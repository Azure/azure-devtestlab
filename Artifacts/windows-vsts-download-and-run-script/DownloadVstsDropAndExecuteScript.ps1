#parameters
param(
    [Parameter]
    [AllowEmptyString()]
    [string] $username,

    [Parameter (Mandatory=$True)]
    [string] $accessToken,

    [Parameter (Mandatory=$True)]
    [string] $buildDefinitionName,

    [Parameter (Mandatory=$True)]
    [string] $vstsProjectUri,

    [Parameter (Mandatory=$True)]
    [string] $pathToScript
)

Set-PSDebug -Strict

# VSTS Variables
$vstsApiVersion = "2.0"
$uriParts = $vstsProjectUri.Split("/")
$projectName = $uriParts[$uriParts.Length - 1]

# Script Variables
$outfile = $PSScriptRoot + "\" + $projectName + ".zip";
$destination = $env:HOMEDRIVE + "\" + $projectName;

function SetAuthHeaders
{
    $basicAuth = ("{0}:{1}" -f $username,$accessToken)
    $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
    $basicAuth = [System.Convert]::ToBase64String($basicAuth)
    return @{Authorization=("Basic {0}" -f $basicAuth)}
}

function GetBuildDefinitionId
{
    $buildDefinitionUri = ("{0}/_apis/build/definitions?api-version={1}&name={2}" -f $vstsProjectUri, $vstsApiVersion, $buildDefinitionName)
    $buildDef = Invoke-RestMethod -Uri $buildDefinitionUri -Headers $headers -method Get 
    return $buildDef.value.id
}

function GetLatestBuild
{
    param (
        [Parameter(Mandatory=$True)]
        [int] $buildDefinitionId 
    )
    $buildUri = ("{0}/_apis/build/builds?api-version={1}&definitions={2}&resultFilter=succeeded" -f $vstsProjectUri, $vstsApiVersion, $buildDefinitionId);
    $builds = Invoke-RestMethod -Uri $buildUri -Headers $headers -Method Get | ConvertTo-Json | ConvertFrom-Json
    return $builds.value[0].id
}

function DownloadBuildArtifacts
{
    $headers = SetAuthHeaders
    $buildId = GetLatestBuild ( GetBuildDefinitionId )
    $artifactsUri = ("{0}/_apis/build/builds/{1}/Artifacts?api-version={2}" -f $vstsProjectUri, $buildId, $vstsApiVersion);
    $artifacts = Invoke-RestMethod -Uri $artifactsUri -Headers $headers -Method Get | ConvertTo-Json -Depth 3 | ConvertFrom-Json
    $DownloadUri = $artifacts.value.resource.downloadUrl

    Invoke-RestMethod -Uri $DownloadUri -Headers $headers -Method Get -Outfile $outfile 

    if (Test-Path $destination -PathType Container)
    {
        Remove-Item -Path $destination -Force -Recurse -Verbose
    }

    [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null 
    [System.IO.Compression.ZipFile]::ExtractToDirectory($outfile, $destination)
}
 
function RunScript
{
    $scriptPath = Join-Path -Path $destination -ChildPath $pathToScript 

    Write-Output $scriptPath

    if (Test-Path $scriptPath -PathType Leaf)
    {
        & $scriptPath 
    }
}

DownloadBuildArtifacts
RunScript
