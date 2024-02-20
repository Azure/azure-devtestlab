<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to 
the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.  

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

.SYNOPSIS
This script copies the existing tags from a DevTest Labs instance and applies them to all underlying
billable resources related to the lab.  This happens automatically if the tags are added to the lab
before VMs/Environments are created, this script is needed to apply new tags on a lab to existing
virtual machines or environments.

.PARAMETER ResourceGroupName
The name of the Azure Resource Group containing the DevTest Lab
.PARAMETER DevTestLabName
The name of the DevTest Lab.
#>

param
(
    [Parameter(Mandatory=$true, HelpMessage="The resource group name containing the DevTest Lab")]
    [string] $ResourceGroupName,

    [Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab to update")]
    [string] $DevTestLabName
)

$ErrorActionPreference = "Stop"

# Get the DevTest Lab
$lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.DevTestLab/labs" -ResourceName $DevTestLabName

# Get the lab's tags
$tags = $lab.Tags

# Get the Lab's unique identifier
$labUid = $lab.Properties.UniqueIdentifier

# only continue if we have tags on the lab
if ($tags) {
    Write-Host "Tags found on the Lab:"
    $tags | Format-Table | Out-String | Write-Host

    # Query for all resources with the lab's unique identifier, gives us all billable resources related to the lab
    $relatedResources = Get-AzResource -Tag @{"hidden-DevTestLabs-LabUId"=$labUid}

    # for each of the related resources, we need to add the Lab's tags
    $relatedResources | ForEach-Object {
        Write-Output "Updating Tags for resource Id: $($_.Id)"
        Update-AzTag -ResourceId $_.ResourceId -Tag $tags -Operation Merge | Out-Null
    }

    # Next, we need to find all the environments in the lab and update the tags on the resource groups
    $environments = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/users/environments' -ResourceName "$($DevTestLabName)/@all" -ApiVersion '2016-05-15'

    # for each of the environments, we need to add the Lab's tags
    $environments | ForEach-Object {
        Write-Output "Updating Tags for environment name: $($_.Name), Resource Group: $($_.ResourceGroupName)"
        Update-AzTag -ResourceId $_.Id -Tag $tags -Operation Merge | Out-Null
    }
}
else {
    Write-Host "No tags found on lab $DevTestLabName in resource group $ResourceGroupName"
}
