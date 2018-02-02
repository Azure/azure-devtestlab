[CmdletBinding()]
param(
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
Push-Location $PSScriptRoot

# Configure strict debugging.
Set-PSDebug -Strict

###################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
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

###################################################################################################
#
# Functions used in this script.
#

function Get-BuildArtifacts
{
    [CmdletBinding()]
    param (
        [string] $ArtifactsUri,
        [Hashtable] $Headers,
        [string] $Destination
    )

    # Clean up destination path first, if needed.
    if (Test-Path $Destination -PathType Container)
    {
        Write-Host "Cleaning up destination folder $Destination"
        Remove-Item -Path $Destination -Force -Recurse | Out-Null
    }

    Write-Host "Getting build artifacts information from $ArtifactsUri"
    [Array] $artifacts = (Invoke-RestMethod -Uri $ArtifactsUri -Headers $Headers -Method Get | ConvertTo-Json -Depth 3 | ConvertFrom-Json).value

    # Process all artifacts found.
    foreach ($artifact in $artifacts)
    {
        $artifactName = "$($artifact.name)"
        $artifactZip = "$artifactName.zip"
        Write-Host "Preparing to download artifact $artifactName to file $artifactZip"

        $downloadUrl = $artifact.resource.downloadUrl
        if (-not $downloadUrl)
        {
            throw "Unable to get the download URL for artifact $artifactName."
        }

        $outfile = "$PSScriptRoot\$artifactZip"

        Write-Host "Downloading artifact $artifactName from $downloadUrl"
        Invoke-RestMethod -Uri "$downloadUrl" -Headers $Headers -Method Get -Outfile $outfile | Out-Null

        Write-Host "Extracting artifact file $artifactZip to $Destination"
        [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null 
        [System.IO.Compression.ZipFile]::ExtractToDirectory($outfile, $Destination) | Out-Null
    }
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
    $buildDefinitionId = $buildDef.value.id
    if (-not $buildDefinitionId)
    {
        throw "Unable to get the build definition ID from $buildDefinitionUri"
    }

    return $buildDefinitionId
}

function Get-LatestBuildId
{
    param (
        [string] $BuildUri,
        [Hashtable] $Headers
    )

    Write-Host "Getting latest build ID from $BuildUri"
    $builds = Invoke-RestMethod -Uri $BuildUri -Headers $Headers -Method Get | ConvertTo-Json | ConvertFrom-Json
    $buildId = $builds.value[0].id
    if (-not $buildId)
    {
        throw "Unable to get the latest build ID from $BuildUri"
    }

    return $buildId
}
 
function Invoke-Script
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

function Set-AuthHeaders
{
    [CmdletBinding()]
    param (
        [string] $UserName = "",
        [string] $AccessToken
    )

    $basicAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $UserName,$AccessToken)))
    return @{ Authorization = "Basic $basicAuth" }
}

###################################################################################################
#
# Main execution block.
#

try
{
    # Prepare values used throughout.
    $vstsApiVersion = "2.0"
    $destination = "$($env:HOMEDRIVE)\$buildDefinitionName"
    $vstsProjectUri = $vstsProjectUri.TrimEnd("/")
    $headers = Set-AuthHeaders -AccessToken $accessToken

    # Output provided parameters.
    Write-Host 'Provided parameters used in this script:'
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
    $buildId = Get-LatestBuildId -BuildUri $buildUri -Headers $headers

    # Download the build artifact package.
    $artifactsUri = "$vstsProjectUri/_apis/build/builds/$buildId/Artifacts?api-version=$vstsApiVersion";
    Get-BuildArtifacts -ArtifactsUri $artifactsUri -Headers $headers -Destination $destination

    # Run the script specified after having successfully downloaded the build artifact package.
    Invoke-Script -Path $destination -Script $pathToScript -Arguments $scriptArguments
}
finally
{
    Pop-Location
}
