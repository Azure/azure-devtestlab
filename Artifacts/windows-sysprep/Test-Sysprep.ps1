[CmdletBinding()]
param(
    [string] $AnswerFileContents
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Hide any progress bars, due to downloads and installs of remote components.
$ProgressPreference = "SilentlyContinue"

# Discard any collected errors from a previous execution.
$Error.Clear()

# Allow certian operations, like downloading files, to execute.
Set-ExecutionPolicy Bypass -Scope Process -Force

###################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe artifact failed to apply.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################
#
# Main execution block.
#

Write-Host "Preparing to sysprep."
$answerFileName = 'unattend.xml'
$answerFile = Join-Path $PSScriptRoot $answerFileName
$sysprepExe = "${env:SystemDrive}\windows\system32\sysprep\sysprep.exe"

try
{
    Push-Location $PSScriptRoot

    Write-Host "Checking existence of sysprep command."
    if (-not (Test-Path -Path $sysprepExe -ErrorAction SilentlyContinue))
    {
        throw "Unable to locate file '$sysprepExe'."
    }

    if ($AnswerFileContents)
    {
        Write-Host "Preparing answer file '$answerFileName'."
        [IO.File]::WriteAllText($answerFile, $AnswerFileContents)

        Write-Host "Executing sysprep command with answer file."
        & "$sysprepExe" /generalize /oobe /shutdown /quiet /unattend:"$answerFile"
    }
    else
    {
        Write-Host "Executing sysprep command."
        & "$sysprepExe" /generalize /oobe /shutdown /quiet
    }

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    Remove-Item -Path $answerFile -ErrorAction SilentlyContinue -Force
    Pop-Location
}
