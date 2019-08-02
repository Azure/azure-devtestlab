Param(
    [Parameter(Mandatory = $false, HelpMessage="The suite of tests to execute, this is done by string matching (StartsWith) on filenames - 'Lab' matches 'Lab.tests.ps1' and 'LabUsers.tests.ps1'")]
    [string] $TestSuite,

    [Parameter(Mandatory = $false, HelpMessage="Run the tests in parallel using jobs, and then summarize the results")]
    [switch] $AsJob = $false
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
    param($testScripts, $PSScriptRoot)

    # In the job, we have to re-import the library for this process
    Import-Module $PSScriptRoot\..\Az.DevTestLabs2.psm1

    # Run pester for the scripts
    Invoke-Pester -Script $testScripts -PassThru
}

# Start searching for scripts from wherever RunPesterTests.ps1 lives
$TestScriptsLocation = $PSScriptRoot
Write-Output "Test Script Location: $TestScriptsLocation"

# Filter down to a specific test suite, if one was passed in
if ($TestSuite) {
    $TestScripts = Get-ChildItem -Include *.tests.ps1, *.test.ps1 -Recurse -Path $TestScriptsLocation | Where-Object {$_.Name.StartsWith($TestSuite)}
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
    if ($AsJob) {
        $jobs = @()
        
        $TestScripts | ForEach-Object {
#            $jobs += Start-Job -Script $invokePesterScriptBlock -ArgumentList $_, $PSScriptRoot
        }

        if($jobs.Count -ne 0)
        {
            Write-Output "Waiting for $($jobs.Count) test runner jobs to complete"
            foreach ($job in $jobs){
                $result = Receive-Job $job -Wait

                if ($result.FailedCount -ne 0) {
                    Write-Error "Pester returned errors for $($result.TestResult.Describe) - $($result.TestResult.Context)"
                }
            }
            Remove-Job -Job $jobs
        }
        else 
        {
            Write-Output "No test scripts to run"
        }
    } 
    else {

#        $result = Invoke-Pester -Script $TestScripts -PassThru
        if ($result.FailedCount -ne 0) {
            Write-Error "Pester returned errors for $($result.TestResult.Describe) - $($result.TestResult.Context)"
        }
    }
}
