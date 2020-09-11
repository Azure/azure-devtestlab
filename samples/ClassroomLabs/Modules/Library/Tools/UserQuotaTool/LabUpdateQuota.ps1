[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile
)

Import-Module .\Az.LabServices.psm1 -Force
Import-Module .\Quota.psm1 -Force

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$init = {
    function Update-AzLabSingleQuota {
        [CmdletBinding()]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Scope = "Function")]
        param(
            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $ResourceGroupName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $LabAccountName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $LabName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $QuotaExtension
        )

        Write-Host "Start updating users quota for $LabName"

        $la = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName

        $lab = $la | Get-AzLab -LabName $LabName

        $users = $lab | Get-AzLabUser 

        $currentQuota = Get-Hours($lab.properties.usageQuota)

        foreach ($user in $users) {
   
            $totalUsage = Get-Hours($user.Properties.totalUsage)
            #if ($user.Properties.additionalUsageQuota) {
            #    $currentAddUsage = Get-Hours($user.Properties.additionalUsageQuota)
            #}
            #else {
            #    $currentAddUsage = 0
            #}
            
    
            $currentHours = ($currentQuota) - $totalUsage
            $AddHours = $QuotaExtension - $currentHours
            if ($AddHours -gt 0) {
                Add-AzLabStudentUsage -Lab $lab -Email $user.properties.email -AdditionalUsage $AddHours
            }
            
        }
    
        Write-Host "$Lab students usage updated."

    }
}

  
function Update-AzLabMultiple {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]
        $ConfigObject
    )

    $block = {
        param($path)

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
        
        #$modulePath = Join-Path $path '.' 'Az.LabServices.psm1'
        #Import-Module #$modulePath
        Import-Module .\Az.LabServices.psm1 -Force
        Import-Module .\Quota.psm1 -Force
        # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
        $input.movenext() | Out-Null
        $obj = $input.current[0]
        Write-Verbose "object inside the newazmultiple block $obj"
        $obj | Update-AzLabSingleQuota
    }

    Write-Host "Starting creation of all labs in parallel. Can take a while."

    $jobs = $ConfigObject | ForEach-Object {
        Write-Verbose "From config: $_"
        Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name $_.LabName -ThrottleLimit 5
    }

    $hours = 2
    $jobs | Wait-Job -Timeout (60 * 60 * $hours) | Receive-Job
    #| out-file c:/MinneapolisEdu/jobs.log -append   
}


$labs = Import-Csv -Path $CsvConfigFile

Write-Verbose ($labs | Format-Table | Out-String)

Write-Verbose ($labs | ConvertTo-Json -Depth 10 | Out-String)

# Needs to create resources in this order, aka parallelize in these three groups, otherwise we get contentions:
# i.e. different jobs trying to create the same common resource (RG or lab account)
#New-ResourceGroups  -ConfigObject $labs
#New-Accounts        -ConfigObject $labs
Update-AzLabMultiple -ConfigObject $labs