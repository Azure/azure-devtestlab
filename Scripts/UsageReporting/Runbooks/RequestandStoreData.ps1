
$StorageAccountName = Get-AutomationVariable -Name 'StorageAccountName'
$StorageKey = Get-AutomationVariable -Name 'StorageKey'
$maxConcurrentJobs = Get-AutomationVariable -Name 'maxConcurrentJobs'

$connectionName = "AzureRunAsConnection"

try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
    Write-Output "post-get auto connect"
    
    Add-AzureRmAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    
    Write-Output "Logging in to Azure..."
    
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#Write-Output $(Get-Module -ListAvailable -Name Azure -Refresh)
#$AzVer = Get-Module -ListAvailable -Name Azure -Refresh

#Dynamically get labs
Write-Output "Information: Get subscriptions"
$allsubs = Get-AzureRmSubscription
Write-Output "Information: Found $($allsubs.Count.ToString()) subscriptions"

Write-Output $allsubs

$labs = @()

foreach ($individualsub in $allsubs) 
{
#    if ($AzVer.Version.Major -eq 4) {
        $labsubid = $individualsub.Id
#    }
#    elseif ($AzVer.Version.Major -eq 3) {
#        $labsubid = $individualsub.SubscriptionId
#    }
            
    Write-Output "Information: Get all labs in a subscription"
    if((Get-AzureRmContext).Subscription.SubscriptionId -ne $labsubid)
    {
        Write-Output "Information: Switching to subscription $($labsubid)"
        Select-AzureRmSubscription -SubscriptionId $labsubid | Out-Null
    }
        
    #Get all DevTest Labs
    $labs += @(Get-AzureRmResource | Where-Object {$_.ResourceType -ieq "Microsoft.DevTestLab/labs"})
    Write-Output "Information: Retrieved labs current count $($labs.Count.ToString())"
}



$labInfoCount = $labs.Count #$labInfo.Labs.Length
Write-Output "Information: Found $labInfoCount total labs"
$ContainerName = "labresourceusage"

#Possible fix for MaxMemoryPerShellMb
#winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2000"}'

#kick off jobs to deploy all the Lab usage requests in parallel
$jobs = @()

$profilePath = Join-Path $env:ProgramData "profile.json"

Write-Output "aaa:$profilePath"

   If (Test-Path $profilePath){
	    Remove-Item $profilePath
    }
    
#If ($AzVer.Version.Major -eq 4) {
    Save-AzureRmContext -Path $profilePath
#}
#elseif ($AzVer.Version.Major -eq 3) {
#    Save-AzureRmProfile -Path $profilePath
#}

#script to be run on each lab
$requestUsageData = {
    Param($labName, $labSubscriptionId, $ModulePath, $startdate, $blobUri, $profilePath)
    
               
#    If ($AzVer.Version.Major -eq 4) {
        $ctx = Import-AzureRMContext -Path $profilePath
        $ctx.Context.TokenCache.Deserialize($ctx.Context.TokenCache.CacheData)
#    }
#    elseif ($AzVer.Version.Major -eq 3) {
#        Select-AzureRmProfile -Path $profilePath | Out-Null
#    }

    Write-Output "Information: Getting Lab information for $($labName)"    
    
    Write-Output "Information: Changing subscription: $labSubscriptionId"

    if((Get-AzureRmContext).Subscription.SubscriptionId -ne $labSubscriptionId){
        Write-Output "Switching to subscription $labSubscriptionId"
        Select-AzureRmSubscription -SubscriptionId $labSubscriptionId | Out-Null
    }

    $resourceGroupName = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $labName}).ResourceGroupName 

    if ($resourceGroupName -eq $null) {
        Write-Output "Error: Unable to find Resource Group for $labName"
        $result = "Failed: Missing Resource Group Name."
    }
    else {

        $resourceId = "/subscriptions/" + $labSubscriptionId + "/resourceGroups/" + $resourceGroupName + "/providers/Microsoft.DevTestLab/labs/" + $labName + "/"

        Write-Output "Information: ResourceID: $resourceId"
         
        $actionParameters = @{
            'blobStorageAbsoluteSasUri' = $blobUri;
            'usageStartDate' = $startdate;
        }
    
        #Execute the exportResourceUsage on the lab
        $result = Invoke-AzureRmResourceAction -Action 'exportResourceUsage' -ResourceId $resourceId -Parameters $actionParameters -Force -Verbose -ErrorAction SilentlyContinue

        Write-Output "Information: Result: $result"
        Write-Output "LabName: $($labName)"
        Write-Output "Usage Data download: $($result.status)"
    }
        
}

#Get storage context and SAS token
$Ctx = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageKey

if ($Ctx -eq $null) {
    Write-Output "Error: Unable to retrieve Storage Context for $StorageAccountName"
    Exit -1
}

$SasToken = New-AzureStorageAccountSASToken -Service Blob, File -ResourceType Container, Service, Object  -Permission rwdlacup -Protocol HttpsOnly -Context $Ctx

if ($SasToken -eq $null) {
    Write-Output "Error: Unable to retrieve Security Token for $StorageAccountName"
    Exit -1
}


# Get blob uri
$blobUri = $Ctx.BlobEndPoint + $SasToken

$jobIndex = 1

Write-Output "Information: Check container existence."

$containerExists = $false

if (Get-AzureStorageContainer -Context $Ctx -Name $ContainerName -ErrorAction SilentlyContinue)
{
    $containerExists = $true
}

