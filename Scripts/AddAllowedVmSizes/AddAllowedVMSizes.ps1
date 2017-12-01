<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

.SYNOPSIS
This script adds the specified set of VM sizes to the list of allowed sizes in the specified lab
.PARAMETER DevTestLabName
The name of the lab.
.PARAMETER SizesToAdd
The name(s) of the Sizes to add. View the list of available sizes in the 'Configuration -> Allowed virtual machine sizes' blade in the Azure Portal
#>

param
(
    [Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab to update")]
    [string] $DevTestLabName,

    [Parameter(Mandatory=$true, HelpMessage="The array of VM Sizes to be added")]
    [Array] $SizesToAdd
)

$lab = Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' -ResourceNameEquals $DevTestLabName

if(!$lab)
{
    throw "Lab named $DevTestLabName was not found"
}

$labResourceName = $lab.Name + '/default'
$existingPolicy = (Get-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs/policySets/policies' -ResourceName $labResourceName -ResourceGroupName $lab.ResourceGroupName -ApiVersion 2016-05-15) | Where-Object {$_.Name -eq 'AllowedVmSizesInLab'}
if($existingPolicy)
{
    $existingSizes = $existingPolicy.Properties.threshold
    $savePolicyChanges = $false
}
else
{
    $existingSizes = ''
    $savePolicyChanges = $true
}

# Make a list of all the sizes. It needs all their current sizes as well as any from our list that arent already there
$finalVmSizes = $existingSizes.Replace('[', '').Replace(']', '').Split(',',[System.StringSplitOptions]::RemoveEmptyEntries)

foreach($vmSize in $SizesToAdd)
{
    $quotedSize = '"' + $vmSize + '"'

    if(!$finalVmSizes.Contains($quotedSize))
    {
        $finalVmSizes += $quotedSize
        $savePolicyChanges = $true
    }
}

if($savePolicyChanges)
{
    $policyObj = @{
        subscriptionId = $lab.SubscriptionId
        factName = 'LabVmSize'
        status = 'Enabled'
        resourceGroupName = $lab.ResourceGroupName
        labName = $lab.Name
        policySetName = 'default'
        name = $lab.Name + '/default/allowedvmsizesinlab'
        evaluatorType = 'AllowedValuesPolicy'
        threshold = ('[' + [String]::Join(',', $finalVmSizes) + ']')
    }

    $resourceType = "Microsoft.DevTestLab/labs/policySets/policies/AllowedVmSizesInLab"
    if($existingPolicy)
    {
        Write-Output "Updating $($lab.Name) VM Size policy"
        Set-AzureRmResource -ResourceType $resourceType -ResourceName $labResourceName -ResourceGroupName $lab.ResourceGroupName -ApiVersion 2016-05-15 -Properties $policyObj -Force
    }
    else
    {
        Write-Output "Creating $($lab.Name) VM Size policy"
        New-AzureRmResource -ResourceType $resourceType -ResourceName $labResourceName -ResourceGroupName $lab.ResourceGroupName -ApiVersion 2016-05-15 -Properties $policyObj -Force
    }
}
else
{
    Write-Output "No policy changes required for VMSize in lab $($lab.Name)"
}
