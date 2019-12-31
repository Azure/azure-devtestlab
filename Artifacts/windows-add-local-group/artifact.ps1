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

    if ([string]::IsNullOrEmpty($Username)) 
    { 
        throw "Username not provided"
    }

    if ($Username -contains '@')
    {
        $user = ($Username -split '@')[0]
        $domain = ($Username -split '@')[1]    
    }
    elseif ($Username -contains '\\')
    {
        $user = ($Username -split '\\')[1]
        $domain = ($Username -split '\\')[0]
    }
    else
    {
        $user = $username
        $domain = $env:COMPUTERNAME
    }

    #Get the local group
    $group = [ADSI]("WinNT://$env:COMPUTERNAME/$GroupName, group")
    $Members = @($group.psbase.Invoke("Members"))
    #Populate the $MemberNames array with all the user ID's
    $MemberNames = @()
    $Members | ForEach-Object {$MemberNames += $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null);}

    #See if your user ID is in there
    if (-Not $MemberNames.Contains($user)) {
        $group.Add("WinNT://$domain/$user")
    }
    else {
        Write-Output "Result: $Username already belongs to the $GroupName"
        return
    }
}

##############################
# Main function

if (Test-LocalGroupExists -GroupName $localGroupName) {
    Add-UserToLocalGroup -Username $username -GroupName $localGroupName
}
else {
    Write-Error "Local Group $localGroupName does not exist on the target machine."
}