Param (
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [String] $Username,

    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$true)]
    [String] $Password
)

$cn = [ADSI]"WinNT://$env:ComputerName"

# Create user
$user = $cn.Create("User", $Username)
$user.SetPassword($Password)
$user.SetInfo()
$user.description = "Created by artifact"
$user.SetInfo()

# Add user to the Administrators group
$group = [ADSI]"WinNT://$env:ComputerName/Administrators,group"
$group.add("WinNT://$env:ComputerName/$userName")