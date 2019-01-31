#Requires -Version 3.0
#Requires -Module Az.Compute

param(
    [string]$vmName = "*"
)

<#
-vmName "FE"
#>

### Ensure connection to Azure RM
$azurecontext = $null
$azurecontext = Get-AzContext -ErrorAction SilentlyContinue
if ($azurecontext -eq $null -or $azurecontext.Account -eq $null -or $azurecontext.Subscription -eq $null) {
    Write-Host "Launching Azure authentication prompt..." -ForegroundColor Green
    Connect-AzAccount
    $azurecontext = Get-AzContext -ErrorAction SilentlyContinue
}
if ($azurecontext -eq $null -or $azurecontext.Account -eq $null -or $azurecontext.Subscription -eq $null){ 
    Write-Host "Unable to get a valid context." -ForegroundColor Red
    return
}

function Generate-DSCArchive($vmName) {
    $dscSourceFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\dsc" -Resolve

    if (Test-Path $dscSourceFolder) {
        $dscSourceFilePaths = @(Get-ChildItem $dscSourceFolder -File -Filter "*$vmName*.ps1" | ForEach-Object -Process {$_.FullName})
        foreach ($dscSourceFilePath in $dscSourceFilePaths) {
            $dscArchiveFilePath = $dscSourceFilePath.Substring(0, $dscSourceFilePath.Length - 4) + ".zip"
            Publish-AzVMDscConfiguration $dscSourceFilePath -OutputArchivePath $dscArchiveFilePath -Force -Verbose
        }
    }
}

Generate-DSCArchive $vmName