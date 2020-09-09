Param(
    [Parameter(Mandatory = $false, HelpMessage="The suite of tests to execute, this is done by string matching (StartsWith) on filenames - 'Lab' matches 'Lab.tests.ps1' and 'LabUsers.tests.ps1'")]
    [string] $TestSuite = "*",

    [Parameter(Mandatory = $false, HelpMessage="If we should run the tests in 'verbose' mode for extra logging")]
    [bool] $VerboseTests = $false
)

Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1

# This allows the parallel tests not to give up on all of them when one test fails. Using just 'Continue' doesn't do it. Mystery.
$ErrorActionPreference="SilentlyContinue"

$pesterModule = Get-Module -ListAvailable | Where-Object {$_.Name -eq "Pester"} | Sort-Object -Descending Version | Select-Object -First 1
if ($pesterModule.Version.Major -lt 4 -or $pesterModule.version.Minor -lt 8) {
    Write-Output "Latest version of Pester is $($pesterModule.Version), Installing the latest Pester from PSGallery"
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    Install-Module -Name Pester -Force -Scope CurrentUser
}

#$threadModule = Get-Module -ListAvailable | Where-Object {$_.Name -eq "ThreadJob"} | Sort-Object -Descending Version | Select-Object -First 1
#if (-not $threadModule) {
#    Write-Output "Don't have a version of ThreadJob module locally, installing from PSGallery"
#    Install-Module -Name ThreadJob -Force -Scope CurrentUser
#}

$invokePesterScriptBlock = {
    param($testScript, $PSScriptRoot, $VerboseTests)

    $ErrorActionPreference="Continue"

    Write-Output "TestScript: $testScript"

    try {
        $outputFile = Split-Path $testScript -leaf
        $outputPath = (Join-Path -Path $PSScriptRoot -ChildPath $outputFile) + '.xml'
        Invoke-Pester -Script @{Path = "$testScript"; Parameters = @{Verbose = $VerboseTests}} -OutputFile $outputPath -OutputFormat NUnitXml
    } catch {

    }
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
        $jobName = Split-Path $_ -leaf
        $jobs += Start-Job -Script $invokePesterScriptBlock -ArgumentList $_, $PSScriptRoot, $VerboseTests -Name $jobName
        # Delay between starting jobs so all the 'setup' doesn't happen at the same time
        Start-Sleep -Seconds 60
    }

    # Write the output one at a time
    $jobs | ForEach-Object {
        Receive-Job -Job $_ -Wait
        Remove-Job -Job $_
    }
}
