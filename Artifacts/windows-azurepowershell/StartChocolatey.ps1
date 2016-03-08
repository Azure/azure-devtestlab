Param(
    #
    [ValidateNotNullOrEmpty()]
    $ProductId
)

Function Get-TempPassword() {
    Param(
        [int]$length=10,
        [string[]]$sourcedata
    )

    For ($loop=1; $loop -le $length; $loop++) {
            $tempPassword+=($sourcedata | GET-RANDOM)
    }

    return $tempPassword
}

$ascii=$NULL;For ($a=33;$a -le 126;$a++) {$ascii+=,[char][byte]$a }

$userName = "artifactInstaller"
$password = Get-TempPassword -length 43 -sourcedata $ascii

$cn = [ADSI]"WinNT://$env:ComputerName"

# Create user
$user = $cn.Create("User", $userName)
$user.SetPassword($password)
$user.SetInfo()
$user.description = "DevTestLab artifact installer"
$user.SetInfo()

# Add user to the Administrators group
$group = [ADSI]"WinNT://$env:ComputerName/Administrators,group"
$group.add("WinNT://$env:ComputerName/$userName")

$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$env:COMPUTERNAME\$($username)", $secPassword)

$command = $PSScriptRoot + "\InstallViaWebPICmd.ps1"
$scriptContent = Get-Content -Path $command -Delimiter ([char]0)
$scriptBlock = [scriptblock]::Create($scriptContent)

# Run Chocolatey as the artifactInstaller user
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Ensure that current process can run scripts. 
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

$exitCode = Invoke-Command -ScriptBlock $scriptBlock -Credential $credential -ComputerName $env:COMPUTERNAME -ArgumentList @($ProductId, $PSScriptRoot)
Disable-PSRemoting -Force

# Delete the artifactInstaller user
$cn.Delete("User", $userName)

# Delete the artifactInstaller user profile
gwmi win32_userprofile | where { $_.LocalPath -like "*$userName*" } | foreach { $_.Delete() }

exit $exitCode