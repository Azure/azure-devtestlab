[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Id for the lab to publish")]
    [ValidateNotNullOrEmpty()]
    [string]
    $AnId
    )

Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../Az.LabServices.BulkOperations.psm1 -Force
    
$CsvConfigFile `
  | Import-LabsCsv `
  | Select-Lab -Id $AnId `
  | Set-LabProperty -ResourceGroup Staging -MaxUsers 50 `
  | Publish-Labs