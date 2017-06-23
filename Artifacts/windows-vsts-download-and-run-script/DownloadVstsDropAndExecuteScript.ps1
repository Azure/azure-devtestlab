[CmdletBinding()]
param(
    [string] $username,
    [string] $accessToken,
    [string] $buildDefinitionName,
    [string] $vstsProjectUri,
    [string] $pathToScript,
    [string] $scriptArguments
)

###################################################################################################

#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
pushd $PSScriptRoot

# Configure strict debugging.
Set-PSDebug -Strict

###################################################################################################

#
# Functions used in this script.
#

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

function Set-AuthHeaders
{
    [CmdletBinding()]
    param (
        [string] $UserName,
        [string] $AccessToken
    )

    $basicAuth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$UserName`:$AccessToken"))
    return @{ Authorization = "Basic $basicAuth" }
}

function Get-BuildDefinitionId
{
    [CmdletBinding()]
    param (
        [string] $BuildDefinitionUri,
        [Hashtable] $Headers
    )

    Write-Host "Getting build definition ID from $BuildDefinitionUri"
    $buildDef = Invoke-RestMethod -Uri $BuildDefinitionUri -Headers $Headers -Method Get
    return $buildDef.value.id
}

function Get-LatestBuild
{
    param (
        [string] $BuildUri,
        [Hashtable] $Headers
    )

    Write-Host "Getting latest build from $BuildUri"
    $builds = Invoke-RestMethod -Uri $BuildUri -Headers $Headers -Method Get | ConvertTo-Json | ConvertFrom-Json
    return $builds.value[0].id
}

function Download-BuildArtifacts
{
    [CmdletBinding()]
    param (
        [string] $ArtifactsUri,
        [Hashtable] $Headers,
        [string] $Outfile,
        [string] $Destination
    )

    Write-Host "Getting build artifacts information from $ArtifactsUri"
    $artifacts = Invoke-RestMethod -Uri $ArtifactsUri -Headers $Headers -Method Get | ConvertTo-Json -Depth 3 | ConvertFrom-Json
    $downloadUrl = $artifacts.value.resource.downloadUrl
    
    Write-Host "Downloading build artifacts package from $downloadUrl"
    Invoke-RestMethod -Uri "$downloadUrl" -Headers $Headers -Method Get -Outfile $Outfile | Out-Null

    if (Test-Path $Destination -PathType Container)
    {
        Write-Host "Cleaning up destination $Destination"
        Remove-Item -Path $Destination -Force -Recurse | Out-Null
    }

    Write-Host "Extracting build artifacts package content to $Destination"
    [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null 
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Outfile, $Destination) | Out-Null
}
 
function Run-Script
{
    [CmdletBinding()]
    param (
        [string] $Path,
        [string] $Script,
        [string] $Arguments
    )

    $scriptPath = Join-Path -Path $Path -ChildPath $Script

    Write-Host "Running $scriptPath"

    if (Test-Path $scriptPath -PathType Leaf)
    {
        Invoke-Expression "& `"$scriptPath`" $Arguments"
    }
    else
    {
        Write-Error "Unable to locate $scriptPath"
    }
}

###################################################################################################

#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

###################################################################################################

#
# Main execution block.
#

try
{
    # Prepare values used throughout.
    $vstsApiVersion = "2.0"
    $outfile = "$PSScriptRoot\$buildDefinitionName.zip"
    $destination = "$($env:HOMEDRIVE)\$buildDefinitionName"
    $vstsProjectUri = $vstsProjectUri.TrimEnd("/")
    $headers = Set-AuthHeaders -UserName $username -AccessToken $accessToken

    # Output provided parameters.
    Write-Host 'Provided parameters used in this script:'
    Write-Host "  `$username = $username"
    Write-Host "  `$accessToken = $('*' * $accessToken.Length)"
    Write-Host "  `$buildDefinitionName = $buildDefinitionName"
    Write-Host "  `$vstsProjectUri = $vstsProjectUri"
    Write-Host "  `$pathToScript = $pathToScript"
    Write-Host "  `$scriptArguments = $scriptArguments"

    # Output constructed variables.
    Write-Host 'Variables used in this script:'
    Write-Host "  `$vstsApiVersion = $vstsApiVersion"
    Write-Host "  `$outfile = $outfile"
    Write-Host "  `$destination = $destination"

    # Get the build definition ID.
    $buildDefinitionUri = "$vstsProjectUri/_apis/build/definitions?api-version=$vstsApiVersion&name=$buildDefinitionName"
    $buildDefinitionId = Get-BuildDefinitionId -BuildDefinitionUri $buildDefinitionUri -Headers $headers
    
    # Get the ID of the latest successful build.
    $buildUri = "$vstsProjectUri/_apis/build/builds/?api-version=$vstsApiVersion&definitions=$buildDefinitionId&statusFilter=succeeded";
    $buildId = Get-LatestBuild -BuildUri $buildUri -Headers $headers

    # Download the build artifact package.
    $artifactsUri = "$vstsProjectUri/_apis/build/builds/$buildId/Artifacts?api-version=$vstsApiVersion";
    Download-BuildArtifacts -ArtifactsUri $artifactsUri -Headers $headers -Outfile $outfile -Destination $destination

    # Run the script specified after having successfully downloaded the build artifact package.
    Run-Script -Path $destination -Script $pathToScript -Arguments $scriptArguments
}
finally
{
    popd
}
