
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
	[string] $VsoProjectUri,

	[Parameter (Mandatory=$True)]
	[string] $pathToScript
)

Set-PSDebug -Strict

# VSO Variables
$VsoApiVersion = "2.0"
$UriParts = $VsoProjectUri.Split("/")
$projectName = $UriParts[$UriParts.Length - 1]

# Script Variables
$outfile = $PSScriptRoot + "\" + $projectName + ".zip";
$destination = $PSScriptRoot + "\" + $projectName;

function SetAuthHeaders
{
	$basicAuth = ("{0}:{1}" -f $username,$accessToken)
	$basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
	$basicAuth = [System.Convert]::ToBase64String($basicAuth)
	return @{Authorization=("Basic {0}" -f $basicAuth)}
}

function GetBuildDefinitionId
{
	$buildDefinitionUri = ("{0}/_apis/build/definitions?api-version={1}&name={2}" -f $VsoProjectUri, $VsoApiVersion, $buildDefinitionName)
	$buildDef = Invoke-RestMethod -Uri $buildDefinitionUri -Headers $headers -method Get | ConvertTo-Json
	$buildDef = ConvertFrom-Json $buildDef
	return $buildDef.value.id
}

function GetLatestBuild
{
	param (
		[Parameter(Mandatory=$True)]
		[int] $buildDefinitionId 
	)
	$buildUri = ("{0}/_apis/build/builds?api-version={1}&definitions={2}&resultFilter=succeeded" -f $VsoProjectUri, $VsoApiVersion, $buildDefinitionId);
	$builds = Invoke-RestMethod -Uri $buildUri -Headers $headers -Method Get | ConvertTo-Json | ConvertFrom-Json
	return $builds.value[0].id
}

function DownLoadBuildArtifacts
{
	$headers = SetAuthHeaders
    $buildId = GetLatestBuild ( GetBuildDefinitionId )
	$artifactsUri = ("{0}/_apis/build/builds/{1}/Artifacts?api-version={2}" -f $VsoProjectUri, $buildId, $VsoApiVersion);
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
	$ScriptPath = Join-Path -Path $destination -ChildPath $pathToScript 

	Write-Output $ScriptPath

	if (Test-Path $ScriptPath -PathType Leaf)
	{
		& $ScriptPath 
	}
}

DownLoadBuildArtifacts
RunScript
