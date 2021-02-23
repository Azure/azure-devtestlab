[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "If a lab contains any of these tags, it will be selected")]
    [ValidateNotNullOrEmpty()]
    [string]
    $AnId,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int]
    $ThrottleLimit = 5

)

Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../LabCreationLibrary.psm1 -Force

$CsvConfigFile | Import-LabsCsv | Select-Lab -AnId $AnId | Publish-Labs -ThrottleLimit $ThrottleLimit