Function Get-RedirectedUrl
{
    Param (
        [Parameter(Mandatory=$true)]
        [String]$URL
    )
 
    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()
 
    If ($response.StatusCode -eq "Found")
    {
        $response.GetResponseHeader("Location")
    }
}

$url = 'http://go.microsoft.com/fwlink/?LinkID=623230'
$codeSetupUrl = Get-RedirectedUrl -URL $url

$infPath = $PSScriptRoot + "\vscode.inf"
$vscodeSetup = "${env:Temp}\VSCodeSetup.exe"

try
{
    Invoke-WebRequest -Uri $codeSetupUrl -OutFile $vscodeSetup
}
catch
{
    Write-Error "Failed to download VSCode Setup"
}

try
{
    Start-Process -FilePath $vscodeSetup -ArgumentList "/VERYSILENT /LOADINF=$infPath"
}
catch
{
    Write-Error 'Failed to install VSCode'
}