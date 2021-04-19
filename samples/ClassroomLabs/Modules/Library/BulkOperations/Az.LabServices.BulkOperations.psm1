# Error if Az.LabServices module not loaded
if (-not (Get-Command -Name "New-AzLab" -ErrorAction SilentlyContinue)) {
    Write-Error "You need to import the module Az.LabServices.psm1 in your script (i.e. Import-Module ../Az.LabServices.psm1 -Force )"
}

# Install the ThreadJob module if the command isn't available
if (-not (Get-Command -Name "Start-ThreadJob" -ErrorAction SilentlyContinue)) {
    Install-Module -Name ThreadJob -Scope CurrentUser -Force
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-LabsCsv {
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $CsvConfigFile
    )

    function Import-Schedules {
        param($schedules)

        $file = "./$schedules.csv"

        $scheds = Import-Csv $file
        $scheds | Foreach-Object {
            $_.WeekDays = ($_.WeekDays.Split(',')).Trim()
        }
        return $scheds
    }

    $labs = Import-Csv -Path $CsvConfigFile

    Write-Verbose ($labs | Format-Table | Out-String)

    # Validate that if a resource group\lab account appears more than once in the csv, that it also has the same SharedGalleryId and EnableSharedGalleryImages values.
    $lacs = $labs | Select-Object -Property ResourceGroupName, LabAccountName, SharedGalleryId, EnableSharedGalleryImages | Sort-Object -Property ResourceGroupName, LabAccountName
    $lacNames = $lacs | Select-Object -Property ResourceGroupName, LabAccountName -Unique
  
    foreach ($lacName in $lacNames){
        $matchLacs = $lacs | Where-Object {$_.ResourceGroupName -eq $lacName.ResourceGroupName -and $_.LabAccountName -eq $lacName.LabAccountName}
        $firstLac = $matchLacs[0]
  
        $mismatchSIGs = $matchLacs | Where-Object {$_.SharedGalleryId -ne $firstLac.SharedGalleryId -or $_.EnableSharedGalleryImages -ne $firstLac.EnableSharedGalleryImages}
        $mismatchSIGs | Foreach-Object {
            $msg1 = "SharedGalleryId - Expected: $($firstLac.SharedGalleryId) Actual: $($_.SharedGalleryId)"
            $msg2 = "EnabledSharedGalleryImages - Expected: $($firstLac.EnableSharedGalleryImages) Actual: $($_.EnableSharedGalleryImages)"
            Write-Error "Lab account $lacName SharedGalleryId and EnableSharedGalleryImages values are not consistent. $msg1. $msg2."
        }
    }

    $labs | ForEach-Object {

        # First thing, we need to save the original properties in case they're needed later (for export)
        Add-Member -InputObject $_ -MemberType NoteProperty -Name OriginalProperties -Value $_.PsObject.Copy()

        # Validate that the name is good, before we start creating labs
        if (-not ($_.LabName -match "^[a-zA-Z0-9_, '`"!|-]*$")) {
            Write-Error "Lab Name '$($_.LabName)' can't contain special characters..."
        }

        if ((Get-Member -InputObject $_ -Name 'AadGroupId') -and ($_.AadGroupId)) {
            # Validate that the aadGroupId (if it exists) isn't a null guid since that's not valid (it's in the default csv this way)
            if ($_.AadGroupId -ieq "00000000-0000-0000-0000-000000000000") {
                Write-Error "AadGroupId cannot be all 0's for Lab '$($_.LabName)', please enter a valid AadGroupId"
            }

            # We have to ensure 
            if ((Get-Member -InputObject $_ -Name 'MaxUsers') -and ($_.MaxUsers)) {
                Write-Warning "Max users and AadGroupId cannot be specified together, MaxUsers will be ignored for lab '$($_.LabName)'"
                $_.MaxUsers = ""
            }
        }

        # Checking to ensure the user has changed the example username/passwork in CSV files
        if ($_.UserName -and ($_.UserName -ieq "test0000")) {
            Write-Warning "Lab $($_.LabName) is using the default UserName from the example CSV, please update it for security reasons"
        }
        if ($_.Password -and ($_.Password -ieq "Test00000000")) {
            Write-Warning "Lab $($_.LabName) is using the default Password from the example CSV, please update it for security reasons"
        }

        if ((Get-Member -InputObject $_ -Name 'Emails') -and ($_.Emails)) {
            $_.Emails = ($_.Emails.Split(';')).Trim()
        }

        if ((Get-Member -InputObject $_ -Name 'LabOwnerEmails') -and ($_.LabOwnerEmails)) {
            $_.LabOwnerEmails = ($_.LabOwnerEmails.Split(';')).Trim()
        }

        if (Get-Member -InputObject $_ -Name 'GpuDriverEnabled') {
            if ($_.GpuDriverEnabled) {
                $_.GpuDriverEnabled = [System.Convert]::ToBoolean($_.GpuDriverEnabled)
            }
            else {
                $_.GpuDriverEnabled = $false
            }
        }
        else {
            Add-Member -InputObject $_ -MemberType NoteProperty -Name "GpuDriverEnabled" -Value $false
        }

        if (Get-Member -InputObject $_ -Name 'LinuxRdp') {
            if ($_.LinuxRdp) {
                $_.LinuxRdp = [System.Convert]::ToBoolean($_.LinuxRdp)
            }
            else {
                $_.LinuxRdp = $false
            }
        }
        else {
            Add-Member -InputObject $_ -MemberType NoteProperty -Name "LinuxRdp" -Value $false
        }

        if ((Get-Member -InputObject $_ -Name 'Schedules') -and ($_.Schedules)) {
            Write-Verbose "Setting schedules for $($_.LabName)"
            $_.Schedules = Import-Schedules -schedules $_.Schedules
        }

    }

    Write-Verbose ($labs | ConvertTo-Json -Depth 10 | Out-String)

    return ,$labs # PS1 Magick here, the comma is actually needed. Don't ask why.
    # Ok, here is why, PS1 puts each object in the collection on the pipeline one by one
    # unless you say explicitely that you want to pass it as a single object
}

