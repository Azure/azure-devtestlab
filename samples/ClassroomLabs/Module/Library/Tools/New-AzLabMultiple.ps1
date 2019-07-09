function New-AzLabMultiple {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]
        $ConfigObject
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    . ./New-AzLabSingle.ps1

    $ConfigObject | ForEach-Object {$_ | NewAzLabSingle}
<#     $export_functions = { Function New-AzLabSingle { $function:NewAzLabSingle } }

    $jobs = @()
    foreach ($config in $ConfigObject) {
        if (-not $config.LabName) {
            Write-Error "$config doesn't contain a lab name"
        }
        $jobs += Start-Job  -InitializationScript $export_functions -ScriptBlock { $Input | New-AzLabSingle } -InputObject $config -Name $config.LabName
    }
    $jobs | Receive-Job -Wait
 #>
}

