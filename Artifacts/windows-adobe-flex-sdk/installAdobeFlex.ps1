Function Get-RedirectedUrl
{
    Param (
        [Parameter(Mandatory=$true)]
        [String]$URL
    )
 
$urlRegex = '<a href="(?<Url>[^"]+)"'
$content = (New-Object System.Net.WebClient).DownloadString($url )

$aObject = [regex]::Matches( $content, $urlRegex ) | Where-Object { $_.Groups[ "Url" ].Value -like "http://download.macromedia.com/pub/flex/sdk/*" }

$aObject.Groups[ "Url" ].Value


}

$url = 'http://www.adobe.com/devnet/flex/flex-sdk-download-all.html'
$flexSetupUrl = Get-RedirectedUrl -URL $url


$flexSetup = "${env:Temp}\FlexSetup.zip"

try
{
    (New-Object System.Net.WebClient).DownloadFile($flexSetupUrl, $flexSetup)
}
catch
{
    Write-Error "Failed to download Adobe Flex SDK Setup"
}

try
{
  
  
  # Extract Archive

  Expand-Archive  -Path $flexSetup -DestinationPath  "$env:ProgramFiles\Adobe Flex SDK\"
  
 
}
catch
{
    Write-Error 'Failed to extract Adobe Flex SDK'
}

try{

$fpd = Get-ChildItem -Path "$env:ProgramFiles\Adobe Flex SDK\runtimes\player\" -Recurse -Filter "*InstallPlugin.exe"

Start-Process -FilePath $fpd.FullName -ArgumentList "-install" -Wait

}
catch
{

 Write-Error 'Failed to install Adobe Flex SDK Flash Plugin'

}

