Function Get-TempPassword {
    Param(
        [int]$length=10,
        [string[]]$sourcedata
    )

    For ($loop=1; $loop -le $length; $loop++) {
        $tempPassword+=($sourcedata | GET-RANDOM)
    }

    return $tempPassword
}

Function Try-Install-Service-Fabric {
    Param (
        [string] $vsVersion,
        [string] $packageVersion,
        [System.Management.Automation.PSCredential] $credential
    )

    $exitCode = 0

    try
    {
        if (Get-Item -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\$vsVersion)
        {
            $command = $PSScriptRoot + "\InstallViaWebPICmd.ps1"
            $scriptContent = Get-Content -Path $command -Delimiter ([char]0)
            $scriptBlock = [scriptblock]::Create($scriptContent)
            $ProductId = 'MicrosoftAzure-ServiceFabric-{0}' -f $packageVersion
            $exitCode = Invoke-Command -ScriptBlock $scriptBlock -Credential $credential -ComputerName $env:COMPUTERNAME -ArgumentList @($ProductId, $PSScriptRoot)
        }
    }
    catch
    {
        Write-Warning('Visual Studio {0} not found. Skipping installation...' -f $vsVersion)
    }

    return $exitCode
}

$exitCode = 0

$userName = "artifactInstaller"
$ascii=$NULL;For ($a=33;$a -le 126;$a++) {$ascii+=,[char][byte]$a }
$password = Get-TempPassword -length 43 -sourcedata $ascii
$cn = [ADSI]"WinNT://$env:ComputerName"

try
{
    $ErrorActionPreference = "Stop"

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
    
    # Run Chocolatey as the artifactInstaller user
    Enable-PSRemoting -Force -SkipNetworkProfileCheck

    # Ensure that current process can run scripts. 
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

    # Try to install service fabric
    $exitCodeVS2015 = Try-Install-Service-Fabric "14.0" "VS2015" $credential
    $exitCodeDev15 = Try-Install-Service-Fabric "15.0" "Dev15" $credential
    
    if ($exitCodeVS2015 -eq -1 -or $exitCodeDev15 -eq -1)
    {
        $exitCode = -1;
    }
}
catch
{
    $exitCode = -1
}
finally
{
    $ErrorActionPreference = "Continue"

    # Delete the artifactInstaller user
    $cn.Delete("User", $userName)
    
    # Delete the artifactInstaller user profile
    gwmi win32_userprofile | where { $_.LocalPath -like "*$userName*" } | foreach { $_.Delete() }
}

if ($exitCode -eq -1)
{
    exit -1;
}
return 0
