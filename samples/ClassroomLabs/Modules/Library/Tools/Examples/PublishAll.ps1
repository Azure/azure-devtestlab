[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int]
    $ThrottleLimit = 5
)

Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../LabCreationLibrary.psm1 -Force

$CsvConfigFile | Import-LabsCsv | Publish-Labs