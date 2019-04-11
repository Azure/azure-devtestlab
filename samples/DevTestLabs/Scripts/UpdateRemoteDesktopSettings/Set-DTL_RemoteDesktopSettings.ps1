<#

.SYNOPSIS
This script leverages Azure Powershell to update the Remote Desktop settings in an Azure DevTest Lab.

.DESCRIPTION
The script updates the DevTest Lab's extended properties to include the experience 
level and/or the gateway settings.  When a user clicks "connect" on a Virtual Machine, 
the RDP file that's generated includes these settings.  In this way, IT admins or 
DevTest Lab Owners can configure the appropriate remote desktop settings for the 
environment and the uesrs can just leverage it seamlessly.

RemoteDesktopGateway:  Must be a fully qualified name like customrds.eastus.cloudapp.azure.com or an IP address

Experience Level:  Must be an integer from 1 to 7, following this table:
    1  -  Modem (56 kbps)
    2  -  Low-speed broadband (256kbps – 2 Mbps)
    3  -  Satellite (2 Mbps – 16 Mbps with high latency)
    4  -  High-speed broadband (2 Mbps – 10 Mbps)
    5  -  WAN (10 Mbps or higher with high latency)
    6  -  LAN (10 Mbps or higher)
    7  -  Detect connection quality automatically

.EXAMPLE
.\Set-DTL_RemoteDesktopSettings.ps1 -DevTestLabName "PeteDevBoxes" -RemoteDesktopGateway "customrds.eastus.cloudapp.azure.com" -ExperienceLevel 2

.LINK
https://github.com/Azure/azure-devtestlab/tree/master/Scripts

#>

param
(
    [Parameter(ParameterSetName="ResourceGroupAndLabName", Mandatory=$true, HelpMessage="The Resource group containing the DevTest Lab")]
    [string] $ResourceGroupName,

    [Parameter(ParameterSetName="ResourceGroupAndLabName", Mandatory=$true, HelpMessage="The name of the DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(ParameterSetName="ResourceId", Mandatory=$true, HelpMessage="The Resource Id of the DevTest Lab")]
    [string] $DevTestLabResourceId,

    [Parameter(HelpMessage="The server name of the remote desktop host.  This cane be a fully qualitified name or an IP address of the gateway")]
    [string] $RemoteDesktopGateway,

    [Parameter(HelpMessage="The remote desktop experience level")]
    [ValidateSet(1, 2, 3, 4, 5, 6, 7)]
    [int] $ExperienceLevel
)

function Update-Member ($labProperties, $fieldName, $fieldValue) {

    # Validate properties
    if ($labProperties -and $fieldName) {
        # If we've never set extended properties in the lab, need to create the top level item
        if ($lab.Properties.extendedProperties -eq $null) {
            Add-Member -InputObject $lab.Properties -Name "extendedProperties" -MemberType NoteProperty -Value (New-Object PSObject)
        }
        
        if ($fieldValue) {
            # Update the value if that parameter isn't null
            if (Get-Member -InputObject $labProperties.extendedProperties -Name $fieldName) {
                # set the property directly since it already exists
                $labProperties.extendedProperties.$fieldName = $fieldValue
            }
            else {
                # add a new property since it doesn't already exist
                Add-Member -InputObject $labProperties.extendedProperties -MemberType NoteProperty -Name $fieldName -Value $fieldValue
            }
        }
        else {
            # Clear out the field since the parameter is null, remove the property if it exists
            if (Get-Member -InputObject $labProperties.extendedProperties -Name $fieldName) {
                $lab.Properties.extendedProperties.PSObject.Properties.Remove($fieldName)
            }
        }
    }
    else {
        Write-Error "Invalid properties, cannot update"
    }
}

if ($PSCmdlet.ParameterSetName -eq "ResourceGroupAndLabName") {
    # Get the lab with the Resource Group Name and the Lab Name
    $lab = Get-AzureRmResource -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType "Microsoft.DevTestLab/labs" -ApiVersion "2018-10-15-preview"
}
else {
    # Get the lab wit hthe Resource Id
    $lab = Get-AzureRmResource -ResourceId $DevTestLabResourceId -ApiVersion "2018-10-15-preview"
}


if ($lab) {
    # Update the fields if they are not null
    if ($ExperienceLevel) {
        Update-Member $lab.Properties "RdpConnectionType" $ExperienceLevel
    }
    if ($RemoteDesktopGateway) {
        Update-Member $lab.Properties "RdpGateway" $RemoteDesktopGateway
    }

    # In the case that both fields are null, let's clear them both out
    if (-not $ExperienceLevel -and -not $RemoteDesktopGateway) {
        Update-Member $lab.Properties "RdpConnectionType" $ExperienceLevel
        Update-Member $lab.Properties "RdpGateway" $RemoteDesktopGateway
    }

    # Update the lab
    Set-AzureRmResource -ResourceId $lab.ResourceId -Properties $lab.Properties -ApiVersion "2018-10-15-preview" -Force | Out-Null

    Write-Output "Update of Lab properties completed"
}
else {
    if ($PSCmdlet.ParameterSetName -eq "ResourceGroupAndLabName") {
        Write-Error "Unable to find the Lab named $DevTestLabName in Resource Group $ResourceGroupName"
    }
    else {
        Write-Error "Unable to find the lab with the Resource Id: $DevTestLabResourceId"
    }
}