function Export-LabsCsv {
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]
        $labs,

        [parameter(Mandatory = $true)]
        [string]
        $CsvConfigFile,

        [parameter(Mandatory = $false)]
        [switch] $Force
    )

    begin
    {
        $outArray = @()
    }

    process
    {
        # Iterate over the labs and pull out the inner properties (orig object) and add in result fields
        $labs | ForEach-Object {
            $obj = $_

            # If we don't have the underlying properties, need to bail out
            if (-not (Get-Member -InputObject $_ -Name OriginalProperties)) {
                Write-Error "Cannot write out labs CSV, input labs object doesn't contain original properties"
            }

            $outObj = $_.OriginalProperties

            # We need to copy any 'result' fields over to the original object we're writing out
            Get-Member -InputObject $obj -Name "*Result" | ForEach-Object {
                if (Get-Member -InputObject $outObj -Name $_.Name) {
                    $outObj.$($_.Name) = $obj.$($_.Name)
                }
                else {
                    Add-Member -InputObject $outObj -MemberType NoteProperty -Name $_.Name $obj.$($_.Name)
                }
            }

            # Add the object to the cumulative array
            $outArray += $outObj
        }
    }

    end
    {
        if ($Force.IsPresent) {
            $outArray | Export-Csv -Path $CsvConfigFile -NoTypeInformation -Force
        }
        else {
            $outArray | Export-Csv -Path $CsvConfigFile -NoTypeInformation -NoClobber
        }
    }
}

function New-AzLabAccountsBulk {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab account to be created", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labAccounts,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5
    )

    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab account creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labAccounts is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labAccounts
    }
    end {
        $init = {            
        }

        # No need to parallelize this one as super fast
        function New-ResourceGroups {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [psobject[]]
                $ConfigObject
            )

            $Rgs = $ConfigObject | Select-Object -Property ResourceGroupName, Location -Unique
            Write-Verbose "Looking for the following resource groups:"
            $Rgs | Format-Table | Out-String | Write-Verbose
            
            $Rgs | ForEach-Object {
                if (-not (Get-AzResourceGroup -ResourceGroupName $_.ResourceGroupName -EA SilentlyContinue)) {
                    New-AzResourceGroup -ResourceGroupName $_.ResourceGroupName -Location $_.Location | Out-null
                    Write-Host "$($_.ResourceGroupName) resource group didn't exist. Created it." -ForegroundColor Green
                }
            }
        }
        
        function New-AzAccount-Jobs {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [psobject[]]
                $ConfigObject
            )

            $block = {
                param($path)

                Set-StrictMode -Version Latest
                $ErrorActionPreference = 'Stop'

                $modulePath = Join-Path $path '..\Az.LabServices.psm1'
                Import-Module $modulePath
                # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
                $input.movenext() | Out-Null
            
                $obj = $input.current[0]

                Write-Verbose "object inside the new-azaccount-jobs block $obj"
                $StartTime = Get-Date

                Write-Host "Creating Lab Account: $($obj.LabAccountName)"
                $labAccount = New-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
                
                if ($obj.SharedGalleryId){
                    $gallery = $labAccount | Get-AzLabAccountSharedGallery
                    if ($gallery) {
                        Write-Host "$($obj.LabAccountName) lab account already has attached gallery $($gallery.id)"
                    }
                    else {
                        $result = New-AzLabAccountSharedGallery -LabAccount $labAccount -SharedGalleryId $obj.SharedGalleryId
                        Write-Host "Successfully attached shared image gallery:  $($obj.SharedGalleryId)"
                    }

                    # This will enable the SIG images explicitly listed in the csv.  
                    # For SIG images that are *not* listed in the csv, this will automatically disable them.
                    Write-Host "Enabling images for lab account: $($labAccount.Name)"
                    if ($obj.EnableSharedGalleryImages)
                    {
                        $imageNamesToEnable = $obj.EnableSharedGalleryImages.Split(',')

                        Write-Verbose "Images to enable: $imageNamesToEnable"
                        $images = $labAccount | Get-AzLabAccountSharedImage -EnableState All
    
                        foreach ($image in $images) {
                            $enableImage = $imageNamesToEnable -contains ($image.Name) # Note: -contains is case insensitive
    
                            if ($enableImage -eq $true){
                                Write-Verbose "Enabling image: $($image.Name)"
                                $image = $image | Set-AzLabAccountSharedImage -EnableState Enabled
                            }
                            else {
                                Write-Verbose "Disabling image: $($image.Name)"
                                $image = $image | Set-AzLabAccountSharedImage -EnableState Disabled
                            }
                        }
                    }

                    Write-Verbose "Completed creation of $($obj.SharedGalleryId), total duration $(((Get-Date) - $StartTime).TotalSeconds) seconds"
                }

                Write-Host "Completed creation of $($obj.LabAccountName), total duration $([math]::Round(((Get-Date) - $StartTime).TotalMinutes, 1)) minutes" -ForegroundColor Green
            }

            Write-Host "Starting creation of all lab accounts in parallel. Can take a while."
            $lacs = $ConfigObject | Select-Object -Property ResourceGroupName, LabAccountName, SharedGalleryId, EnableSharedGalleryImages -Unique
            
            Write-Verbose "Operating on the following Lab Accounts:"
            Write-Verbose ($lacs | Format-Table | Out-String)

            $jobs = @()

            $lacs | ForEach-Object {
                Write-Verbose "From config: $_"
                $jobs += Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name ("$($_.ResourceGroupName)+$($_.LabAccountName)") -ThrottleLimit $ThrottleLimit
            }

            while (($jobs | Measure-Object).Count -gt 0) {
                # If we have more jobs, wait for 60 sec before checking job status again
                Start-Sleep -Seconds 60

                $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
                if (($completedJobs | Measure-Object).Count -gt 0) {
                    # Write output for completed jobs, but one by one so output doesn't bleed 
                    # together, also use "Continue" so we write the error but don't end the outer script
                    $completedJobs | ForEach-Object {
                        # For each completed job we write the result back to the appropriate Config object, using the "name" field to coorelate
                        $jobName = $_.Name
                        $jobState = $_.State
                        # NOTE:  we may have many 'config' rows in the CSV associated with a single lab account, we need to udpate all of them
                        $config = $ConfigObject | Where-Object {$_.ResourceGroupName -ieq $jobName.Split('+')[0] -and $_.LabAccountName -ieq $jobName.Split('+')[1]}
                        $config | ForEach-Object {
                            if (Get-Member -InputObject $_ -Name LabAccountResult) {
                                $_.LabAccountResult = $jobState
                            }
                            else {
                                Add-Member -InputObject $_ -MemberType NoteProperty -Name "LabAccountResult" -Value $jobState
                            }
                        }

                        # Finally, output the results to the UI
                        $_ | Receive-Job -ErrorAction Continue
                    }
                    # Trim off the completed jobs from our list of jobs
                    $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                    # Remove the completed jobs from memory
                    $completedJobs | Remove-Job
                }
            }

            # Return the objects with an additional property on the result of the operation
            return $ConfigObject
        }

        # Needs to create resources in this order, aka parallelize in these three groups, otherwise we get contentions:
        # i.e. different jobs trying to create the same common resource (RG or lab account)
        New-ResourceGroups  -ConfigObject $aggregateLabs
        # New-AzAccount-Jobs returns the config object with an additional column, we need to leave it on the pipeline
        New-AzAccount-Jobs   -ConfigObject $aggregateLabs
    }
}

