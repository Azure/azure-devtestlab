[CmdletBinding()]       
param
(
    [Parameter(Mandatory = $true)]
    [string] $username,
    [Parameter(Mandatory = $true)]
    [string] $localGroupName
)

##############################
# Function to check if the local group exists
function Test-LocalGroupExists ()
{
    param
    (
        [Parameter(Mandatory = $true)] 
        [string] $GroupName
    )
    
    $result = try { [ADSI]::Exists("WinNT://$env:COMPUTERNAME/$GroupName") } catch { $False }

    return $result
}

#############################
# Function to find the members of a local machine group, usually administrators.
# Works around the cahnge in call pattern InvokeMember
function Get-LocalGroupMembersPs3to5 ()
{
    param
    (
        [Parameter(Mandatory = $true)] 
        [string] $GroupName
    )
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
    return $Details
}

##############################
# Function to find the members of a local machine group, usually administrators
function Get-LocalGroupMembers ()
{
    param
    (
        [Parameter(Mandatory = $true)] 
        [string] $GroupName
    )

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
    return $Details
}
    
##############################
# Function to get the Fully Qualified User string in format "WinNT://<machinename|domain>/<username>"
function Get-UsernameString ()
{
    param
    (
        [Parameter(Mandatory = $true)] 
        [string] $UserName
    )
    if ([string]::IsNullOrEmpty($Username)) 
    { 
        throw "Username not provided"
    }

    if ($Username -contains '@')
    {
        Write-Output "$Username contains ampersand."
        $ADResolved = ($Username -split '@')[0]
        $DomainResolved = ($Username -split '@')[1]    
    }
    elseif ($Username -contains '\\')
    {
        Write-Output "$Username contains backslash."
        $ADResolved = ($Username -split '\\')[1]
        $DomainResolved = ($Username -split '\\')[0]
    }else
    {
        $ADResolved = $UserName
        $DomainResolved = ""
    }

    if($DomainResolved -eq "" -or $DomainResolved -eq ".")
    {
        Write-Output "Result: $Username is local user."
        return "WinNT://$env:COMPUTERNAME/$ADResolved, user"
    }
    else {
        Write-Output "Result: $Username is domain user."
        return "WinNT://$DomainResolved/$ADResolved, user"   
    }
}

##############################
# Function to add the user to a local group
function Add-UserToLocalGroup ()
{
    param
    (
        [Parameter(Mandatory = $true)] 
        [string] $Username, 
        
        [Parameter(Mandatory = $true)] 
        [string] $GroupName
    )
    Write-Output "Attempting to add $Username to the local group..."
    $user = Get-UsernameString $Username
    $group = [ADSI]("WinNT://$env:COMPUTERNAME/$GroupName, group")

    Write-Output "Is $user already a member of the local group $GroupName"

    if ($group.IsMember($user))
    {
        Write-Output "Result: $Username already belongs to the $GroupName"
        return
    }

    Write-Output "Adding $user as a member of the local group $GroupName"
    $group.Add($user)
    
    if ($group.IsMember($user))
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

if (Test-LocalGroupExists -GroupName $localGroupName) {
    Add-UserToLocalGroup -Username $username -GroupName $localGroupName

    Write-Output "Members of $localGroupName are:"
    Get-LocalGroupMembers $localGroupName   
}
else {
    Write-Error "Result: Local Group $localGroupName does not exist on the target machine."
}