Function Get-TempPassword() {
    Param (
        [int]       $length = 10,
        [string[]]  $sourcedata
    )

    For ($loop = 1; $loop -le $length; $loop++) {
        $tempPassword += ($sourcedata | GET-RANDOM)
    }

    Write-Host "Generated password : $tempPassword"
    return $tempPassword
}

$ascii = $NULL;
For ($a = 33; $a -le 126; $a++) {
    if ($a -eq 34 -or $a -eq 39 -or $a -eq 96) {
        # exclude complex symbols : ' " `
        continue
    }
    $ascii+=,[char][byte]$a
}

$userName = "artifactInstaller"
$password = Get-TempPassword -length 43 -sourcedata $ascii

# Create user
$cn = [ADSI]"WinNT://$env:ComputerName"
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

Enable-PSRemoting -force -SkipNetworkProfileCheck

$vsInstallScript = [IO.Path]::Combine($PSScriptRoot, 'UpdateWindows.ps1')
$runProcessFile = [IO.Path]::Combine($PSScriptRoot, 'run_process_as_scheduled_task.ps1')
Test-Path $runProcessFile
Write-Host $runProcessFile


# Run script now
$newProcess = new-object System.Diagnostics.ProcessStartInfo "powershell";
$newProcess.Arguments = "-ExecutionPolicy Bypass -NoProfile -File " + $runProcessFile + " `"" + $vsInstallScript + "`" `` " + $userName + " " + $password
Write-Host $newProcess.Arguments
$newProcess.Verb = "runas";
$process = [System.Diagnostics.Process]::Start($newProcess);
$process.WaitForExit();
Write-Host ("InstallVS: " + $process.ExitCode)


# Cleanup
Disable-PSRemoting -Force
$cn.Delete("User", $userName)
gwmi win32_userprofile | where { $_.LocalPath -like "*$userName*" } | foreach { $_.Delete() }

if ($process.ExitCode -eq 3010)
{
    Write-Host ("Restarting the machine as exit code 3010 was received")
    $newProcess = new-object System.Diagnostics.ProcessStartInfo "shutdown";
    $newProcess.Arguments = "-r -t 0 -f"
    Write-Host $newProcess.Arguments
    $newProcess.Verb = "runas";
    $process = [System.Diagnostics.Process]::Start($newProcess);
    $process.WaitForExit();
    $process.ExitCode
    exit 0
}

exit $process.ExitCode