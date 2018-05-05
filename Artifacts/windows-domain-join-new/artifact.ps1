[CmdletBinding()]       
param
(
    [Parameter(Mandatory = $true)]
    [string] $DomainAdminUsername,

    [Parameter(Mandatory = $true)]
    [string] $DomainAdminPassword,

    [Parameter(Mandatory = $true)]
    [string] $DomainToJoin,

    [Parameter(Mandatory = $false)]
    [string] $OUPath
)

##############################
# Join computer to the domain
function Add-VmToDomain ()
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string] $VmName,

        [Parameter(Mandatory = $true)]
        [string] $DomainName,

        [Parameter(Mandatory = $true)]
        [string] $JoinUser,

        [Parameter(Mandatory = $true)]
        [securestring] $JoinPassword,

        [Parameter(Mandatory = $false)]
        [string] $OU
    )

    if ((Get-WmiObject Win32_ComputerSystem).Domain -eq $DomainToJoin)
    {
        Write-Output "Computer is already joined to $DomainToJoin"
    }
    else
    {
        $credential = New-Object System.Management.Automation.PSCredential($JoinUser, $JoinPassword)
        if($OU) {   
            [Microsoft.PowerShell.Commands.ComputerChangeInfo]$computerChangeInfo = Add-Computer -ComputerName $VmName -DomainName $DomainName -Credential $credential -OUPath $OU -Force -PassThru
        } else {
            [Microsoft.PowerShell.Commands.ComputerChangeInfo]$computerChangeInfo = Add-Computer -ComputerName $VmName -DomainName $DomainName -Credential $credential -Force -PassThru
        }
        if ($computerChangeInfo.HasSucceeded)
        {
            Write-Output "Result: Successfully joined the $DomaintoJoin domain"
        }
        else
        {
            Write-Error "Result: Failed to join $env:COMPUTERNAME to $DomaintoJoin domain"
        }
    }
}

##############################
# Main function

if ($PSVersionTable.PSVersion.Major -lt 3)
{
    Write-Error "The current version of PowerShell is $($PSVersionTable.PSVersion.Major). Prior to running this artifact, ensure you have PowerShell 3 or higher installed."
}

else
{
    $securePass = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
    Write-Output "Attempting to join the domain..."
    Add-VmToDomain -VmName $env:COMPUTERNAME -DomainName $DomainToJoin -JoinUser $DomainAdminUsername -JoinPassword $securePass -OU $OUPath
}


