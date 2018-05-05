[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $Subject,
     
    [Parameter(Mandatory=$true)]
    [string] $Password,   
    
    [ValidateSet('ServiceFabric', 'HPCPack')]
    [string] $Type = 'ServiceFabric'
)

$securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
$certificatePath = Join-Path $env:TEMP $($Subject + ".pfx")
$certificateInfo = [System.IO.Path]::ChangeExtension($certificatePath, ".txt")
Write-Host "Creating new self signed certificate at $certificatePath"

# Remove certificate file and info if exists
Remove-Item -Path $certificatePath -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Path $certificateInfo -Force -ErrorAction SilentlyContinue | Out-Null

# Changes to PSPKI version 3.5.2 New-SelfSignedCertificate replaced by New-SelfSignedCertificateEx
$PspkiVersion = (Get-Module PSPKI).Version

if($PSPKIVersion.Major -ieq 3 -And $PspkiVersion.Minor -ieq 2 -And $PspkiVersion.Build -ieq 5) {

    switch ($Type) {
        'ServiceFabric' { New-SelfsignedCertificateEx -Subject "CN=$Subject"                    -KeyUsage "KeyEncipherment, DigitalSignature" -EnhancedKeyUsage "Server Authentication", "Client authentication" -Path $certificatePath -Password $securePassword -Exportable -NotAfter (Get-Date).AddYears(5) }
        'HPCPack'       { New-SelfSignedCertificateEx -Subject "CN=$Subject" -KeySpec Exchange  -KeyUsage "KeyEncipherment, DigitalSignature" -EnhancedKeyUsage "Server Authentication", "Client Authentication" -Path $certificatePath -Password $securePassword -Exportable -NotAfter (Get-Date).AddYears(5) }
        Default { throw "Unsupported type '$Type'." }
    }

} else {

    switch ($Type) {
        'ServiceFabric' { New-SelfSignedCertificate -Subject "CN=$Subject"                      -CertStoreLocation Cert:\CurrentUser\My                                                                                                                                      | Export-PfxCertificate -FilePath $certificatePath -Password $securePassword | Out-Null }
        'HPCPack'       { New-SelfSignedCertificate -Subject "CN=$Subject" -KeySpec KeyExchange -CertStoreLocation Cert:\CurrentUser\My -KeyExportPolicy Exportable -NotAfter (Get-Date).AddYears(5) -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.2") | Export-PfxCertificate -FilePath $certificatePath -Password $securePassword | Out-Null }
        Default { throw "Unsupported type '$Type'." }
    }

}

$cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2 $certificatePath, $Password
$bytes = [System.IO.File]::ReadAllBytes($certificatePath)

"Certificate Thumbprint: $($cert.Thumbprint)"                       | Out-File -FilePath $certificateInfo -Append
"Certificate Password:   $Password"                                 | Out-File -FilePath $certificateInfo -Append
"================================================================"  | Out-File -FilePath $certificateInfo -Append
$([System.Convert]::ToBase64String($bytes))                         | Out-File -FilePath $certificateInfo -Append

notepad $certificateInfo