function New-AzLabsBulk {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be created", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5
    )

    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labs is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labs
    }
    end {
        $init = {
            
        }
        function New-AzLab-Jobs {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [psobject[]]
                $ConfigObject
            )

            $block = {
                param($path)

                Set-StrictMode -Version Latest
                $ErrorActionPreference = 'Stop'

                $modulePath = Join-Path $path '..\Az.LabServices.psm1'
                Import-Module $modulePath
                # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
                $input.movenext() | Out-Null
            
                $obj = $input.current[0]

                Write-Verbose "object inside the new-azlab-jobs block $obj"

                $StartTime = Get-Date
                Write-Host "Creating Lab : $($obj.LabName)"

                $la = Get-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
                if (-not $la -or @($la).Count -ne 1) { Write-Error "Unable to find lab account $($obj.LabAccountName)."}

                $lab = $la | Get-AzLab -LabName $obj.LabName

                if ($lab) {
                    Write-Host "Lab already exists..  Updating properties instead."
                    Set-AzLab -Lab $lab -MaxUsers $obj.MaxUsers -UserAccessMode $obj.UsageMode -SharedPasswordEnabled $obj.SharedPassword | Out-Null

                    # In the case of AAD Group, we have to force sync users to update the MaxUsers property
                    if ((Get-Member -InputObject $obj -Name 'AadGroupId') -and ($obj.AadGroupId)) {
                        Write-Host "syncing users from AAD ..."
                        Sync-AzLabADUsers -Lab $lab | Out-Null
                    }

                    $currentLab = $lab
                }
                else {
                    # Try to get shared image and then gallery image
                    $img = $la | Get-AzLabAccountSharedImage | Where-Object { $_.name -like $obj.ImageName }
                    if(-not $img) {
                        $img = $la | Get-AzLabAccountGalleryImage | Where-Object { $_.name -like $obj.ImageName }
                        if (-not $img -or @($img).Count -ne 1) { Write-Error "$($obj.ImageName) pattern doesn't match just one gallery image." }
                    }

                    # Set the TemplateVmState, defaulting to enabled
                    if (Get-Member -InputObject $obj -Name TemplateVmState) {
                        if ($obj.TemplateVmState -and ($obj.TemplateVmState -ieq "Disabled")) {
                            $obj.TemplateVmState  = "Disabled"
                        }
                        else {
                            $obj.TemplateVmState  = "Enabled"
                        }
                    }
                    else {
                        Add-Member -InputObject $obj -MemberType NoteProperty -Name TemplateVmState -Value "Enabled"
                    }

                    # Set the boolean LinuxRdp
                    if ($obj.LinuxRdp -ieq "True") {
                        $obj.LinuxRdp = $true
                    } else {
                        $obj.LinuxRdp = $false
                    }

                    $obj | New-AzLab -LabAccount $la -Image $img | Out-Null
                    $currentLab = Get-AzLab -LabAccount $la -LabName $obj.LabName 
                    Set-AzLab -Lab $currentLab -MaxUsers $obj.MaxUsers -UserAccessMode $obj.UsageMode -SharedPasswordEnabled $obj.SharedPassword -UsageQuotaInHours $obj.UsageQuota | Out-Null

                    Write-Host "Completed lab creation step in $([math]::Round(((Get-Date) - $StartTime).TotalMinutes, 1)) minutes"

                    # In the case of AAD Group, we have to force sync users to update the MaxUsers property
                    if ((Get-Member -InputObject $obj -Name 'AadGroupId') -and ($obj.AadGroupId)) {
                        Write-Host "syncing users from AAD ..."
                        Sync-AzLabADUsers -Lab $currentLab | Out-Null
                    }

                    # If we have any lab owner emails, we need to assign the RBAC permission
                    if ($obj.LabOwnerEmails) {
                        Write-Host "Adding Lab Owners: $($obj.LabOwnerEmails) ."
                        $obj.LabOwnerEmails | ForEach-Object {
                            # Need to ensure we didn't get an empty string, in case there's an extra delimiter
                            if ($_) {
                                # Check if Lab Owner role already exists (the role assignment is added by default by the person who runs the script), if not create it
                                if (-not (Get-AzRoleAssignment -SignInName $_ -Scope $currentLab.id -RoleDefinitionName Owner)) {
                                    New-AzRoleAssignment -SignInName $_ -Scope $currentLab.id -RoleDefinitionName Owner | Out-Null
                                }
                                # Check if the lab account reader role already exists, if not create it
                                if (-not (Get-AzRoleAssignment -SignInName $_ -ResourceGroupName $currentLab.ResourceGroupName -ResourceName $currentLab.LabAccountName -ResourceType "Microsoft.LabServices/labAccounts" -RoleDefinitionName Reader)) {
                                    New-AzRoleAssignment -SignInName $_ -ResourceGroupName $currentLab.ResourceGroupName -ResourceName $currentLab.LabAccountName -ResourceType "Microsoft.LabServices/labAccounts" -RoleDefinitionName Reader | Out-Null 
                                }
                            }
                        }
                        Write-Host "Added Lab Owners: $($obj.LabOwnerEmails)." -ForegroundColor Green
                    }
                }
                
                #Section to send out invitation emails
                if ($obj.Emails) {
                    Write-Host "Adding users for $($obj.LabName) for users $($obj.Emails)."
                    $currentLab = $currentLab | Add-AzLabUser -Emails $obj.Emails
                    if ($obj.Invitation) {
                        Write-Host "Sending Invitation emails for $($obj.LabName)."
                        $users = $currentLab | Get-AzLabUser
                        $users | ForEach-Object { $currentLab | Send-AzLabUserInvitationEmail -User $_ -InvitationText $obj.Invitation } | Out-Null
                    }
                }

                if ($obj.Schedules) {
                    Write-Host "Adding Schedules for $($obj.LabName)."
                    $obj.Schedules | ForEach-Object { $_ | New-AzLabSchedule -Lab $currentlab } | Out-Null
                    Write-Host "Added all schedules."
                }

                Write-Host "Completed all tasks for $($obj.LabName), total duration $([math]::Round(((Get-Date) - $StartTime).TotalMinutes, 1)) minutes" -ForegroundColor Green
            }

            Write-Host "Starting creation of all labs in parallel. Can take a while."
            $jobs = @()

            $ConfigObject | ForEach-Object {
                Write-Verbose "From config: $_"
                $jobs += Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name  ("$($_.ResourceGroupName)+$($_.LabAccountName)+$($_.LabName)") -ThrottleLimit $ThrottleLimit
            }

            while (($jobs | Measure-Object).Count -gt 0) {
                # If we have more jobs, wait for 60 sec before checking job status again
                Start-Sleep -Seconds 60

                $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
                if (($completedJobs | Measure-Object).Count -gt 0) {
                    # Write output for completed jobs, but one by one so output doesn't bleed 
                    # together, also use "Continue" so we write the error but don't end the outer script
                    $completedJobs | ForEach-Object {
                        # For each completed job we write the result back to the appropriate Config object, using the "name" field to coorelate
                        $jobName = $_.Name
                        $jobState = $_.State
                        $config = $ConfigObject | Where-Object {$_.ResourceGroupName -ieq $jobName.Split('+')[0] -and $_.LabAccountName -ieq $jobName.Split('+')[1] -and $_.LabName -ieq $jobName.Split('+')[2]}

                        if (Get-Member -InputObject $config -Name LabResult) {
                            $config.LabResult = $jobState
                        }
                        else {
                            Add-Member -InputObject $config -MemberType NoteProperty -Name "LabResult" -Value $jobState
                        }
                        $_ | Receive-Job -ErrorAction Continue
                    }
                    # Trim off the completed jobs from our list of jobs
                    $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                    # Remove the completed jobs from memory
                    $completedJobs | Remove-Job
                }
            }

            # Return the objects with an additional property on the result of the operation
            return $ConfigObject
        }

        # New-AzLab-Jobs returns the config object with an additional column, we need to leave it on the pipeline
        New-AzLab-Jobs   -ConfigObject $aggregateLabs 
    }
}