$labsWithStartDate = @()

#Get the last successful usage export for each lab based on key file

foreach ($lab in $labs) {

    $blob = $null
 
    if ($containerExists) {
        $blob = Get-AzureStorageBlob -Container $ContainerName.ToLower() -Context $Ctx -Blob ($lab.ResourceName.ToLower() + "/*.txt")
        if ($blob -eq $null){
            Write-Output "Warning: Storage Container for $($lab.ResourceName) exists but no last success date file. This is acceptable for new labs."
        }
    }

    #If a new lab use this as the start date
    $startdate = Get-Date -Day "01" -Month "01" -Year "2017"

    #Find the last date successfully downloaded.
    if ($blob -ne $null)
    {
        Write-Output "Information: Start date file $($blob.Name)"
        $lastdate = $blob.Name.Substring($lab.ResourceName.Length +1).TrimEnd(".txt")
        $startdate = Get-Date -Day $lastdate.Substring(6,2) -Month $lastdate.Substring(4,2) -Year $lastdate.Substring(0,4)
    }
       
    $labsWithStartDate += @{
        'labName' = $lab.ResourceName;
        'labSubscriptionId' = $lab.SubscriptionId;
        'labstartdate' = $startdate
        }
        
}

# Start Job for each lab
foreach ($fullLab in $labsWithStartDate) {

    Write-Output "Information: First try for : $($fullLab.labName) in $($fullLab.labSubscriptionId)"

    #Limiting number of concurrent jobs being run.
    while ((Get-Job -State 'Running').Count -ge $maxConcurrentJobs){
        Write-Output "Information: Throttling background tasks after starting $jobIndex of $($labsWithStartDate.Count.ToString()) jobs."
        Start-Sleep -Seconds 30
    }

    Write-Output "Information: Post Throttle job for lab: $($fullLab.labName) in $($fullLab.labSubscriptionId)"
    
    $jobs += Start-Job -ScriptBlock $requestUsageData -ArgumentList $fullLab.labName, $fullLab.labSubscriptionId, $ModulePath, $fullLab.labstartdate, $blobUri, $profilePath
    $jobIndex++

    Write-Output "Information: Job #$($jobIndex.ToString()) started: $($fullLab.labName) in $($fullLab.labSubscriptionId)."
}

 #Generate new success key file with current date
$localStore = Join-Path -Path $env:APPData -ChildPath $ContainerName

Write-Output "Information: Local store: $localStore"

If(!(Test-Path -LiteralPath $localStore))
{
    New-Item -ItemType Directory -Force -Path $localStore | out-null
    Write-Output "Information: Created new localstore"
}
        
$newDate = (Get-Date)
$fullPath = Join-Path -Path $localStore -ChildPath ($newDate.ToString("yyyyMMdd") + ".txt")

Write-Output "Information: New fullpath: $fullPath"

If(!(Test-Path -Path ($fullPath)))
{
    $newFile = New-Item -ItemType File -Path $localStore -Name ($newDate.ToString("yyyyMMdd") + ".txt")
}
else
{
    $newFile = Get-Item -Path $fullPath
}

Write-Output "Information: New date file created."

$successjobLabName = @()

# Get results from all jobs
if($jobs.Count -ne 0)
{
    try{

        Write-Output "Information: Waiting for Lab Usage jobs to complete"
        $currentJob = 0

        foreach ($job in $jobs){
            $currentJob ++
            Write-Output "Information: In Job Count #: $($currentJob.ToString())"
            Write-Output "Information: Job Id #: $($job.Id.ToString())"

            $jobResult = Receive-Job -Job $job -Wait 

            Write-Output "Information: Received Job # $($currentJob.ToString())"

            #Parse the result information for the specific lab

            Write-Output "++++++++++++++++++++++++++++++++++++"

            foreach ($item in $jobResult) {
                Write-Output "Information: $item"
                if ($item.Contains("LabName:")) {
                    $labName = $item.Substring(9)
                }
                if ($item.Contains("Usage Data download:")){
                    $jobInfo = $item.Substring(21)
                }

                Write-Output "Information: $item"
            }
            Write-Output "++++++++++++++++++++++++++++++++++++"
            
            Write-Output "Information: jobInfo: $jobInfo"

            if ($jobInfo -like "Succeeded")
                {
                    Write-Output "Information: Success in $($job.Id.ToString())"
                    $successjobLabName += $labName
                }
            else
                {
                    Write-Output "Error: Failed to download lab, job result: $jobResult"                    
                }
     
        }
    }
    finally{
        Remove-Job -Job $jobs -Force
        # Remove old key files and replace in all successful labs
        foreach($slabname in $successjobLabName) {

            Write-Output "Information: Telemetry successfully downloaded for $slabname"                   

            $oldfiles = Get-AzureStorageBlob -Container $ContainerName.ToLower() -Context $Ctx -Blob ($slabname.ToLower() + "/*.txt")
            Write-Output "Information: Number files to be removed: $($oldfiles.count.ToString())"

            if ($oldfiles.count -ne 0) {
                $oldfiles | Remove-AzureStorageBlob
                Write-Output "Information: DateTime files removed."
            }                    

            Set-AzureStorageBlobContent -Container $ContainerName.ToLower() -Context $Ctx -File $newFile -Blob ($slabname.ToLower() + "/" + $newFile.Name)
                    
            Write-Output "Information: Reset date $newDate"
        }
    }
}
else 
{
    Write-Output "Information: No labs available"
}
