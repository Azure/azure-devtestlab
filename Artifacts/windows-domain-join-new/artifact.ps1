[CmdletBinding()]       
param
(
    [Parameter(Mandatory = $true)]
    [string] $DomainJoinUsername,

    [Parameter(Mandatory = $true)]
    [string] $DomainAdminUsername,

    [Parameter(Mandatory = $true)]
    [string] $DomainAdminPassword,

    [Parameter(Mandatory = $true)]
    [string] $DomainToJoin,

    [Parameter(Mandatory = $true)]
    [string] $OUPath
)

##############################
# Function returns the localized group name for the local administrator group
function Get-LocalAdminGroupName ()
{
    ([wmi]"Win32_SID.SID='S-1-5-32-544'").AccountName
}

#############################
# Function to find the members of a local machine group, usually administrators.
# Works around the cahnge in call pattern InvokeMember

function Get-LocalGroupMembersPs3to5 ([Parameter(Mandatory = $true)] [string] $GroupName)
{
    if ($PSVersionTable.PSVersion.Major -gt 4)
    {
        throw "This method id not supported on powershell 5 and greater"
    }
    $group = [ADSI]("WinNT://$env:COMPUTERNAME/$GroupName, group");
    $members = @($group.psbase.Invoke("Members"));
    $Details = @();

    $members | ForEach-Object {
        $name = $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
        $path = $_.GetType().InvokeMember("ADsPath", 'GetProperty', $null, $_, $null)
        $schema = $_.GetType().InvokeMember("Schema", 'GetProperty', $null, $_, $null)
       

        if ($schema -notlike "WinNT://$name/*")
        {
            $Type = "Domain"
            if ($path -like "*/$env:COMPUTERNAME/*")
            {
                $Type = "Local"
            }
           
            $Details += New-Object PSObject -Property @{"Account" = $name; "Type" = $type; }
        }
    }
    Write-Output "Members of $GroupName are:"
    $Details
}

##############################
# Function to find the members of a local machine group, usually administrators
function Get-LocalGroupMembers ([Parameter(Mandatory = $true)] [string] $GroupName)
{
    if ($PSVersionTable.PSVersion.Major -lt 5)
    {
        return Get-LocalGroupMembersPs3to5 $GroupName
    }

    $group = [ADSI]("WinNT://$env:COMPUTERNAME/$GroupName, group");
    $members = @($group.psbase.Invoke("Members"));
    $Details = @();
    
    $members | ForEach-Object {
        $name = $_.GetType.Invoke().InvokeMember("Name", 'GetProperty', $null, $_, $null)
        $path = $_.GetType.Invoke().InvokeMember("ADsPath", 'GetProperty', $null, $_, $null)
        $schema = $_.GetType.Invoke().InvokeMember("Schema", 'GetProperty', $null, $_, $null)

        if ($schema -notlike "WinNT://$name/*")
        {
            $Type = "Domain"
            if ($path -like "*/$env:COMPUTERNAME/*")
            {
                $Type = "Local"
            }
           
            $Details += New-Object PSObject -Property @{"Group" = $GroupName; "Account" = $name; "Type" = $type; }
        }
    }
    Write-Output "Members of $GroupName are:"
    $Details.ForEach( {$_}) | Format-Table -Property Account, Type -AutoSize
}
    
##############################
# Function to get the AD User string in format "WinNT://<domain>/<username>"
function Get-AdUsernameString ([Parameter(Mandatory = $true)] [string] $UserName)
{
    if ([string]::IsNullOrEmpty($Username)) 
    { 
        Write-Error "Username not provided"
        throw "Username not provided"
    }

    if ($Username -notmatch '\\')
    {
        $ADResolved = ($Username -split '@')[0]
        $DomainResolved = ($Username -split '@')[1]    
        $Username = 'WinNT://', "$DomainResolved", '/', $ADResolved -join ''
    }
    else
    {
        $ADResolved = ($Username -split '\\')[1]
        $DomainResolved = ($Username -split '\\')[0]
        $Username = 'WinNT://', $DomainResolved, '/', $ADResolved -join ''
    }
    return $Username
}

##############################
# Function to add an AD user to a local group
function Add-UserToLocalGroup ([Parameter(Mandatory = $true)] [string] $Username, [Parameter(Mandatory = $true)] [string] $GroupName)
{
    Write-Output "Attempting to add $DomainJoinUsername to the administrators group..."
    $adUser = Get-AdUsernameString $Username
    $group = [ADSI]("WinNT://$env:COMPUTERNAME/$GroupName, group")

    if ($group.IsMember($adUser))
    {
        Write-Output "Result: $Username already belongs to the $GroupName"
        return
    }
    $group.Add($adUser)
    
    if ($group.IsMember($adUser))
    {
        Write-Output "Result: $Username successfully added to $GroupName"
    }
    else
    {
        Write-Error "Result: failed to add $username to $GroupName"
    }
}

##############################
# Join computer to the domain
function Add-VmToDomain ([Parameter(Mandatory = $true)] [string] $VmName, 
    [Parameter(Mandatory = $true)] [string] $DomainName, 
    [Parameter(Mandatory = $true)] [string] $JoinUser, 
    [Parameter(Mandatory = $true)] [securestring] $JoinPassword, 
    [Parameter(Mandatory = $true)] [string] $OU)
{
    Write-Output "Attempting to join the domain..."

    if ((Get-WmiObject Win32_ComputerSystem).Domain -eq $DomainToJoin)
    {
        Write-Output "Computer is already joined to $DomainToJoin"
    }
    else
    {
        $credential = New-Object System.Management.Automation.PSCredential($JoinUser, $securePass)
    
        [Microsoft.PowerShell.Commands.ComputerChangeInfo]$computerChangeInfo = Add-Computer -ComputerName $VmName -DomainName $DomainName -Credential $credential -OUPath $OU -Force -PassThru
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
    $adminGroupName = Get-LocalAdminGroupName
    $securePass = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
    Add-VmToDomain -VmName $env:COMPUTERNAME -DomainName $DomainToJoin -JoinUser $DomainAdminUsername -JoinPassword $securePass -OU $OUPath
    Add-UserToLocalGroup -Username $DomainJoinUsername -GroupName $adminGroupName
    Get-LocalGroupMembers $adminGroupName
}


