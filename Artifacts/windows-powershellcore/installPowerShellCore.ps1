param
(
    [Parameter(Mandatory)]
    [String]
    $Url
)

if (-not (Split-Path -Path $url -Leaf).EndsWith('.msi'))
{
    throw "${Url} is not the path to PowerShell Core MSI."
}

try
{
    $coreMSI = "${env:Temp}\PowerShellCore.msi"    
    Write-Verbose -Message "Downloading ${url} to ${coreMSI} ..."
    Invoke-WebRequest -url $Url -OutFile $coreMSI -Verbose

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
        throw "Download of ${url} failed."
    }
}
catch
{
    Write-Error -Message $_
}
