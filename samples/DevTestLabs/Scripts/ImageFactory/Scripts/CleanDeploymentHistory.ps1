param
(
    [Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab to clean up")]
    [string] $DevTestLabName
)

function CleanRGDeployments($resourceGroup, $modulePath)
{
    $maxConcurrentJobs = 25
    $jobs = @()

    # Script block for deleting images
    $myCodeBlock = {
        Param($modulePath, $subscriptionId, $rgName, $deployName)
        Import-Module $modulePath
        LoadProfile
        Select-AzureRmSubscription -SubscriptionId $subscriptionId | Out-Null

        Write-Output "  Deleting $deployName"
        Remove-AzureRmResourceGroupDeployment -Name $deployName -ResourceGroupName $rgName | Out-Null
    }

    $subscriptionId = (Get-AzureRmContext).Subscription.Id
    $dateCutoff = (Get-Date).AddDays(-15)

    $allDeploys = Get-AzureRmResourceGroupDeployment -Id $resourceGroup.id

    $deleteDeploys = $allDeploys | Where-Object {$_.ProvisioningState -eq 'Succeeded' -or $_.Timestamp -lt $dateCutoff}

    Write-Output ("Deleting " + $deleteDeploys.Count + " of " + $allDeploys.Count + " deployments from " + $resourceGroup.Name)
    $copyCount = $deleteDeploys.Count
    $jobIndex = 0

    foreach ($deploymentToDelete in $deleteDeploys){
        #don't start more than $maxConcurrentJobs jobs at one time
        while ((Get-Job -State 'Running').Count -ge $maxConcurrentJobs){
            Write-Output "Throttling background tasks after starting $jobIndex of $copyCount tasks"
            Start-Sleep -Seconds 10
        }

        $jobIndex++
        $jobs += Start-Job -ScriptBlock $myCodeBlock -ArgumentList $modulePath, $subscriptionId, $deploymentToDelete.ResourceGroupName, $deploymentToDelete.DeploymentName
    }

    if($jobs.Count -ne 0)
    {
        Write-Output "Waiting for deployment deletion jobs to complete"
        foreach ($job in $jobs){
            Receive-Job $job -Wait | Write-Output
        }
        Remove-Job -Job $jobs
    }
}

$modulePath = Join-Path (Split-Path ($Script:MyInvocation.MyCommand.Path)) "DistributionHelpers.psm1"
Import-Module $modulePath
SaveProfile

$resourceGroups = Find-AzureRmResourceGroup | Where-Object {$_.Name.StartsWith($DevTestLabName, 'CurrentCultureIgnoreCase')}
foreach($resGroup in $resourceGroups)
{
    # We have deployed a lot of artifacts. Remove those deployments so we dont hit the 800 deployment limit for our lab RGs
    CleanRGDeployments $resGroup $modulePath
}
