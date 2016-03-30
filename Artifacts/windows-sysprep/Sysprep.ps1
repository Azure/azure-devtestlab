$newProcess = new-object System.Diagnostics.ProcessStartInfo "sysprep.exe" 
$newProcess.WorkingDirectory = "${env:SystemDrive}\windows\system32\sysprep" 
$newProcess.Arguments = "/generalize /oobe" 
Write-Host $newProcess.Arguments 
$newProcess.Verb = "runas"; 
$process = [System.Diagnostics.Process]::Start($newProcess); 
