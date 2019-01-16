[CmdletBinding()]
param(
    [string] $tenantId,
    [string] $applicationId,
    [string] $servicePrincipalPassword,
    [string] $pavcVersion,
    [string] $keyVault,
    [string] $keyVaultCertPasswordKeyName,
    [string] $keyVaultCertName,
    [string] $keyVaultPavcServiceAccountPatKeyName,
    [string] $nuGetVersion,
    [string] $pavcWorkload,
    [string] $pavcServiceLine,
    [string] $pavcCertificateNameWildCard,
    [string] $pavcEnvironment,
    [string] $pavcCPURateLimit,
    [string] $pavcScanStartTime,
    [string] $pavcNnuGetFeed,
    [string] $serviceAccount,
    [string] $pavcNuGetPackageName
)

###################################################################################################

#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

# Configure strict debugging.
Set-PSDebug -Strict

###################################################################################################

function Test-Parameters
{
    [CmdletBinding()]
    param(
        [string] $tenantId,
        [string] $applicationId,
        [string] $servicePrincipalPassword,
        [string] $pavcVersion,
        [string] $keyVault,
        [string] $keyVaultCertPasswordKeyName,
        [string] $keyVaultCertName,
        [string] $keyVaultPavcServiceAccountPatKeyName,
        [string] $nuGetVersion,
        [string] $pavcWorkload,
        [string] $pavcServiceLine,
        [string] $pavcCertificateNameWildCard,
        [string] $pavcEnvironment,
        [string] $pavcCPURateLimit,
        [string] $pavcScanStartTime,
        [string] $pavcNnuGetFeed,
        [string] $serviceAccount,
        [string] $pavcNuGetPackageName
    )

    if ([string]::IsNullOrWhiteSpace($tenantId))
    {
        Write-Error "Tenant ID was not provided! Please retry by providing a valid Tenant ID!"
    }

    if ([string]::IsNullOrWhiteSpace($applicationId))
    {
        Write-Error "Application ID was not provided! Please retry by providing a valid Application ID!"
    }

    if ([string]::IsNullOrWhiteSpace($servicePrincipalPassword))
    {
        Write-Error "Service Principal Password was not provided! Please retry by providing a valid Service Principal Password!"
    }

    if ([string]::IsNullOrWhiteSpace($pavcVersion))
    {
        Write-Error "PAVC Version not set! Please retry by providing a valid PAVC Version!"
    }

    if ([string]::IsNullOrWhiteSpace($keyVault))
    {
        Write-Error "KeyVault name not set! Please retry by providing a valid KeyVault name!"
    }

    if ([string]::IsNullOrWhiteSpace($keyVaultCertPasswordKeyName))
    {
        Write-Error "KeyVault Certificate Password Key name not set! Please retry by providing a valid KeyVault Certificate Password Key name!"
    }

    if ([string]::IsNullOrWhiteSpace($keyVaultCertName))
    {
        Write-Error "KeyVault Certificate name not set! Please retry by providing a valid KeyVault Certificate name!"
    }

    if ([string]::IsNullOrWhiteSpace($keyVaultPavcServiceAccountPatKeyName))
    {
        Write-Error "KeyVault Service Account PAT Key name not set! Please retry by providing a valid KeyVault Service Account PAT Key name!"
    }

    if ([string]::IsNullOrWhiteSpace($nuGetVersion))
    {
        Write-Error "NuGet version not set! Please retry by providing a valid NuGet version!"
    }

    if ([string]::IsNullOrWhiteSpace($pavcWorkload))
    {
        Write-Error "PAVC Workload not set! Please retry by providing a valid PAVC Workload!"
    }

    if ([string]::IsNullOrWhiteSpace($pavcServiceLine))
    {
        Write-Error "PAVC ServiceLine not set! Please retry by providing a valid PAVC ServiceLine!"
    }

    if ([string]::IsNullOrWhiteSpace($pavcCertificateNameWildCard))
    {
        Write-Error "PAVC CertificateNameWildCard not set! Please retry by providing a valid PAVC CertificateNameWildCard!"
    }

    if ([string]::IsNullOrWhiteSpace($pavcEnvironment))
    {
        Write-Error "PAVC Environment not set! Please retry by providing a valid PAVC Environment!"
    }

    if ([string]::IsNullOrWhiteSpace($pavcCPURateLimit))
    {
        Write-Error "PAVC CPURateLimit not set! Please retry by providing a valid PAVC CPURateLimit!"
    }

    if ([string]::IsNullOrWhiteSpace($pavcScanStartTime))
    {
        Write-Error "PAVC ScanStartTime not set! Please retry by providing a valid PAVC ScanStartTime!"
    }

    if ([string]::IsNullOrWhiteSpace($pavcNnuGetFeed))
    {
        Write-Error "PAVC NnuGet Feed not set! Please retry by providing a valid NnuGet Feed!"
    }

    if ([string]::IsNullOrWhiteSpace($serviceAccount))
    {
        Write-Error "Service Account name not set! Please retry by providing a valid Service Account name!"
    }

    if ([string]::IsNullOrWhiteSpace($pavcNuGetPackageName))
    {
        Write-Error "PAVC NnuGet package name not set! Please retry by providing a valid PAVC NnuGet package name!"
    }
}

