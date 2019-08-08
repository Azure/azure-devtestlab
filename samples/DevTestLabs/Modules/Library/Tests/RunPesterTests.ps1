Param(
    [Parameter(Mandatory = $false, HelpMessage="The suite of tests to execute, this is done by string matching (StartsWith) on filenames - 'Lab' matches 'Lab.tests.ps1' and 'LabUsers.tests.ps1'")]
    [string] $TestSuite = "*",

    [Parameter(Mandatory = $false, HelpMessage="If we should run the tests in 'verbose' mode for extra logging")]
    [bool] $VerboseTests = $false

)

# Import the module here to make sure we validate up front versions of Azure Powershell
Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1

# We don't want to give up on the rest after a single error
$ErrorActionPreference="Continue"

# Check if we have a newer version of Pester, if not - let's install it
$pesterModule = Get-Module -ListAvailable | Where-Object {$_.Name -eq "Pester"} | Sort-Object -Descending Version | Select-Object -First 1
if ($pesterModule.Version.Major -lt 4 -or $pesterModule.version.Minor -lt 8) {
    # We don't have a new enough version of Pester, install it
    Write-Output "Latest version of Pester is $($pesterModule.Version), Installing the latest Pester from PSGallery"
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    Install-Module -Name Pester -Force -Scope CurrentUser
}

# Check if we have a good version of ThreadJob - if not, let's install it
$threadModule = Get-Module -ListAvailable | Where-Object {$_.Name -eq "ThreadJob"} | Sort-Object -Descending Version | Select-Object -First 1
if (-not $threadModule) {
    Write-Output "Don't have a version of ThreadJob module locally, installing from PSGallery"
    Install-Module -Name ThreadJob -Force -Scope CurrentUser
}

$invokePesterScriptBlock = {
    param($testScript, $PSScriptRoot, $VerboseTests)

    Write-Output "TestScript: $testScript"

    # Run pester for the scripts
    Invoke-Pester -Script @{Path = "$testScript"; Parameters = @{Verbose = $VerboseTests}} -PassThru
}

# Start searching for scripts from wherever RunPesterTests.ps1 lives
$TestScriptsLocation = $PSScriptRoot
Write-Output "Test Script Location: $TestScriptsLocation"

# Filter down to a specific test suite, if one was passed in
if ($TestSuite -and $TestSuite -ne "*") {
    $TestScripts = Get-ChildItem -Include *.tests.ps1, *.test.ps1 -Recurse -Path $TestScriptsLocation | Where-Object {$_.Name.StartsWith($TestSuite, "CurrentCultureIgnoreCase")}
}
else {
    $TestScripts = Get-ChildItem -Include *.tests.ps1, *.test.ps1 -Recurse -Path $TestScriptsLocation
}

$TestScripts | ForEach-Object {
    Write-Output "Found Script: $_"
}

if (-not $TestScripts) {
    Write-Error "Unable to find any test scripts.."
}
else {
    $jobs = @()

    $TestScripts | ForEach-Object {
        $jobs += Start-ThreadJob -Script $invokePesterScriptBlock -ArgumentList $_, $PSScriptRoot, $VerboseTests
    }

    $jobs | ForEach-Object {
        Write-Output "-----------------------------------------------------------------"
        Recieve-Job -Wait -Verbose
    }
}
