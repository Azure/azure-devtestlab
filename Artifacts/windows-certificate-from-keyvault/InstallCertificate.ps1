Param(
    [ValidateNotNullOrEmpty()]
    [string]$vaultName,
    [ValidateNotNullOrEmpty()]
    [string]$secretName,
    [ValidateNotNullOrEmpty()]
    [string]$azureServicePrincipalClientId,
    [ValidateNotNullOrEmpty()]
    [string]$azureServicePrincipalKey,
    [ValidateNotNullOrEmpty()]
    [string]$azureServicePrincipalTenantId,
    [ValidateNotNullOrEmpty()]
    [string]$certificatePasswordSecretName
)

# Handle all errors in this script.
trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this script, unless you want to ignore a specific error.
    Handle-LastError
}

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.  
$ErrorActionPreference = "Stop"

function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}


try{

    Write-Host "Arguments:"
    Write-Host "vaultName: $vaultName"
    Write-Host "secretName: $secretName"
    Write-Host "azureServicePrincipalClientId: $azureServicePrincipalClientId"
    Write-Host "azureServicePrincipalKey: $azureServicePrincipalKey"
    Write-Host "azureServicePrincipalTenantId: $azureServicePrincipalTenantId"
    Write-Host "certificatePasswordSecretName: $certificatePasswordSecretName"
    Write-Host ""

    if (-not (Get-Module -Name "AzureRm")){
        if (Get-Module -ListAvailable | Where-Object { $_.Name -eq "AzureRm"}){
            
        }else{
            Write-Host "AzureRM not detected, installing..."
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            Install-Module AzureRm -Force -AllowClobber
        }
    }

    Import-Module AzureRm

    $azureAccountName = $azureServicePrincipalClientId
    $azurePassword = ConvertTo-SecureString $azureServicePrincipalKey -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)

    Write-Host "Logging into Azure"
    Add-AzureRmAccount -Credential $psCred -TenantId $azureServicePrincipalTenantId -ServicePrincipal
    Write-Host "Done"
    Write-Host ""
    
    Write-Host "Getting the certificate from the vault"
    $secret = Get-AzureKeyVaultSecret -VaultName $vaultName -Name $secretName
    Write-Host "Done"
    Write-Host ""
    
    if (!$secret){
        throw "Failed to locate secret"
    }
    
    Write-Host "Getting the certificate password from the vault"
    $passwordSecret = Get-AzureKeyVaultSecret -VaultName $vaultName -Name $certificatePasswordSecretName
    Write-Host "Done"
    Write-Host ""

    if (!$passwordSecret){
        throw "Failed to locate secret"
    }
    
    $password = $passwordSecret.SecretValueText

    Write-Host "Converting secret into useable object"
    $certBytes = [System.Convert]::FromBase64String($secret.SecretValueText)
    $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $keyFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet 
    $keyFlags = $keyFlags -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet
    $keyFlags = $keyFlags -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable    
    $certCollection.Import($certBytes,$null,$keyFlags)
    Write-Host "Done"

    Write-Host "Saving pfx to [$env:temp\cert.pfx]"
    $protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $password)
    $pfxPath = "$env:temp\cert.pfx"
    [System.IO.File]::WriteAllBytes($pfxPath, $protectedCertificateBytes)
    Write-Host "Done"

    # Convert password to secure string.
    $securePassword = ConvertTo-SecureString -String $password -Force -AsPlainText

    Write-Host "Importing the PFX"
    # Install the PFX certificate into the Cert:\LocalMachine\My certificate store.
    Import-PfxCertificate `
    -FilePath "$env:temp\cert.pfx" `
    -CertStoreLocation cert:\localMachine\my `
    -Password $securePassword
    Write-Host "Done"
}
finally
{    
    if (Test-Path "$env:temp\cert.pfx")
    {
        Write-Host "Deleting the PFX"
        Remove-Item "$env:temp\cert.pfx" -Force
        Write-Host "Done"
    }    
}
