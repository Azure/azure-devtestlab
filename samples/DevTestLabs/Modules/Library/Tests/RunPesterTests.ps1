Param(
    [Parameter(Mandatory = $false, HelpMessage="The suite of tests to execute, this is done by string matching (StartsWith) on filenames - 'Lab' matches 'Lab.tests.ps1' and 'LabUsers.tests.ps1'")]
    [string] $TestSuite
)

# Import the module here to make sure we validate up front versions of Azure Powershell
Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1

# Check if we have a newer version of Pester, if not - let's install it
$pesterModule = Get-Module -ListAvailable | Where-Object {$_.Name -eq "Pester"} | Sort-Object -Descending Version | Select-Object -First 1
if ($pesterModule.Version.Major -lt 4 -or $pesterModule.version.Minor -lt 8) {
    # We don't have a new enough version of Pester, install it
    Write-Output "Latest version of Pester is $($pesterModule.Version), Installing the latest Pester from PSGallery"
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    Install-Module -Name Pester -Force -Scope CurrentUser
}

$invokePesterScriptBlock = {
    param($testScript, $PSScriptRoot)

    Write-Output "TestScript: $testScript"

    # Run pester for the scripts
    Invoke-Pester -Script @{Path = "$testScript"; Parameters = @{Verbose = $true}} -PassThru
}

# Start searching for scripts from wherever RunPesterTests.ps1 lives
$TestScriptsLocation = $PSScriptRoot
Write-Output "Test Script Location: $TestScriptsLocation"

# Filter down to a specific test suite, if one was passed in
if ($TestSuite) {
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
        $jobs += Start-Job -Script $invokePesterScriptBlock -ArgumentList $_, $PSScriptRoot
    }

    while ($jobs -and $jobs.Count -gt 0) {

        # look for a completed job
        $jobs | ForEach-Object {
            if ($_.State -ne "NotStarted" -and $_.State -ne "Running") {

                # We found a completed job! Let's peek in and see if we have any failures...  If so - we want verbose output instead of basic output
                $failures = $_.Output.TestResult | Where-Object {$_.Passed -eq $false}

                Write-Output "-----------------------------------------------------------------"
                if ($failures) {
                    $result = Receive-Job -Wait -Job $_ -Verbose
                }
                else {
                    $result = Receive-Job -Wait -Job $_
                }

                Remove-Job -Job $_
            }

            Start-Sleep -Seconds 30
            $jobs = Get-Job
        }
    }
}
