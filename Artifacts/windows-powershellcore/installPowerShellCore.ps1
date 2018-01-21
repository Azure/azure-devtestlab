param
(
    [Parameter(Mandatory = $true)]
    [String]
    $packageUrl,

    [Parameter()]
    [bool]
    $installCRuntime = $false
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
        if ($installCRuntime)
        {
            $osVersion = [System.Environment]::OSVersion.Version
            if (($osVersion.Major -lt 10) -and ($osVersion.Major -ge 6))
            {
                Write-Verbose -Message 'Acquiring C runtime installer ...'
                $ucArchive = "${env:Temp}\WindowsUCRT.zip"
                $ucRuntimeUri = 'https://download.microsoft.com/download/3/1/1/311C06C1-F162-405C-B538-D9DC3A4007D1/WindowsUCRT.zip'
                Invoke-WebRequest -Uri $ucRuntimeUri -OutFile $ucArchive

                #Extract the archive
                Add-Type -assembly "System.IO.Compression.FileSystem"
                [IO.Compression.ZipFile]::ExtractToDirectory($ucArchive, "${env:Temp}\ucFiles")

                #installing Universal C Runtime
                $isX64 = [System.Environment]::Is64BitOperatingSystem
                $fullOSVersion = "$($osVersion.Major).$($osVersion.Minor)"
                if ($isX64)
                {
                    $msuPath = "${env:Temp}\ucFiles\Windows${fullOSVersion}-KB3118401-${x64}.msu"
                }
                else
                {
                    $msuPath = "${env:Temp}\ucFiles\Windows${fullOSVersion}-KB3118401-${x86}.msu"
                }

                #Install MSU
                $msuProcess = Start-Process -FilePath wusa.exe -ArgumentList "/install ${msuPath} /quiet" -Wait -PassThru
                if (-not $msuProcess.ExitCode -eq 0)
                {
                    Remove-Item -Path $msuPath -Force
                    Write-Error -Message 'Failed to install Universal C Runtime.'
                    
                }
                else
                {
                    Write-Verbose -Message 'Universal C Runtime install complete.' 
                    Remove-Item -Path $msuPath -Force
                }                
            }
        }

        #PowerShell Core install
        $msiProcess = Start-Process -FilePath msiexec.exe -ArgumentList "/i ${coreMSI} /quiet /qn" -Wait -PassThru
        if (-not $msiProcess.ExitCode -eq 0)
        {
            Remove-Item -Path $coreMSI -Force
            Write-Error -Message 'Failed to install PowerShell Core.'
            
        }
        else
        {
            Write-Verbose -Message 'PowerShell Core install complete.' 
            Remove-Item -Path $coreMSI -Force
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
