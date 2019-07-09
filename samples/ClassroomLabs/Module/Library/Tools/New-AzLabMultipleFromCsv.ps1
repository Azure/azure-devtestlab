[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile
)

. ./New-AzLabMultiple.ps1

$labs = Import-Csv -Path $CsvConfigFile

$labs | Format-Table | Out-Host

$labs | ForEach-Object { $_.Emails          = $_.Emails.Split(';')
                         $_.LinuxRdp        = [System.Convert]::ToBoolean($_.LinuxRdp)
                         $_.SharedPassword  = [System.Convert]::ToBoolean($_.SharedPassword)
                        }

$labs | ForEach-Object { $_ | New-AzLabMultiple }
