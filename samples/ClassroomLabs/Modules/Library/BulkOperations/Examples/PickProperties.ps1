[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile,

    [Parameter(Mandatory = $false, HelpMessage = "Which lab properties to show a prompt for")]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $Properties
)

Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../Az.LabServices.BulkOperations.psm1 -Force

$CsvConfigFile `
  | Import-LabsCsv `
  | Show-LabMenu -Properties $Properties `
  | Publish-Labs