 Param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$True)]
    [string] $url,
    
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$True)]
    [string] $path
 )

#ensure the path is available 
New-Item -ItemType Directory -Force -Path (Split-Path -parent $path)    
     
$client = new-object System.Net.WebClient 
$client.DownloadFile($url, $path) 