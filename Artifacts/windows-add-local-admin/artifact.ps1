[CmdletBinding()]       
param
(
    [Parameter(Mandatory = $true)]
    [string] $DomainJoinUsername
)

##############################
# Function returns the localized group name for the local administrator group
function Get-LocalAdminGroupName ()
{
    #well known SID for the Administrators group
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
# Main function
$adminGroupName = Get-LocalAdminGroupName
Add-UserToLocalGroup -Username $DomainJoinUsername -GroupName $adminGroupName
Get-LocalGroupMembers $adminGroupName