function Set-AzRoleToLabAccountsBulk {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be created", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $RoleDefinitionName
    )

    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labs is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labs
    }
    end {
        $init = {
            
        }
        function Set-AzRoleToLabAccount-Jobs {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [psobject[]]
                $ConfigObject,

                [parameter(Mandatory = $true)]
                [ValidateNotNullOrEmpty()]
                [string]
                $RoleDefinitionName
            )

            $block = {
                param($path, $RoleDefinitionName)

                Set-StrictMode -Version Latest
                $ErrorActionPreference = 'Stop'

                $modulePath = Join-Path $path '..\Az.LabServices.psm1'
                Import-Module $modulePath
                # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
                $input.movenext() | Out-Null
            
                $obj = $input.current[0]

                Write-Host "Started operating on lab account:  '$($obj.LabAccountName)' in resource group '$($obj.ResourceGroupName)'"
                Write-Verbose "object inside the assign-azRoleToLabAccount-jobs block $obj"

                if((Get-Member -InputObject $obj -Name 'LabAccountCustomRoleEmails') -and ($obj.LabAccountCustomRoleEmails)) {
                            
                    $emails = @($obj.LabAccountCustomRoleEmails -split ';')
                    $emails = @($emails | Where-Object {-not [string]::IsNullOrWhiteSpace($emails) })
                    if ($emails.Length -eq 0){
                        Write-Verbose "No emails specified for role assignment."
                    }
                    else {

                        $la = Get-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
                        if (-not $la -or @($la).Count -ne 1) {
                            Write-Error "Unable to find lab account '$($obj.LabAccountName)'"
                        } 

                        foreach ($email in $emails) {
                            #Get AD object id for user.  Try both user principal name and mail emails
                            $userAdObject = $null
                            $userAdObject = Get-AzADUser -UserPrincipalName $email.ToString().Trim() -ErrorAction SilentlyContinue
                            if (-not $userAdObject){
                                $userAdObject = Get-AzADUser -Mail $email.ToString().Trim() -ErrorAction SilentlyContinue
                            }
                            if (-not $userAdObject){
                                Write-Error "Couldn't find user '$email' in Azure AD."
                            }

                            #Check if role assignment already exists.
                            if (Get-AzRoleAssignment -ObjectId $userAdObject.Id -RoleDefinitionName $RoleDefinitionName -Scope $la.id -ErrorAction SilentlyContinue) {
                                Write-Host "Role Assignment $RoleDefinitionName for $email for lab account $($obj.LabAccountName) already exists."
                            }
                            else {
                                Write-Host "Creating new role ssignment $RoleDefinitionName for $email for lab account $($obj.LabAccountName)."
                                $result = New-AzRoleAssignment -ObjectId $userAdObject.Id -RoleDefinitionName $RoleDefinitionName -Scope $la.id
                            }
                        }
                    }
                }
                else {
                    Write-Host "No emails specified for role assignment" -ForegroundColor Yellow         
                }    
             }

            Write-Host "Starting role assignment for lab accounts in parallel. Can take a while."

            # NOTE: the Get-AzureAdUser commandlet will throw an error if the user isn't logged in
            if (-not (Get-AzAdUser -First 1)) {
                Write-Error "Unable to access Azure AD users using Get-AzAdUser commandlet, you don't have sufficient permission to the AD Tenant to use this commandlet"
            }

            $jobs = @()

            $ConfigObject | ForEach-Object {
                Write-Verbose "From config: $_"
                $jobs += Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot, $RoleDefinitionName -InputObject $_ -Name  ("$($_.ResourceGroupName)+$($_.LabAccountName)") -ThrottleLimit $ThrottleLimit
            }

            while (($jobs | Measure-Object).Count -gt 0) {
                # If we have more jobs, wait for 30 sec before checking job status again
                Start-Sleep -Seconds 30

                $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
                if (($completedJobs | Measure-Object).Count -gt 0) {
                    # Write output for completed jobs, but one by one so output doesn't bleed 
                    # together, also use "Continue" so we write the error but don't end the outer script
                    $completedJobs | ForEach-Object {
                        $_ | Receive-Job -ErrorAction Continue
                    }
                    # Trim off the completed jobs from our list of jobs
                    $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                    # Remove the completed jobs from memory
                    $completedJobs | Remove-Job
                }
            }
        }

        Set-AzRoleToLabAccount-Jobs  -ConfigObject $aggregateLabs -RoleDefinitionName $RoleDefinitionName
    }
}

