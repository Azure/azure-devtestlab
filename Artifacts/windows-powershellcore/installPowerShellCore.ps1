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
    (New-Object System.Net.WebClient).DownloadFile($Url, $coreMSI)
    $msiProcess = Start-Process -FilePath msiexe.exe -ArgumentList "/i ${coreMSI} /quiet /qn" -Wait -PassThru
    if (-not $msiProcess.ExitCode -eq 0)
    {
        Write-Error -Message 'Failed to install PowerShell Core'
    }
}
catch
{
    Write-Error -Message $_
}
