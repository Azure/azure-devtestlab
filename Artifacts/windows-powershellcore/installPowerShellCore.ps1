param
(
    [Parameter(Mandatory = $true)]
    [String]
    $packageUrl
)

if (-not (Split-Path -Path $packageUrl -Leaf).EndsWith('.msi'))
{
    throw "${packageUrl} is not the path to PowerShell Core MSI."
}

try
{
    $coreMSI = "${env:Temp}\PowerShellCore.msi"    
    Write-Verbose -Message "Downloading ${packageUrl} to ${coreMSI} ..."
    Invoke-WebRequest -Uri $packageUrl -OutFile $coreMSI -Verbose

    if (Test-Path -Path $coreMSI)
    {
        $msiProcess = Start-Process -FilePath msiexe.exe -ArgumentList "/i ${coreMSI} /quiet /qn" -Wait -PassThru
        if (-not $msiProcess.ExitCode -eq 0)
        {
            Write-Error -Message 'Failed to install PowerShell Core.'
        }
        else
        {
            Write-Verbose -Message 'PowerShell Core install complete.'    
        }
    }
    else
    {
        throw "Download of ${packageUrl} failed."
    }
}
catch
{
    Write-Error -Message $_
}
