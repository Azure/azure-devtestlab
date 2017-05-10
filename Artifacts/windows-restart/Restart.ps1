$newProcess = new-object System.Diagnostics.ProcessStartInfo "shutdown";
$newProcess.Arguments = "-r -t 0 -f"
Write-Host $newProcess.Arguments
$newProcess.Verb = "runas";
$process = [System.Diagnostics.Process]::Start($newProcess);
$process.WaitForExit();
$process.ExitCode
Write-Host ("Reboot exitcode : " + $process.ExitCode)