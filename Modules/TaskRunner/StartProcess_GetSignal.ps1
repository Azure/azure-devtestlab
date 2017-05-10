Param (

     [ValidateNotNullOrEmpty()]
     [string] $fileName,

     [ValidateNotNullOrEmpty()]
     [string] $signalFileName

)

Write-Host "Inside StartProcess-GetSignal.ps1"

$ErrorActionPreference = 'SilentlyContinue'

$filePath = [System.IO.Path]::Combine($PSScriptRoot, $fileName)
$signalFile = [System.IO.Path]::Combine($PSScriptRoot, $signalFileName)

$stdoutFile = $signalFile + '.stdout.txt'
$stderrFile = $signalFile + '.stderr.txt'

Write-Host "Filepath : $filePath"
Write-Host "Signal file : $signalFile"

$LASTEXITCODE = -1
try
{
    Write-Host "Running Script"
    & $filePath
}
finally
{
    $LASTEXITCODE | Out-File $signalFile -Append
}