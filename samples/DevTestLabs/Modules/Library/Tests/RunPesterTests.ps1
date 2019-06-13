Param(
    [Parameter(Mandatory = $false, HelpMessage="The suite of tests to execute")]
    [string] $TestSuite
)

# Check if we have a newer version of Pester, if not - let's install it
$pesterModule = Get-Module -ListAvailable | Where-Object {$_.Name -eq "Pester"} | Sort-Object -Descending Version | Select-Object -First 1
if ($pesterModule.Version.Major -lt 4 -or $pesterModule.version.Minor -lt 8) {
    # We don't have a new enough version of Pester, install it
    Write-Output "Latest version of Pester is $($pesterModule.Version), Installing the latest Pester from PSGallery"
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    Install-Module -Name Pester -Force -Scope CurrentUser
}

if ($TestSuite) {
    $TestScriptsLocation = (Join-Path $PSScriptRoot $TestSuite)
}
else {
    $TestScriptsLocation = $PSScriptRoot
}

Write-Output "Test Script Location: $TestScriptsLocation"
$TestScripts = Get-ChildItem -Include "*.tests.ps1" -Recurse -Path $TestScriptsLocation

if (-not $TestScripts) {
    Write-Error "Unable to find any test scripts.."
}
else {
    $result = Invoke-Pester -Script $TestScripts -PassThru
    if ($result.FailedCount -ne 0) {
        Write-Error "Pester returned errors"
    }
}
