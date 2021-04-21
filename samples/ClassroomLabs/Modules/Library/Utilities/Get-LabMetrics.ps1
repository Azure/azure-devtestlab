[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $CsvOutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (Test-Path -Path $CsvOutputFile) {
    Write-Error "Output File cannot already exist, please choose a location to create a new output file..."
}

Import-Module ../Az.LabServices.psm1 -Force
Import-Module ../BulkOperations/Az.LabServices.BulkOperations.psm1 -Force

$labAccounts = Get-AzLabAccount
$labs = $labAccounts | Get-AzLab

# Array to keep track of the metrics, we write it out at the end
$results = @()
$totalStudents = 0
$totalAssignedVMs = 0

$labs | ForEach-Object {
    $students = $_ | Get-AzLabUser -ErrorAction SilentlyContinue
    $assignedVms = $_ | Get-AzLabVm -ErrorAction SilentlyContinue | Where-Object {$_.UserPrincipal}

    $studentCount = ($students | Measure-Object).Count
    $assignedVmsCount = ($assignedVms | Measure-Object).Count

    # Add this lab to our running totals
    $totalStudents += $studentCount
    $totalAssignedVMs += $assignedVmsCount

    $labUsageQuota = Convert-UsageQuotaToHours $_.Properties.usageQuota

    $HoursUsedByStudents = 0
    $StudentsUsedAllQuota = ($students | Where-Object {
        $totalUsage = Convert-UsageQuotaToHours $_.properties.totalUsage
        if (Get-Member -InputObject $_.properties -Name additionalUsageQuota) {
            $additionalUsageQuota = Convert-UsageQuotaToHours $_.properties.additionalUsageQuota
        }
        else {
            $additionalUsageQuota = 0
        }
        $HoursUsedByStudents += $totalUsage

        # Returns true or false, for the Where-Object
        ($totalUsage -gt ($labUsageQuota + $additionalUsageQuota))
    } | Measure-Object).Count

    # Requested metrics:
    #  - Total number of students (projected as possible using it)
    #  - Total number of students actually using it
    #  - Total unassigned VMs in the course
    #  - Number of hours used across all the students in the course
    #  - Number of students maxing out on the hours per course

    $results += [pscustomobject] @{
        ResourceGroupName = $_.ResourceGroupName
        LabAccountName = $_.LabAccountName
        LabName = $_.LabName
        TotalStudents = $studentCount
        StudentsWIthAssignedVMs = $assignedVmsCount
        UnassignedVMs = $studentCount - $assignedVmsCount
        HoursUsedByStudents = $HoursUsedByStudents
        TotalStudentsUsedAllQuota = $StudentsUsedAllQuota
    }
}

Write-Host "Total Number of Lab Accounts:  $(($labAccounts | Measure-Object).Count)"
Write-Host "Total Number of Labs:  $(($labs | Measure-Object).Count)"
Write-Host "Total number of students: $totalStudents"
Write-Host "Total number of assigned VMs: $totalAssignedVMs"

# Write out the CSV file with metrics
$results | Export-Csv -Path $CsvOutputFile
