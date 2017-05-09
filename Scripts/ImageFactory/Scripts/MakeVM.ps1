param
(
    [Parameter(Mandatory=$true, HelpMessage="The full path to the module to import")]
    [string] $ModulePath,
    
    [Parameter(Mandatory=$true, HelpMessage="The full path of the template file")]
    [string] $TemplateFilePath,
    
    [Parameter(Mandatory=$true, HelpMessage="The name of the lab")]
    [string] $DevTestLabName,
    
    [Parameter(Mandatory=$true, HelpMessage="The name of the VM to create")]
    [string] $vmName,
    
    [Parameter(Mandatory=$true, HelpMessage="The path to the image file")]
    [string] $imagePath,
    
    [Parameter(Mandatory=$true, HelpMessage="The admin username for the VM")]
    [string] $machineUserName,
    
    [Parameter(Mandatory=$true, HelpMessage="The admin password for the VM")]
    [System.Security.SecureString] $machinePassword,

    [Parameter(Mandatory=$true, HelpMessage="The name of the lab")]
    [string] $vmSize
)

Import-Module $ModulePath

LoadProfile

Write-Output "Starting Deploy for $TemplateFilePath"

#if the VM already exists then we fail out.
$existingVms = Find-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceNameContains $DevTestLabName | Where-Object { $_.Name -eq "$DevTestLabName/$vmName"}
if($existingVms.Count -ne 0){
    Write-Error "Factory VM creation failed because there is an existing VM named $vmName in Lab $DevTestLabName"
    return ""
}
else {
    $deployName = "Deploy-$vmName"
    $ResourceGroupName = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}).ResourceGroupName
    
    $vmDeployResult = New-AzureRmResourceGroupDeployment -Name $deployName -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath -labName $DevTestLabName -newVMName $vmName  -userName $machineUserName -password $machinePassword -size $vmSize
    
    #delete the deployment information so that we dont use up the total deployments for this resource group
    Remove-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deployName  -ErrorAction SilentlyContinue | Out-Null

    if($vmDeployResult.ProvisioningState -eq "Succeeded"){
        #set the imagePath tag on the VM
        Write-Output "Stamping the VM $vmName with originalImageFile $imagePath"
        $existingVm = Find-AzureRmResource -ResourceType "Microsoft.DevTestLab/labs/virtualMachines" -ResourceNameContains $DevTestLabName | Where-Object { $_.Name -eq "$DevTestLabName/$vmName"}

        #Determine if artifacts succeeded
        Write-Output "Determining artifact status."
        $filter = '$expand=Properties($expand=ComputeVm,NetworkInterface,Artifacts)'
        $vmResource = Get-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines' -Name $existingVm.Name -ResourceGroupName $existingVm.ResourceGroupName -ODataQuery $filter
        $existingVmArtStatus = $vmResource.Properties.ArtifactDeploymentStatus
        if ($existingVmArtStatus.totalArtifacts -eq 0 -or $existingVmArtStatus.deploymentStatus -eq "Succeeded")
        {
            Write-Output "##[section]Successfully deployed $vmName from $imagePath"

            $tags = $existingVm.Tags
            if((get-command -Name 'New-AzureRmResourceGroup').Parameters["Tag"].ParameterType.FullName -eq 'System.Collections.Hashtable'){
                # Azure Powershell version 2.0.0 or greater - https://github.com/Azure/azure-powershell/blob/v2.0.1-August2016/documentation/release-notes/migration-guide.2.0.0.md#change-of-tag-parameters
                $tags += @{ImagePath=$imagePath}
            }
            else {
                # older versions of the cmdlets use a hashtable array to represent the Tags
                $tags += @{Name="ImagePath";Value="$imagePath"}
            }

            Write-Output "Getting resource ID from Existing Vm"
            $vmResourceId = $existingVm.ResourceId 
            Write-Output "Resource ID: $vmResourceId"
            Set-AzureRmResource -ResourceId $vmResourceId -Tag $tags -Force
        }
        else
        {
            if ($existingVmArtStatus.deploymentStatus -ne "Succeeded")
            {
                Write-Error ("##[error]Artifact deployment status is: " + $existingVmArtStatus.deploymentStatus)
            }
            Write-Error "##[error]Deploying VM artifacts failed. $vmName from $TemplateFilePath. Failure details follow:"
            $failedArtifacts = ($vmResource.Properties.Artifacts | Where-Object {$_.status -eq 'failed'})
            if($failedArtifacts -ne $null)
            { 
                foreach($failedArtifact in $failedArtifacts)
                {
                    Write-Output ('Failed Artifact ID: ' + $failedArtifact.artifactId)
                    Write-Output ('   ' + $failedArtifact.deploymentStatusMessage)
                    Write-Output ('   ' + $failedArtifact.vmExtensionStatusMessage)
                    Write-Output ''
                }
            }

            Write-Output "Deleting VM $vmName after failed artifact deployment"
            Remove-AzureRmResource -ResourceId $existingVm.ResourceId -ApiVersion 2016-05-15 -Force
        }
    }
    else {
        Write-Error "##[error]Deploying VM failed:  $vmName from $TemplateFilePath"
    }

    return $vmName
}