function Remove-AzLabsBulk {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be removede", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5
    )

    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab account creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labAccounts is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labs
    }
    end {
        $init = {            
        }

        # No need to parallelize this one as super fast
         function Remove-AzLabs-Jobs {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [psobject[]]
                $ConfigObject
            )

            $block = {
                param($path)

                Set-StrictMode -Version Latest
                $ErrorActionPreference = 'Stop'

                $modulePath = Join-Path $path '..\Az.LabServices.psm1'
                Import-Module $modulePath
                # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
                $input.movenext() | Out-Null
            
                $obj = $input.current[0]

                Write-Verbose "object inside the remove-azlabs-jobs block $obj"
                $StartTime = Get-Date

                Write-Host "Removing Lab: $($obj.LabName)"
                $la = Get-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
                if (-not $la -or @($la).Count -ne 1) { Write-Error "Unable to find lab account $($obj.LabAccountName)."}

                $lab = $la | Get-AzLab -LabName $obj.LabName
                if (-not $lab -or @($lab).Count -ne 1) { Write-Error "Unable to find lab $($obj.LabName)."}
                Remove-AzLab -Lab $lab -EnableWaitForDelete $true
                Write-Host "Completed removal of $($obj.LabName), total duration $([math]::Round(((Get-Date) - $StartTime).TotalMinutes, 1)) minutes"
            }

            Write-Host "Starting removal of all labs in parallel. Can take a while."
            $labs = $ConfigObject | Select-Object -Property ResourceGroupName, LabAccountName, LabName -Unique
            
            Write-Verbose "Operating on the following Lab Accounts:"
            Write-Verbose ($labs | Format-Table | Out-String)

            $jobs = @()

            $labs | ForEach-Object {
                Write-Verbose "From config: $_"
                $jobs += Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name ("$($_.ResourceGroupName)+$($_.LabAccountName)+$($_.LabName)") -ThrottleLimit $ThrottleLimit
            }

            while (($jobs | Measure-Object).Count -gt 0) {
                # If we have more jobs, wait for 60 sec before checking job status again
                Start-Sleep -Seconds 60

                $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
                if (($completedJobs | Measure-Object).Count -gt 0) {
                    # Write output for completed jobs, but one by one so output doesn't bleed 
                    # together, also use "Continue" so we write the error but don't end the outer script
                    $completedJobs | ForEach-Object {
                        $_ | Receive-Job -ErrorAction Continue
                    }
                    # Trim off the completed jobs from our list of jobs
                    $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                    # Remove the completed jobs from memory
                    $completedJobs | Remove-Job
                }
            }
        }

        Remove-AzLabs-Jobs   -ConfigObject $aggregateLabs
    }
}

function Publish-AzLabsBulk {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be created", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [bool]
        $EnableCreatingLabs = $true,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5
    )

    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labs is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labs
    }
    end {
        $init = {
            
        }
        function Publish-AzLabs-Jobs {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [psobject[]]
                $ConfigObject
            )

            $block = {
                param($path)

                Set-StrictMode -Version Latest
                $ErrorActionPreference = 'Stop'

                $modulePath = Join-Path $path '..\Az.LabServices.psm1'
                Import-Module $modulePath
                # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
                $input.movenext() | Out-Null
            
                $obj = $input.current[0]
                $StartTime = Get-Date

                Write-Verbose "object inside the publish-azlab-jobs block $obj"
                
                Write-Host "Start publishing $($obj.LabName)"
                $la = Get-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
                $lab = Get-AzLab -LabAccount $la -LabName $obj.LabName
                Publish-AzLab -Lab $lab | Out-null
                Write-Host "Completed publishing of $($obj.LabName), total duration $([math]::Round(((Get-Date) - $StartTime).TotalMinutes, 1)) minutes" -ForegroundColor Green

            }

            Write-Host "Starting publishing of all labs in parallel. Can take a while."
            $jobs = @()

            $ConfigObject | ForEach-Object {
                Write-Verbose "From config: $_"
                $jobs += Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name ("$($_.ResourceGroupName)+$($_.LabAccountName)+$($_.LabName)") -ThrottleLimit $ThrottleLimit
            }

            while (($jobs | Measure-Object).Count -gt 0) {
                # If we have more jobs, wait for 60 sec before checking job status again
                Start-Sleep -Seconds 60

                $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
                if (($completedJobs | Measure-Object).Count -gt 0) {
                    # Write output for completed jobs, but one by one so output doesn't bleed 
                    # together, also use "Continue" so we write the error but don't end the outer script
                    $completedJobs | ForEach-Object {
                        # For each completed job we write the result back to the appropriate Config object, using the "name" field to coorelate
                        $jobName = $_.Name
                        $jobState = $_.State
                        $config = $ConfigObject | Where-Object {$_.ResourceGroupName -ieq $jobName.Split('+')[0] -and $_.LabAccountName -ieq $jobName.Split('+')[1] -and $_.LabName -ieq $jobName.Split('+')[2]}

                        if (Get-Member -InputObject $config -Name PublishResult) {
                            $config.PublishResult = $jobState
                        }
                        else {
                            Add-Member -InputObject $config -MemberType NoteProperty -Name "PublishResult" -Value $jobState
                        }

                        $_ | Receive-Job -ErrorAction Continue
                    }
                    # Trim off the completed jobs from our list of jobs
                    $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                    # Remove the completed jobs from memory
                    $completedJobs | Remove-Job
                }
            }
            # Return the objects with an additional property on the result of the operation
            return $ConfigObject
        }

       
        # Added switch to either create labs and publish or just publish existing lab
        # Capture the results so they don't end up on the pipeline
        if ($EnableCreatingLabs) {
            $results = New-AzLabsBulk $aggregateLabs -ThrottleLimit $ThrottleLimit
        }

        # Publish-AzLab-Jobs returns the config object with an additional column, we need to leave it on the pipeline
        Publish-AzLabs-Jobs   -ConfigObject $aggregateLabs
    }
}

function Sync-AzLabADUsersBulk {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be created", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5
    )
    
    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labs is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labs
    }
    end {
        $init = {
            
        }
        function Sync-AzLabADUsers-Jobs {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [psobject[]]
                $ConfigObject
            )

            $block = {
                param($path)

                Set-StrictMode -Version Latest
                $ErrorActionPreference = 'Stop'

                $modulePath = Join-Path $path '..\Az.LabServices.psm1'
                Import-Module $modulePath
                # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
                $input.movenext() | Out-Null
            
                $obj = $input.current[0]
                $StartTime = Get-Date

                Write-Verbose "object inside the Sync-AzLabADUsers-jobs block $obj"
                
                Write-Host "Start ADGroup sync $($obj.LabName)"
                $la = Get-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
                $lab = Get-AzLab -LabAccount $la -LabName $obj.LabName
                Sync-AzLabADUsers -Lab $lab | Out-null
                Write-Host "Completed ADGroup sync of $($obj.LabName), total duration $(((Get-Date) - $StartTime).TotalSeconds) seconds" -ForegroundColor Green

            }

            Write-Host "Starting ADGroup sync of all labs in parallel. Can take a while."
            $jobs = @()

            $ConfigObject | ForEach-Object {
                Write-Verbose "From config: $_"
                $jobs += Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name $_.LabName -ThrottleLimit $ThrottleLimit
            }

            while (($jobs | Measure-Object).Count -gt 0) {
                $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
                if (($completedJobs | Measure-Object).Count -gt 0) {
                    # Write output for completed jobs, but one by one so output doesn't bleed 
                    # together, also use "Continue" so we write the error but don't end the outer script
                    $completedJobs | ForEach-Object {
                        $_ | Receive-Job -ErrorAction Continue
                    }
                    # Trim off the completed jobs from our list of jobs
                    $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                    # Remove the completed jobs from memory
                    $completedJobs | Remove-Job
                }
                # Wait for 60 sec before checking job status again
                Start-Sleep -Seconds 60
            }
        }

        Sync-AzLabADUsers-Jobs   -ConfigObject $aggregateLabs
    }
}

