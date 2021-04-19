[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $JsonConfigFile,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int]
    $ThrottleLimit = 5
)

Import-Module ../../Az.LabServices.psm1 -Force
Import-Module ../Az.LabServices.BulkOperations.psm1 -Force

Get-Content -Raw -Path $JsonConfigFile | ConvertFrom-Json | Publish-Labs -ThrottleLimit $ThrottleLimit