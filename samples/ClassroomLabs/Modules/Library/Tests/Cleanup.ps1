[cmdletbinding()]
Param()
Import-Module $PSScriptRoot\..\Az.LabServices.psm1

. $PSScriptRoot\Utils.ps1

$rg  = Get-FastResourceGroup
$la  = Get-FastLabAccount
$lab = Get-FastLab

Describe 'Cleanup resources as might get left dangling' {
    It 'Can cleanup everything' {
            
        Get-AzLabAccount -ResourceGroupName $rg.ResourceGroupName | Where-Object {$_.Name.StartsWith('Temp')} | Remove-AzLabAccount
        $la | Get-AzLab | Where-Object {$_.Name.StartsWith('Temp')} | Remove-AzLab
        $lab | Get-AzLabSchedule | Where-Object {$_.properties.start -lt (Get-Date).AddDays(-7)} | Remove-AzLabSchedule
    }    
}