function Get-OSDriveLetter
{
    [System.IO.Path]::GetPathRoot([Environment]::SystemDirectory)[0]
}

function Login-ToAzure
{
    [CmdletBinding()]
    param(
        [string] $tenantId,
        [string] $applicationId,
        [string] $servicePrincipalPassword
    )

    $password = ConvertTo-SecureString $servicePrincipalPassword -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($applicationId, $password)

    try
    {
        Connect-AzureRmAccount -ServicePrincipal -Credential $cred -TenantId $tenantId
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}

function Install-Certificate
{
    [CmdletBinding()]
    param(
        [string] $keyVault,
        [string] $keyVaultCertPasswordKeyName,
        [string] $keyVaultCertName
    )

    $kvPavcSecret = Get-AzureKeyVaultSecret -VaultName $keyVault -Name $keyVaultCertPasswordKeyName
    $kvSecret = Get-AzureKeyVaultSecret -VaultName $keyVault -Name $keyVaultCertName
    $kvSecretBytes = [System.Convert]::FromBase64String($kvSecret.SecretValueText)
    $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store("My","LocalMachine")

    try
    {
        $kvPavcSecretKey = ConvertTo-SecureString $kvPavcSecret.SecretValueText -AsPlainText -Force
    }
    catch
    {
        Write-Error "Invalid Certificate Key name: $_.Exception.Message"
    }

    try
    {
        $certCollection.Import($kvSecretBytes, $kvPavcSecretKey.Password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
    }
    catch
    {
        Write-Error "Invalid Certificate name: $_.Exception.Message"
    }

    try
    {
        $store.open("MaxAllowed")
        $store.addrange($certCollection)
        $store.close()
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}

function Download-NuGet
{
    [CmdletBinding()]
    param(
        [string] $nuGetVersion
    )

    $nugetUrl = "https://dist.nuget.org/win-x86-commandline/$nuGetVersion/nuget.exe"

    try
    {
        Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetExe
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}

function Download-PAVC
{
    [CmdletBinding()]
    param(
        [string] $pavcVersion,
        [string] $keyVault,
        [string] $keyVaultPavcServiceAccountPatKeyName,
        [string] $pavcNnuGetFeed,
        [string] $serviceAccount,
        [string] $pavcNuGetPackageName
    )

    $nugetPavcSourceName = "PAVC"
    $kvPavcAccountSecretPat = Get-AzureKeyVaultSecret -VaultName $keyVault -Name $keyVaultPavcServiceAccountPatKeyName
    $kvPavcAccountSecret = $kvPavcAccountSecretPat.SecretValueText

    try
    {
        Invoke-Expression -Command "$nugetExe source Add -Name $nugetPavcSourceName -Source $pavcNnuGetFeed -UserName $serviceAccount -Password $kvPavcAccountSecret"
        Invoke-Expression -Command "$nugetExe install $pavcNuGetPackageName -NonInteractive -DirectDownload -Version $pavcVersion -OutputDirectory $Env:HOMEDRIVE/ -ExcludeVersion"
        Invoke-Expression -Command "$nugetExe source Remove -Name $nugetPavcSourceName"
        Remove-Item -Path $nugetExe -Force
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}

function Install-PAVC
{
    [CmdletBinding()]
    param(
        [string] $pavcWorkload,
        [string] $pavcServiceLine,
        [string] $pavcCertificateNameWildCard,
        [string] $pavcEnvironment,
        [string] $pavcCPURateLimit,
        [string] $pavcScanStartTime,
        [string] $pavcNuGetPackageName
    )

    $pavcAgentDir = "$(Get-OSDriveLetter):\PavcAgent"
    $pavcInstallBinaries = "$(Get-OSDriveLetter):\$pavcNuGetPackageName"

    try
    {
        New-Item -ItemType Directory -Force -Path $pavcAgentDir
        Invoke-Expression -Command "$pavcInstallBinaries\StartUp.ps1 -EnableDeployment True -Workload '$pavcWorkload' -ServiceLine '$pavcServiceLine' -CertificateNameWildCard '$pavcCertificateNameWildCard' -HostName '$Env:Computername' -Environment '$pavcEnvironment' -RetinaPath '$pavcAgentDir' -InstallToOsDrive True -CPURateLimit '$pavcCPURateLimit' -ScanStartTime '$pavcScanStartTime'"
        Remove-Item -Path $pavcInstallBinaries -Force -Recurse
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}

try
{
    $nugetExe = "$(Get-OSDriveLetter):\NuGet.exe"

    Test-Parameters -tenantId $tenantId `
                    -applicationId $applicationId `
                    -servicePrincipalPassword $servicePrincipalPassword `
                    -pavcVersion $pavcVersion `
                    -keyVault $keyVault `
                    -keyVaultCertPasswordKeyName $keyVaultCertPasswordKeyName `
                    -keyVaultCertName $keyVaultCertName `
                    -keyVaultPavcServiceAccountPatKeyName $keyVaultPavcServiceAccountPatKeyName `
                    -nuGetVersion $nuGetVersion `
                    -pavcWorkload $pavcWorkload `
                    -pavcServiceLine $pavcServiceLine `
                    -pavcCertificateNameWildCard $pavcCertificateNameWildCard `
                    -pavcEnvironment $pavcEnvironment `
                    -pavcCPURateLimit $pavcCPURateLimit `
                    -pavcScanStartTime $pavcScanStartTime `
                    -pavcNnuGetFeed $pavcNnuGetFeed `
                    -serviceAccount $serviceAccount `
                    -pavcNuGetPackageName $pavcNuGetPackageName

    Login-ToAzure -tenantId $tenantId -applicationId $applicationId -servicePrincipalPassword $servicePrincipalPassword

    Install-Certificate -keyVault $keyVault -keyVaultCertPasswordKeyName $keyVaultCertPasswordKeyName -keyVaultCertName $keyVaultCertName

    Download-NuGet -nuGetVersion $nuGetVersion

    Download-PAVC -pavcVersion $pavcVersion `
                  -keyVault $keyVault `
                  -keyVaultPavcServiceAccountPatKeyName $keyVaultPavcServiceAccountPatKeyName `
                  -pavcNnuGetFeed $pavcNnuGetFeed `
                  -serviceAccount $serviceAccount `
                  -pavcNuGetPackageName $pavcNuGetPackageName

    Install-PAVC -pavcWorkload $pavcWorkload `
                 -pavcServiceLine $pavcServiceLine `
                 -pavcCertificateNameWildCard $pavcCertificateNameWildCard `
                 -pavcEnvironment $pavcEnvironment `
                 -pavcCPURateLimit $pavcCPURateLimit `
                 -pavcScanStartTime $pavcScanStartTime `
                 -pavcNuGetPackageName $pavcNuGetPackageName
}
finally
{
    Write-Host "Done"
}