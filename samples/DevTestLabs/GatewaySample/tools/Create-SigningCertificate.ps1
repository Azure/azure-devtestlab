<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

.SYNOPSIS
Creates signing certificate necessary to work with token authenticated based Remote Desktop Gateway.

.EXAMPLE
.\Create-SigningCertificate.ps1
#>

Push-Location -Path $PSScriptRoot

$expiresOn = (Get-Date).AddYears(1).ToString("MM/dd/yyyy")
$cerFileName = "$([Guid]::NewGuid().ToString()).cer"

# makecert arguments to create a signing cert
# don't mess them up - RDG is really picky on this
$makecertArguments = @(
    "-n `"CN=Azure DTL Gateway`"", 
    "-r",
    "-pe",
    "-a sha256",
    "-e $expiresOn",
    "-len 2048",
    "-sky signature",
    "-eku 1.3.6.1.5.5.7.3.2",
    "-sr CurrentUser",
    "-ss My",
    "-sy 24",
    "$cerFileName"
)

# use makecert to create a signing certificate
Start-Process "makecert.exe" -ArgumentList $makecertArguments -Verbose -Wait -NoNewWindow

$cerFilePath = Join-Path $PSScriptRoot $cerFileName
$pfxFilePath = [System.IO.Path]::ChangeExtension($cerFilePath, ".pfx")

try {
    
    # import the cer file to get the thumbprint for export
    $cer = New-Object System.Security.Cryptography.X509Certificates.X509Certificate;
    $cer.Import($cerFilePath);

    # create a random password for the pfx export
    $pwd = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 20 | % { [char] $_ })
    $hash = $cer.GetCertHashString()

    # export the pfx incl private key
    Get-ChildItem -Path cert:\CurrentUser\My\$hash | Export-PfxCertificate -FilePath $pfxFilePath -Password (ConvertTo-SecureString -String $pwd -AsPlainText -Force) | Out-Null

    # persist additional data the user needs to do followup work
    @(
        "Certificate Name:              $(Split-Path $pfxFilePath -Leaf)",
        "Certificate Thumbprint:        $hash",
        "Certificate Password:          $pwd",
        "Certificate BASE64 encoded:    <see below>",
        "==============================================================================================",
        [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($pfxFilePath))

    ) | Out-File -FilePath "$pfxFilePath.info" -Force

    Start-Process "notepad.exe" -ArgumentList @( "$pfxFilePath.info" )
}
finally {

    # clean up - remove not needed files
    Remove-Item -Path $cerFilePath -Force -ErrorAction SilentlyContinue | Out-Null
}