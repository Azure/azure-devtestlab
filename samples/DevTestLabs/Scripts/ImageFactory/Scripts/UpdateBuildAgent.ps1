param
(
    [Parameter(Mandatory=$true, HelpMessage="The ID of the subscription containing the Image Factory")]
    [string] $SubscriptionId,
    
    [Parameter(Mandatory=$true, HelpMessage="The name of the Image Factory DevTest Lab")]
    [string] $DevTestLabName,

	[Parameter(Mandatory=$true, HelpMessage="The name of the build agent")]
    [string] $BuildAgent,

	[Parameter(Mandatory=$true, HelpMessage="Either Start or Stop to apply an action to the Virtual Machine")]
    [string] $Action

)

# find the build agent in the subscription
$ResourceGroupName = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}).ResourceGroupName
$agentVM = Get-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.DevTestLab/labs/virtualmachines -ResourceName $DevTestLabName -ApiVersion 2016-05-15 | Where-Object {$_.Name -eq $BuildAgent}

if ($agentVM -ne $null) {

    # Update the agent via DevTest Labs with the specified action (start or stop)
    $status = Invoke-AzureRmResourceAction -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.DevTestLab/labs/virtualmachines -ResourceName ($DevTestLabName + "/" + $BuildAgent) -Action $Action -ApiVersion 2016-05-15 -Force

    if ($status.Status -eq 'Succeeded') {
        Write-Output "##[section] Successfully updated VSTS Build Agent: $BuildAgent , Action: $Action"
    }
    else {
        Write-Error "##[error]Failed to update the VSTS Build Agent: $BuildAgent , Action: $Action"
    }
}
else {
    Write-Error "##[error]$BuildAgent was not found in the DevTest Lab, unable to update the agent"
}