function Get-AzLabsRegistrationLinkBulk {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5
    )

    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labs is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labs
    }
    end {
        $init = {
        }

        function Get-RegistrationLink-Jobs {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [psobject[]]
                $ConfigObject
            )

            $block = {
                param($path)

                Set-StrictMode -Version Latest
                $ErrorActionPreference = 'Stop'

                $modulePath = Join-Path $path '..\Az.LabServices.psm1'
                Import-Module $modulePath
                $input.movenext() | Out-Null
            
                $obj = $input.current[0]

                Write-Host "Getting registration link for $($obj.LabName)"
                $la = Get-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
                $lab = Get-AzLab -LabAccount $la -LabName $obj.LabName

                $URL = "https://labs.azure.com/register/$($lab.Properties.invitationCode)"
                return $URL
            }

            $jobs = @()

            $ConfigObject | ForEach-Object {
                Write-Verbose "From config: $_"
                $jobs += Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name ("$($_.ResourceGroupName)+$($_.LabAccountName)+$($_.LabName)") -ThrottleLimit $ThrottleLimit
            }

            while (($jobs | Measure-Object).Count -gt 0) {
                # If we have more jobs, wait for 60 sec before checking job status again
                Start-Sleep -Seconds 20

                $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
                if (($completedJobs | Measure-Object).Count -gt 0) {
                    # Write output for completed jobs, but one by one so output doesn't bleed 
                    # together, also use "Continue" so we write the error but don't end the outer script
                    $completedJobs | ForEach-Object {
                        # For each completed job we write the result back to the appropriate Config object, using the "name" field to coorelate
                        $jobName = $_.Name
                        $jobState = $_.State
                        $config = $ConfigObject | Where-Object {$_.ResourceGroupName -ieq $jobName.Split('+')[0] -and $_.LabAccountName -ieq $jobName.Split('+')[1] -and $_.LabName -ieq $jobName.Split('+')[2]}
                        $URL = $_ | Receive-Job -ErrorAction Continue

                        if (Get-Member -InputObject $config -Name RegistrationLink) {
                            $config.RegistrationLink = $URL
                        }
                        else {
                            Add-Member -InputObject $config -MemberType NoteProperty -Name "RegistrationLink" -Value $URL
                        }
                    }
                    # Trim off the completed jobs from our list of jobs
                    $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                    # Remove the completed jobs from memory
                    $completedJobs | Remove-Job
                }
            }
            # Return the objects with an additional property on the result of the operation
            return $ConfigObject
        }

        # Get-RegistrationLink-Jobs returns the config object with an additional column, we need to leave it on the pipeline
        Get-RegistrationLink-Jobs -ConfigObject $aggregateLabs
    }
}

function Reset-AzLabUserQuotaBulk {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be updated.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5
    )

    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labs is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labs

    }
    end {

        $block = {
            param($obj, $path)

            Set-StrictMode -Version Latest
            $ErrorActionPreference = 'Stop'

            Write-Verbose "object inside the Update-AzLabUserQuotaBulk-Job block $obj"

            # Only load the module if it's not already available
            if (-not (Get-Command -Name "Get-AzLabAccount" -ErrorAction SilentlyContinue)) {
                $modulePath = Join-Path $path '..\Az.LabServices.psm1'
                Import-Module $modulePath
            }

            Write-Verbose "ConfigObject: $($obj | ConvertTo-Json -Depth 10)"

            $la = Get-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
            if (-not $la -or @($la).Count -ne 1) { Write-Error "Unable to find lab account $($obj.LabAccountName)."}

            $lab = Get-AzLab -LabAccount $la -LabName $obj.LabName
            if (-not $lab -or @($lab).Count -ne 1) { Write-Error "Unable to find lab $($obj.LabName)."}

            Write-Host "Checking lab '$($lab.Name)' in lab account '$($lab.LabAccountName)' for student quotas..."

            $users = Get-AzLabUser -Lab $lab -Email "*"
            $totalUserCount = ($users | Measure-Object).Count
            Write-Host "  This lab has '$totalUserCount' users..."
            Write-Host "  Updating the users to have $($obj.UsageQuota) quota remaining..."

            $currentLabQuota = Convert-UsageQuotaToHours($lab.properties.usageQuota)
            foreach ($user in $users) {
                $totalUsage = Convert-UsageQuotaToHours($user.Properties.totalUsage)
                if ($user.Properties -contains "additionalUsageQuota") {
                    $currentUserQuota = Convert-UsageQuotaToHours($user.Properties.additionalUsageQuota)
                }
                else {
                    $currentUserQuota = 0
                }

                # if the usage (column from csv) and the available hours are less than the Lab quota set the user quota to zero
                if (([int]$obj.UsageQuota + $totalUsage) -le $currentLabQuota) {
                    Set-AzLabUser -Lab $lab -User $user -AdditionalUsageQuota 0 | Out-Null
                } else {
                    #totalUserUsage is the current quota for the lab and the user
                    $totalUserUsage = ($currentLabQuota + $currentUserQuota)
                    #individualUserNeeds is the user used time and the expected available time
                    $individualUserNeeds = ([int]$obj.UsageQuota) + $totalUsage
                    # subtract totalUserUsage from individualUserNeeds, positives will be added to user quota, negatives removed.
                    $diff = ($individualUserNeeds - $totalUserUsage)
                    #Adjust the current user quota
                    $newuserQuota = $currentUserQuota + $diff
                    if ($newuserQuota -ge 0) {
                        Set-AzLabUser -Lab $lab -User $user -AdditionalUsageQuota $newuserQuota | Out-Null
                    }
                    else {
                        # Reduce the user quota but only to zero
                        $removeDiff = ($currentUserQuota + $newuserQuota)
                        if ($removeDiff -ge 0) {
                            Set-AzLabUser -Lab $lab -User $user -AdditionalUsageQuota $removeDiff | Out-Null
                        }
                        else {
                            Set-AzLabUser -Lab $lab -User $user -AdditionalUsageQuota 0 | Out-Null
                        }
                    }
                }
            }
        }

        $jobs = $aggregateLabs | ForEach-Object {
                Write-Verbose "From config: $_"
                Start-ThreadJob -ScriptBlock $block -ArgumentList $_, $PSScriptRoot -Name $_.LabName -ThrottleLimit $ThrottleLimit
            }

        while (($jobs | Measure-Object).Count -gt 0) {
            # If we have more jobs, wait for 60 sec before checking job status again
            Start-Sleep -Seconds 10

            $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
            if (($completedJobs | Measure-Object).Count -gt 0) {
                # Write output for completed jobs, but one by one so output doesn't bleed 
                # together, also use "Continue" so we write the error but don't end the outer script
                $completedJobs | ForEach-Object {
                    $_ | Receive-Job -ErrorAction Continue
                }
                # Trim off the completed jobs from our list of jobs
                $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                # Remove the completed jobs from memory
                $completedJobs | Remove-Job
            }
        }
    }
}

