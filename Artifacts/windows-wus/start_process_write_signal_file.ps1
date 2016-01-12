Param (

     [ValidateNotNullOrEmpty()]

     [string] 
$filePath,



     [ValidateNotNullOrEmpty()]
 
    [string] $arguments,



     [ValidateNotNullOrEmpty()]
 
    [string] 
$signalFile

)



if ($filePath.EndsWith(".ps1"))
{

    $arguments = ("-ExecutionPolicy Bypass -NoProfile -File `"" + $filePath + "`" " + $arguments)

    $filePath = "powershell"

}



# Install VS

$processInfo = new-object System.Diagnostics.ProcessStartInfo $filePath;
$processInfo.Arguments = $arguments


$processInfo.Verb = "runas";


$processInfo.RedirectStandardOutput = $true;
$processInfo.RedirectStandardError = $true;
$processInfo.UseShellExecute = $false;

# Start the new process

$process = [System.Diagnostics.Process]::Start($processInfo);
$process.WaitForExit();



# Route the logs to another file
$stdout = $process.StandardOutput.ReadToEnd();
$stderr = $process.StandardError.ReadToEnd();

$stdoutFile = $signalFile + '.stdout.txt'
$stderrFile = $signalFile + '.stderr.txt'

$stdout | out-file $stdoutFile
$stderr | out-file $stderrFile
$process.ExitCode | out-file $signalFile