[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $CsvConfigFile,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $CsvOutputFile,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int]
    $ThrottleLimit = 10,

    [Parameter(Mandatory = $false, HelpMessage = "Only create the groups, but don't add members")]
    [switch]
    $CreateGroupsOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Install the ThreadJob module if the command isn't already available
if (-not (Get-Command -Name "Start-ThreadJob" -ErrorAction SilentlyContinue)) {
    Install-Module -Name ThreadJob -Scope CurrentUser -Force
}

$scriptstartTime = Get-Date
Write-Host "Executing Script for creating AAD Groups and adding students, starting at $scriptstartTime" -ForegroundColor Green

if (Test-Path -Path $CsvOutputFile) {
    Write-Error "Output File cannot already exist, please choose a location to create a new output file..."
}

# Let's make sure we have the right dependencies and they're setup
if (-not (Get-Command -Name "New-AzureAdGroup" -ErrorAction SilentlyContinue)) {
    Write-Error "The Azure Powershell module 'AzureAd' is required to run this script, please install the module and try again"
}

if (-not (Get-AzureADUser -Top 1 -ErrorAction SilentlyContinue)) {
    # NOTE: the command above will throw an error if user isn't logged in
    Write-Error "User does not have enough permissions in Azure AD to query users, cannot continue.."
}

# Import the CSV file into memory
$data = Import-Csv -Path $CsvConfigFile

# Validate that we have OK emails & Group Names, we use "Continue" to make sure we validate everything
$foundError = $false
$data | ForEach-Object -ErrorAction Continue {
    
    # Ensure email field isnt missing
    if (-not (Get-Member -InputObject $_ -Name 'EMail') -or -not $_.EMail) {
        Write-Host "Email is missing for this student:  $_" -ForegroundColor Red
        $foundError = $true
    }

    # Ensure AADGroupName isn't missing
    if (-not (Get-Member -InputObject $_ -Name 'AADGroupName') -or -not $_.AADGroupName) {
        Write-Host "AADGroupName is missing for this student:  $_" -ForegroundColor Red
        $foundError = $true
    }
    
    # Ensure all emails are formatted as an email address
    if ($_.EMail -notmatch "(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|`"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*`")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])") {
        Write-Host "Email is not formatted correctly for this student: $_" -ForegroundColor Red
        $foundError = $true
    }

}

# Write out some stats for the groups
$AadGroups = $data | Select-Object -Property EMail, AADGroupName | Group-Object -Property AADGroupName

Write-Host "Total number of AAD Groups to create: $(($AadGroups | Measure-Object).Count)"
$totalStudents = 0
$minimumStudents = 1000
$maximumStudents = 0

# Count some stats - should be fast, all happening in memory
$AadGroups | ForEach-Object {
    if ($_.Count -gt $maximumStudents) {
        $maximumStudents = $_.Count
    }
    if ($_.Count -lt $minimumStudents) {
        $minimumStudents = $_.Count
    }

    $totalStudents += $_.Count
}

Write-Output "Total number of students to map into groups:  $totalStudents"
Write-Output "Smallest AAD group we'll create:  $minimumStudents members"
Write-Output "Largest AAD group we'll create:  $maximumStudents members"
Write-Output "Average group size:  $($totalStudents/$AadGroups.Count)"

$block = {
    param($AadGroup, $CreateGroupsOnly)

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Let's check if the group already exists, if so - we use it
    $group = Get-AzureADGroup -SearchString $AadGroup.Name -ErrorAction SilentlyContinue

    if (-not $group) {
        Write-Host "  Creating group $($AadGroup.Name)"
        $group = New-AzureADGroup -DisplayName $AadGroup.Name -Description "$($AadGroup.Name) is a group used for Azure Lab Services to define the students in a course and section" -MailEnabled $false -MailNickName $AadGroup.Name -SecurityEnabled $true
    }
    else {
        Write-Host "  Group $($AadGroup.Name) already exists, using it..." -ForegroundColor Yellow
    }

    # We need to sleep briefly to make sure that the group is propogated
    $retries = 3
    while ($retries-- -gt 0 -and -not (Get-AzureADGroup -ObjectId $group.ObjectId)) {
        Start-Sleep -Seconds 30
    }

    if (-not $CreateGroupsOnly)
    {
        $AadGroup.Group | ForEach-Object {
            $user = Get-AzureAdUser -ObjectId $_.EMail

            # Check if the user is alrady a member, if so, we can skip
            if (-not (Get-AzureADGroupMember -ObjectId $group.ObjectId | Where-Object {$_.ObjectId -ieq $user.ObjectId})) {
                Write-Host "  Adding user $($_.EMail) to group $($_.AADGroupName)"
                Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId
            }
            else {
                Write-Host "  User $($_.EMail) already exists in group $($_.AADGroupName)" -ForegroundColor Yellow
            }
        }
    }

    return $group

}

$jobs = @()
$results = @()

$AadGroups | ForEach-Object {
    $jobs += Start-ThreadJob -ScriptBlock $block -ArgumentList $_, $CreateGroupsOnly -ThrottleLimit $ThrottleLimit
}

while (($jobs | Measure-Object).Count -gt 0) {
    $completedJobs = $jobs | Where-Object {($_.State -ieq "Completed") -or ($_.State -ieq "Failed")}
    if (($completedJobs | Measure-Object).Count -gt 0) {
        # Write output for completed jobs, but one by one so output doesn't bleed 
        # together, also use "Continue" so we write the error but don't end the outer script
        $completedJobs | ForEach-Object {
            $result = $_ | Receive-Job -ErrorAction Continue
            if ($_.State -ieq "Completed") {
                $results += $result
            }
        }
        # Trim off the completed jobs from our list of jobs
        $jobs = $jobs | Where-Object {$_.Id -notin $completedJobs.Id}
        # Remove the completed jobs from memory
        $completedJobs | Remove-Job
    }
    # Wait for 10 sec before checking job status again
    Start-Sleep -Seconds 10
}

$results | Select-Object -Property DisplayName, ObjectId | Export-Csv -Path $CsvOutputFile -NoTypeInformation

Write-Host "Completed running script to create AAD groups and add students, total duration $([math]::Round(((Get-Date) - $scriptstartTime).TotalMinutes, 1)) minutes" -ForegroundColor Green