function Confirm-AzLabsBulk {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [int]
        $ThrottleLimit = 5,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Created', 'Published')]
        [string]
        $ExpectedLabState = 'Created'
    )

    begin {
        # This patterns aggregates all the objects in the pipeline before performing an operation
        # i.e. executes lab creation in parallel instead of sequentially
        # This trick is to make it work both when the argument is passed as pipeline and as normal arg.
        # I came up with this. Maybe there is a better way.
        $aggregateLabs = @()
    }
    process {
        # If passed through pipeline, $labs is a single object, otherwise it is the whole array
        # It works because PS uses '+' to add objects or arrays to an array
        $aggregateLabs += $labs
    }
    end {
        $init = {
        }

        function Validate-AzLab-Jobs {
            [CmdletBinding()]
            param(
                [parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [psobject[]]
                $ConfigObject
            )

            $block = {
                param($path, $expectedLabState)

                Set-StrictMode -Version Latest
                $ErrorActionPreference = 'Stop'

                $modulePath = Join-Path $path '..\Az.LabServices.psm1'
                Import-Module $modulePath
                $input.movenext() | Out-Null
            
                $obj = $input.current[0]

                Write-Host "Validating properties for $($obj.LabName)"

                # Lab Account Exists
                $la = Get-AzLabAccount -ResourceGroupName $obj.ResourceGroupName -LabAccountName $obj.LabAccountName
                if (-not $la) {
                    Write-Error "Lab Account doesn't exist..."
                }
                if ($la.Properties.provisioningState -ine "Succeeded") {
                    Write-Error "Lab Account didn't provision successfully"
                }

                # Lab Account has shared gallery and image enabled
                if ((Get-Member -InputObject $obj -Name 'SharedGalleryId') -and $obj.SharedGalleryId) {
                    $sharedGallery = Get-AzLabAccountSharedGallery -LabAccount $la
                    if (-not $sharedGallery) {
                        Write-Error "Shared Gallery not attached correctly"
                    }

                    $images = Get-AzLabAccountSharedImage -LabAccount $la -EnableState Enabled
                    if (($images | Measure-Object).Count -ne ($obj.EnableSharedGalleryImages.Split(',') | Measure-Object).Count) {
                        Write-Error "Incorrect number of gallery images enabled on this lab..."
                    }
                }

                # Lab Exists
                $lab = Get-AzLab -LabAccount $la -LabName $obj.LabName
                if (-not $lab) {
                    Write-Error "Lab doesn't exist..."
                }

                if ($lab.properties.provisioningState -ine "Succeeded") {
                    Write-Error "Lab Account didn't provision successfully"
                }

                # Lab Max users 
                if ((Get-Member -InputObject $obj -Name 'MaxUsers') -and $obj.MaxUsers) {
                    if ($obj.MaxUsers -ne $lab.properties.maxUsersInLab) {
                        Write-Error "Max users don't match for this lab"
                    }
                }

                # AAD Group Id (if set) is correct
                if ((Get-Member -InputObject $obj -Name 'AadGroupId') -and $obj.AadGroupId) {
                    if ($obj.AadGroupId -ine $lab.properties.aadGroupId) {
                        Write-Error "AAD Group Id doesn't match for this lab"
                    }
                }

                # Usage Mode is correct
                if ($obj.UsageMode) {
                    if ($obj.UsageMode -ine $lab.properties.userAccessMode) {
                        Write-Error "UsageMode doesn't match for this lab..."
                    }
                }

                # Validate the template settings (disabled/enabled) and provisioningState
                $template = $lab | Get-AzLabTemplateVm
                if (-not $template) {
                    Write-Error "Template doesn't exist for lab, the lab is broken..."
                }
                if ($template.properties.provisioningState -ine "Succeeded") {
                    Write-Error "Template object failed to be created for lab, the lab is broken..."
                }
                if ((Get-Member -InputObject $obj -Name 'TemplateVmState') -and ($obj.TemplateVmState -ieq "disabled")) {
                    $templateSetting = $false
                }
                else {
                    $templateSetting = $true
                }

                if ($template.properties.hasTemplateVm -ne $templateSetting) {
                    Write-Error "Template setting (enabled/disabled) doesn't match what's in the lab..."
                }

                # Validate the username is correct for accounts
                if ($obj.UserName -ine $template.properties.resourceSettings.referenceVm.userName) {
                    Write-Error "Username is incorrect in the lab template object..."
                }

                # Validate the VM size is set corectly
                if ($obj.Size -ine $template.properties.resourceSettings.vmSize) {
                    Write-Error "VM Size is not set correctly in the lab"
                }

                # Write something to the UI after checking lab settings
                Write-Host "Lab and template settings appear correct.."

                if ($expectedLabState -ieq "Published")
                {
                    # If we expect the lab to be published, validate the state of the template and student VMs
                    Write-Host "Template's publishing state is: $($template.properties.publishingState)"
                    if ($template.properties.publishingState -ne "Published") {
                        Write-Error "Publishing lab template failed"
                    }

                    # maxUsers is empty if using AAD groups, so compare against the max users in the lab
                    $vms = $lab | Get-AzLabVm -Status "Any"
                    if (($vms | Measure-Object).Count -ne $lab.properties.maxUsersInLab) {
                        Write-Error "Unexpected number of VMs"
                    }
    
                    $publishedVms = $vms | Where-Object { $_.properties.provisioningState -ieq "Succeeded" }
                    if (($publishedVMs | Measure-Object).Count -ne $lab.properties.maxUsersInLab) {
                        Write-Error "Unexpected number of VMs in succeeded state"
                    }
                }
        
                # TODO:  Validate SharedPassword is set correctly
                # TODO:  We should validate that the user quota is set correctly
                # TODO:  We should validate the GPU driver settings
                # TODO:  Validate the title & Description are set correctly
                # TODO:  validate Linux RDP is set to false
                # TODO:  If there are emails, validate those are setup for the lab
                # TODO:  If there are lab owners, validate they have the right permissions
                # TODO:  validate the settings (idleGracePeriod, idleOsGracePeriod, idleNoConnectGracePeriod)
                # TODO:  If there's a schedule, validate it is set correctly
                # TODO:  If there were invitations supposed to be sent out, validate that those were sent
            }

            $jobs = @()

            $ConfigObject | ForEach-Object {
                Write-Verbose "From config: $_"
                $jobs += Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot, $ExpectedLabState -InputObject $_ -Name ("$($_.ResourceGroupName)+$($_.LabAccountName)+$($_.LabName)") -ThrottleLimit $ThrottleLimit
            }

            while (($jobs | Measure-Object).Count -gt 0) {
                # If we have more jobs, wait for 60 sec before checking job status again
                Start-Sleep -Seconds 20

                $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
                if (($completedJobs | Measure-Object).Count -gt 0) {
                    # Write output for completed jobs, but one by one so output doesn't bleed 
                    # together, also use "Continue" so we write the error but don't end the outer script
                    $completedJobs | ForEach-Object {
                        # For each completed job we write the result back to the appropriate Config object, using the "name" field to coorelate
                        $jobName = $_.Name
                        $jobState = $_.State
                        $config = $ConfigObject | Where-Object {$_.ResourceGroupName -ieq $jobName.Split('+')[0] -and $_.LabAccountName -ieq $jobName.Split('+')[1] -and $_.LabName -ieq $jobName.Split('+')[2]}
                        $URL = $_ | Receive-Job -ErrorAction Continue

                        if (Get-Member -InputObject $config -Name ValidateLabResult) {
                            $config.ValidateLabResult = $jobState
                        }
                        else {
                            Add-Member -InputObject $config -MemberType NoteProperty -Name "ValidateLabResult" -Value $jobState
                        }
                    }
                    # Trim off the completed jobs from our list of jobs
                    $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
                    # Remove the completed jobs from memory
                    $completedJobs | Remove-Job
                }
            }
            # Return the objects with an additional property on the result of the operation
            return $ConfigObject
        }

        # Get-RegistrationLink-Jobs returns the config object with an additional column, we need to leave it on the pipeline
        Validate-AzLab-Jobs -ConfigObject $aggregateLabs
    }
}

