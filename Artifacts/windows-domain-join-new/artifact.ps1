[CmdletBinding()]       
param
(
    [Parameter(Mandatory = $true)]
    [string] $domainJoinUsername,

    [Parameter(Mandatory = $true)]
    [string] $domainAdminUsername,

    [Parameter(Mandatory = $true)]
    [string] $domainAdminPassword,

    [Parameter(Mandatory = $true)]
    [string] $domainToJoin,

    [Parameter(Mandatory = $true)]
    [string] $ouPath
    
)

##############################
# Method to find the members of a local machine group, usually administrators

function Get-LocalGroupMembers ($groupName)
{
    $group = [ADSI]("WinNT://$env:COMPUTERNAME/$groupName, group");
    $members = @($group.psbase.Invoke("Members"));
    $Details = @();

    $members | ForEach-Object {
        $name = $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
        $path = $_.GetType().InvokeMember("ADsPath", 'GetProperty', $null, $_, $null)
        $schema = $_.GetType().InvokeMember("Schema", 'GetProperty', $null, $_, $null)

        if ($schema -notlike "WinNT://$name/*")
        {
            $Type = "Domain"
            if ($path -like "*/$Computer/*")
            {
                $Type = "Local"
            }
           
            $Details += New-Object PSObject -Property @{"Group" = $groupName; "Account" = $name; "Type" = $type; }
        }
    }
    return $Details.ForEach( {$_}) | Format-Table -Property Account, Type, Group -AutoSize
}

##############################
# Main function

if ($PSVersionTable.PSVersion.Major -lt 3)
{
    Write-Error "The current version of PowerShell is $($PSVersionTable.PSVersion.Major). Prior to running this artifact, ensure you have PowerShell 3 or higher installed."
}
else
{
    $securePass = ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($domainAdminUsername, $securePass)

    Write-Output "Attempting to join the domain..."
    [Microsoft.PowerShell.Commands.ComputerChangeInfo]$computerChangeInfo = Add-Computer -ComputerName $env:COMPUTERNAME -DomainName $domainToJoin -Credential $credential -OUPath $ouPath -Force -PassThru

    if ($computerChangeInfo.HasSucceeded)
    {
        Write-Output "Successfully joined the $domaintoJoin domain"

        Write-Output "Attempting to add $domainJoinUsername to the administrators group..."
        if ([string]::IsNullOrEmpty($domainJoinUsername)) 
        { 
            $results = "Username not provided"
        }
        else
        {
            $results = Invoke-Expression -Command "net localgroup administrators $domainJoinUsername /add"
        }
        Write-Output "Result: $results"
        Get-LocalGroupMembers "Administrators"
    }
    else
    {
        Write-Error "Failed to join $env:COMPUTERNAME to $domaintoJoin domain"
    }
}


