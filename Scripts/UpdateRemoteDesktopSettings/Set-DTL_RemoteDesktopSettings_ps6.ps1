<#

.SYNOPSIS
This script leverages Azure Powershell to update the Remote Desktop settings in an Azure DevTest Lab.

.DESCRIPTION
The script updates the DevTest Lab's extended properties to include the experience level and/or the gateway settings.  When a user clicks "connect" on a Virtual Machine, the RDP file that's generated includes these settings.  In this way, IT admins or DevTest Lab Owners can configure the appropriate remote desktop settings for the environment and the uesrs can just leverage it seamlessly.

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
.\Set-DTL_RemoteDesktopSettings_ps6.ps1 -DevTestLabName "PeteDevBoxes" -RemoteDesktopGateway "customrds.eastus.cloudapp.azure.com" -ExperienceLevel 2

.LINK
https://github.com/Azure/azure-devtestlab/tree/master/Scripts

#>

param
(
    [Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab")]
    [string] $DevTestLabName,

    [Parameter(HelpMessage="The server name of the remote desktop host.  This cane be a fully qualitified name or an IP address of the gateway")]
    [string] $RemoteDesktopGateway,

    [Parameter(HelpMessage="The remote desktop experience level")]
    [ValidateSet(1, 2, 3, 4, 5, 6, 7)]
    [int] $ExperienceLevel
)

function Update-Member ($labProperties, $fieldName, $fieldValue) {
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
        # NOTE:  There isn't a "Remove-Member" so we have to do some converstions to remove the field
        if (Get-Member -InputObject $labProperties.extendedProperties -Name $fieldName) {
            $lab.Properties.extendedProperties.PSObject.Properties.Remove($fieldName)
        }
    }
}

# Get the DevTest Lab
$lab = Get-AzureRmResource -Name $DevTestLabName -ResourceType "Microsoft.DevTestLab/labs" -ApiVersion "2017-04-26-preview"

if ($lab -eq $null) {
    Write-Error "Unable to find the Lab named $DevTestLabName in Subscription $SubscriptionId"
}
else {
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
    Set-AzureRmResource -ResourceId $lab.ResourceId -Properties $lab.Properties -ApiVersion "2017-04-26-preview" -Force
}
