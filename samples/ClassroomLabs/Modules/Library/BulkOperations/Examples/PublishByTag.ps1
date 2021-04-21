[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "If a lab contains any of these tags, it will be selected")]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $SomeTags,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int]
    $ThrottleLimit = 5
)

Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../Az.LabServices.BulkOperations.psm1 -Force

$CsvConfigFile | Import-LabsCsv | Select-Lab -SomeTags $SomeTags | Publish-Labs -ThrottleLimit $ThrottleLimit