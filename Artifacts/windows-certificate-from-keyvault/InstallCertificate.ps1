Param(
    [ValidateNotNullOrEmpty()]
    [string]$vaultName,
    [ValidateNotNullOrEmpty()]
    [string]$secretName,
    [ValidateNotNullOrEmpty()]
    [string]$azureUsername,
    [ValidateNotNullOrEmpty()]
    [string]$azurePassword
)

# Handle all errors in this script.
trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
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


$securePassword = ConvertTo-SecureString $azurePassword -AsPlainText -Force
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $azureUsername, $securePassword

if (-not (Get-Module -Name "AzureRm")){
    if (Get-Module -ListAvailable | Where-Object { $_.Name -eq "AzureRm"}){
        
    }else{
        Write-Host "AzureRM not detected, installing..."
        Install-Module AzureRm -Force -AllowClobber
    }
}

Import-Module AzureRm

Write-Host "Logging into Azure"
Add-AzureRmAccount -Credential $creds
Write-Host "Done"

$secret = Get-AzureKeyVaultSecret -VaultName "iSAMS-KeyVault" -Name "isams-cloud"

if (!$secret){
    throw "Failed to locate secret"
}

Write-Host "Converting secret into useable object"
$jsonObjectBytes = [System.Convert]::FromBase64String($secret.SecretValueText)
$jsonObject = [System.Text.Encoding]::UTF8.GetString($jsonObjectBytes)
$customObject = ConvertFrom-Json $jsonObject
Write-Host "Done"

Write-Host "Saving pfx to [$env:temp\cert.pfx]"
# Deserialize and save the PFX file.
$pfxBytes = [System.Convert]::FromBase64String($customObject.data)
[io.file]::WriteAllBytes("$env:temp\cert.pfx", $pfxBytes)
Write-Host "Done"

# Convert password to secure string.
$password = ConvertTo-SecureString -String $customObject.password -Force -AsPlainText

Write-Host "Importing the PFX"
# Install the PFX certificate into the Cert:\LocalMachine\My certificate store.
Import-PfxCertificate `
-FilePath "$env:temp\cert.pfx" `
-CertStoreLocation cert:\localMachine\my `
-Password $password
Write-Host "Done"

Write-Host "Deleting the PFX"
Remove-Item "$env:temp\cert.pfx" -Force
Write-Host "Done"