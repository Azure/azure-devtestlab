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

# Script Variables
$outfile = $PSScriptRoot + "\" + $buildDefinitionName + ".zip";
$destination = $env:HOMEDRIVE + "\" + $buildDefinitionName;

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
    try
    {
        Write-Host "GetBuildDefinitionId from $buildDefinitionUri"
        $buildDef = Invoke-RestMethod -Uri $buildDefinitionUri -Headers $headers -method Get -ErrorAction Stop
        return $buildDef.value.id
    }
    catch
    {
        if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
        {
            $errMsg = $Error[0].Exception.Message
            Write-Host $errMsg
        }
        exit -1
    }
}

function GetLatestBuild
{
    param (
        [Parameter(Mandatory=$True)]
        [int] $buildDefinitionId 
    )
    $buildUri = ("{0}/_apis/build/builds?api-version={1}&definitions={2}&resultFilter=succeeded" -f $vstsProjectUri, $vstsApiVersion, $buildDefinitionId);

    try 
    {
        Write-Host "GetLatestBuild from $buildUri"
        $builds = Invoke-RestMethod -Uri $buildUri -Headers $headers -Method Get -ErrorAction Stop | ConvertTo-Json | ConvertFrom-Json
        return $builds.value[0].id
    }
    catch
    {
        if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
        {
            $errMsg = $Error[0].Exception.Message
            Write-Host $errMsg
        }
        exit -1
    }
   
}

function DownloadBuildArtifacts
{
	if ($vstsProjectUri.EndsWith("/")) {
        $vstsProjectUri = $vstsProjectUri.Substring(0, $vstsProjectUri.Length -1)
    }

    $headers = SetAuthHeaders
    $buildId = GetLatestBuild ( GetBuildDefinitionId )
    $artifactsUri = ("{0}/_apis/build/builds/{1}/Artifacts?api-version={2}" -f $vstsProjectUri, $buildId, $vstsApiVersion);

    try 
    {
        Write-Host "Get artifacts from $artifactsUri"
        $artifacts = Invoke-RestMethod -Uri $artifactsUri -Headers $headers -Method Get  -ErrorAction Stop | ConvertTo-Json -Depth 3 | ConvertFrom-Json
        $DownloadUri = $artifacts.value.resource.downloadUrl

        Write-Host "Download from $DownloadUri"
        Invoke-RestMethod -Uri $DownloadUri -Headers $headers -Method Get -Outfile $outfile -ErrorAction Stop

        if (Test-Path $destination -PathType Container)
        {
            Remove-Item -Path $destination -Force -Recurse -Verbose
        }

        [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null 
        [System.IO.Compression.ZipFile]::ExtractToDirectory($outfile, $destination)
    }
    catch
    {
        if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
        {
            $errMsg = $Error[0].Exception.Message
            Write-Host $errMsg
        }
        exit -1
    }
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