function Set-LabProperty {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be created", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [Parameter(Mandatory = $true, ValueFromRemainingArguments=$true, HelpMessage = "Series of multiple -propertyName propValue pairs")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $vars
    )
    begin {
        #Convert vars to hashtable
        $htvars = @{}
        $vars | ForEach-Object {
            if($_ -match '^-') {
                #New parameter
                Write-Verbose $_
                $lastvar = $_ -replace '^-'
                $lastvar = $lastvar -replace ':' # passing parameters as hashtable inserts a : char
                $htvars[$lastvar] = $null
            } else {
                #Value
                $htvars[$lastvar] = $_
            }
        }
    }

    process {
        foreach ($l in $labs) {
            # Deep cloning not to change the original
            $lc = [System.Management.Automation.PSSerializer]::Deserialize(
                    [System.Management.Automation.PSSerializer]::Serialize($l))

            Write-Verbose ($lc | Out-String) 

            function ChangeLab ($lab) {
                $htvars.Keys | ForEach-Object { $lab.($_) = $htvars[$_]}
            }
            $lc | ForEach-Object { ChangeLab  $_}
            $lc
        }
    }
}

function Show-LabMenu {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be created", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [Parameter(Mandatory = $false, HelpMessage = "Pick one lab from the labs' list")]
        [switch]
        $PickLab,

        [Parameter(Mandatory = $false, HelpMessage = "Which lab properties to show a prompt for")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Properties
    )

    begin {

        function LabToString($lab, $index) {
            return "[$index]`t$($lab.Id)`t$($lab.ResourceGroupName)`t$($lab.LabName)"
        }

        $propsPassed = $PSBoundParameters.ContainsKey('Properties')
        $pickLabPassed = $PSBoundParameters.ContainsKey('PickLab')

        if($pickLabPassed) {
           Write-Host "LABS"
        }

        $aggregateLabs = @()
    }
    process {
        $aggregateLabs += $labs
    }
    end {

        if($pickLabPassed) {
            $index = 0
            $aggregateLabs | ForEach-Object { Write-Host (LabToString $_ ($index++)) }

            $resp = $null
            do {
                $resp = Read-Host -Prompt "Please select the lab to create"
                $resp = $resp -as [int]
                if($resp -eq $null) {
                    Write-Host "Not an integer.Try again." -ForegroundColor red
                }
                if($resp -and ($resp -ge $labs.Length -or $resp -lt 0)) {
                    Write-Host "The lab number must be between 0 and $($labs.Length - 1). Try again." -ForegroundColor red
                    $resp = $null
                }
            } until ($resp -ne $null)
            $aggregateLabs = ,$aggregateLabs[$resp]
        }

        if($propsPassed) {
            $hash = @{}
            $properties | ForEach-Object { $hash[$_] = Read-Host -Prompt "$_"}

            $aggregateLabs = $aggregateLabs | Set-LabProperty @hash
        }
        return $aggregateLabs
    }
}

# I am forced to use parameter names starting with 'An' because otherwise they get
# bounded automatically to the fields in the CSV and added to $PSBoundParameters
function Select-Lab {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Array containing one line for each lab to be created", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [psobject[]]
        $labs,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Id to look for")]
        [string]
        $AnId,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "If a lab contains any of these tags, it will be selected")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $SomeTags
    )

    begin {
        function HasAnyTags($foundTags) {
            $found = $false
            $SomeTags | ForEach-Object {
                if(($foundTags -split ';') -contains $_) {
                    $found = $true
                }
            }
            return $found
        }
    }
    process {

        $labs | ForEach-Object {
            Write-Verbose ($PSBoundParameters | Out-String)
            $IdPassed = $PSBoundParameters.ContainsKey('AnId')
            $TagsPassed = $PSBoundParameters.ContainsKey('SomeTags')
            $IdOk = (-not $IdPassed) -or ($_.Id.Trim() -eq $AnId)
            $TagsOk = (-not $TagsPassed) -or (HasAnyTags($_.Tags))

            Write-Verbose "$IdPassed $TagsPassed $IdOk $TagsOk"

            if($IdOk -and $TagsOk) {
                return $_
            }
        }
    }
}

Export-ModuleMember -Function   Import-LabsCsv,
                                New-AzLabsBulk,
                                New-AzLabAccountsBulk,
                                Remove-AzLabsBulk,
                                Publish-AzLabsBulk,
                                Sync-AzLabADUsersBulk,
                                Get-AzLabsRegistrationLinkBulk,
                                Reset-AzLabUserQuotaBulk,
                                Confirm-AzLabsBulk,
                                Set-AzRoleToLabAccountsBulk,
                                Set-LabProperty,
                                Set-LabPropertyByMenu,
                                Select-Lab,
                                Show-LabMenu,
                                Export-LabsCsv