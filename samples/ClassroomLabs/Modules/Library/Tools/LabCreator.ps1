[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [string]
    $CsvConfigFile,

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [int]
    $ThrottleLimit = 5
)

Import-Module ../Az.LabServices.psm1 -Force
Install-Module -Name ThreadJob -Scope CurrentUser -Force

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$init = {
    function New-AzLabSingle {
        [CmdletBinding()]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Scope = "Function")]
        param(
            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $ResourceGroupName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $Location,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $LabAccountName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $LabName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateNotNullOrEmpty()]
            $ImageName,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [string]
            $AadGroupId = "",

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [int]
            $MaxUsers,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [int]
            $UsageQuota,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [ValidateSet('Restricted', 'Open')]
            $UsageMode,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [bool]
            $SharedPassword,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            $Size,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [bool]
            $GpuDriverEnabled,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string]
            $Title,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string]
            $Descr,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string]
            $UserName,

            [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
            [string]
            $Password,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [bool]
            $LinuxRdp,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [string[]]
            $Emails,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [string[]]
            $LabOwnerEmails,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [int]
            $idleGracePeriod,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [int]
            $idleOsGracePeriod,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [int]
            $idleNoConnectGracePeriod,
            
            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            [string]
            $Invitation,

            [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
            $Schedules
        )

        Write-Host "Start creation of $LabName"

        $la = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName
        $lab = $la | Get-AzLab -LabName $LabName

        if ($lab) {
            $lab = $lab | Set-AzLab -MaxUsers $MaxUsers -UsageQuotaInHours $UsageQuota -UserAccessMode $UsageMode  -SharedPasswordEnabled:$SharedPassword
            Write-Host "$LabName lab already exist. Republished."
        }
        else {
            # Try to load shared image and then gallery image
            $img = $la | Get-AzLabAccountSharedImage | Where-Object { $_.name -like $ImageName }

            if(-not $img) {
                $img = $la | Get-AzLabAccountGalleryImage | Where-Object { $_.name -like $ImageName }
      
                if (-not $img -or @($img).Count -ne 1) { Write-Error "$ImageName pattern doesn't match just one gallery image." }
            }

            Write-Host "Image $ImageName found."
            Write-Host "Linux $LinuxRdp***"
    
            $lab = $la `
            | New-AzLab -LabName $LabName -Image $img -Size $Size -UserName $UserName -Password $Password -LinuxRdpEnabled:$LinuxRdp -InstallGpuDriverEnabled:$GpuDriverEnabled -UsageQuotaInHours $UsageQuota `
                -idleGracePeriod $idleGracePeriod -idleOsGracePeriod $idleOsGracePeriod -idleNoConnectGracePeriod $idleNoConnectGracePeriod -AadGroupId $AadGroupId `
            | Publish-AzLab `
            | Set-AzLab -MaxUsers $MaxUsers -UserAccessMode $UsageMode -SharedPasswordEnabled:$SharedPassword

            # If we have any lab owner emails, we need to assign the RBAC permission
            $LabOwnerEmails | ForEach-Object {
                # Check if Lab Owner role already exists (the role assignment is added by default by the person who runs the script), if not create it
                if (-not (Get-AzRoleAssignment -SignInName $_ -Scope $lab.id -RoleDefinitionName Owner)) {
                    New-AzRoleAssignment -SignInName $_ -Scope $lab.id -RoleDefinitionName Owner | Out-Null
                }

                # Check if the lab account reader role already exists, if not create it
                if (-not (Get-AzRoleAssignment -SignInName $_ -ResourceGroupName $lab.ResourceGroupName -ResourceName $lab.LabAccountName -ResourceType "Microsoft.LabServices/labAccounts" -RoleDefinitionName Reader)) {
                    New-AzRoleAssignment -SignInName $_ -ResourceGroupName $lab.ResourceGroupName -ResourceName $lab.LabAccountName -ResourceType "Microsoft.LabServices/labAccounts" -RoleDefinitionName Reader | Out-Null 
                }
            }

            Write-Host "$LabName lab doesn't exist. Created it."
        }

        #Section to send out invitation emails
        if ($Emails) {

            $lab = $lab | Add-AzLabUser -Emails $Emails
            if ($Invitation) {
                $users = $lab | Get-AzLabUser
                $users | ForEach-Object { $lab | Send-AzLabUserInvitationEmail -User $_ -InvitationText $invitation } | Out-Null
                Write-Host "Added Users: $Emails."
            }
        }

        if ($Schedules) {
            $Schedules | ForEach-Object { $_ | New-AzLabSchedule -Lab $lab } | Out-Null
            Write-Host "Added all schedules."
        }
    }
}

# No need to parallelize this one as super fast
function New-ResourceGroups {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]
        $ConfigObject
    )

    $Rgs = $ConfigObject | Select-Object -Property ResourceGroupName, Location -Unique
    Write-Host "Operating on the following RGs:"
    Write-Host $Rgs
    
    $Rgs | ForEach-Object {
        if (-not (Get-AzResourceGroup -ResourceGroupName $_.ResourceGroupName -EA SilentlyContinue)) {
            New-AzResourceGroup -ResourceGroupName $_.ResourceGroupName -Location $_.Location | Out-null
            Write-Host "$($_.ResourceGroupName) resource group didn't exist. Created it."
        }
    }
}

function New-Accounts {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]]
        $ConfigObject
    )

    $lacs = $ConfigObject | Select-Object -Property ResourceGroupName, LabAccountName -Unique
    Write-Host "Operating on the following Lab Accounts:"
    Write-Host $lacs

    $block = {
        param($path, $ResourceGroupName, $LabAccountName)

        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        $modulePath = Join-Path $path '..\Az.LabServices.psm1'
        Import-Module $modulePath

        if ((Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName) -eq $null ){
            New-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName | Out-Null
        }
        Write-Host "$LabAccountName lab account created or found."
    }
    
    Write-Host "Starting lab accounts creation in parallel. Can take a while."
    $jobs = @()
    $lacs | ForEach-Object {
        $jobs += Start-ThreadJob -ScriptBlock $block -ArgumentList $PSScriptRoot, $_.ResourceGroupName, $_.LabAccountName -Name $_.LabAccountName -ThrottleLimit $ThrottleLimit
    }

    $hours = 1
    $jobs | Wait-Job -Timeout (60 * 60 * $hours) | Receive-Job
}
  
function New-AzLabMultiple {
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

        $modulePath = Join-Path $path '..\Az.LabServices.psm1'
        Import-Module $modulePath
        # Really?? It got to be the lines below? Doing a ForEach doesn't work ...
        $input.movenext() | Out-Null
     
        $obj = $input.current[0]

        Write-Verbose "object inside the newazmultiple block $obj"
        $obj | New-AzLabSingle
    }

    Write-Host "Starting creation of all labs in parallel. Can take a while."

    $jobs = $ConfigObject | ForEach-Object {
        Write-Verbose "From config: $_"
        Start-ThreadJob  -InitializationScript $init -ScriptBlock $block -ArgumentList $PSScriptRoot -InputObject $_ -Name $_.LabName -ThrottleLimit $ThrottleLimit
    }

    $hours = 2
    $jobs | Wait-Job -Timeout (60 * 60 * $hours) | Receive-Job
}

function Import-Schedules {
    param($schedules)

    $file = "./$schedules.csv"

    $scheds = Import-Csv $file
    $scheds | Foreach-Object {
        $_.WeekDays = ($_.WeekDays.Split(',')).Trim()
    }
    return $scheds
}

$labs = Import-Csv -Path $CsvConfigFile

Write-Verbose ($labs | Format-Table | Out-String)

$labs | ForEach-Object {

    # Validate that the name is good, before we start creating labs
    if (-not ($_.LabName -match "^[a-zA-Z0-9_, '`"!|-]*$")) {
        Write-Error "Lab Name '$($_.LabName)' can't contain special characters..."
    }

    # Checking to ensure the user has changd the example username/passwork in CSV files
    if ($_.UserName -and ($_.UserName -ieq "test0000")) {
        Write-Warning "Lab $($_.LabName) is using the default UserName from the example CSV, please update it for security reasons"
    }
    if ($_.Password -and ($_.Password -ieq "Test00000000")) {
        Write-Warning "Lab $($_.LabName) is using the default Password from the example CSV, please update it for security reasons"
    }

    if ((Get-Member -InputObject $_ -Name 'Emails') -and ($_.Emails)) {
        $_.Emails = ($_.Emails.Split(';')).Trim()
    }

    if ((Get-Member -InputObject $_ -Name 'LabOwnerEmails') -and ($_.LabOwnerEmails)) {
        $_.LabOwnerEmails = ($_.LabOwnerEmails.Split(';')).Trim()
    }

    if (Get-Member -InputObject $_ -Name 'GpuDriverEnabled') {
        if ($_.GpuDriverEnabled) {
            $_.GpuDriverEnabled = [System.Convert]::ToBoolean($_.GpuDriverEnabled)
        }
        else {
            $_.GpuDriverEnabled = $false
        }
    }
    else {
        Add-Member -InputObject $_ -MemberType NoteProperty -Name "GpuDriverEnabled" -Value $false
    }

    if (Get-Member -InputObject $_ -Name 'LinuxRdp') {
        if ($_.LinuxRdp) {
            $_.LinuxRdp = [System.Convert]::ToBoolean($_.LinuxRdp)
        }
        else {
            $_.LinuxRdp = $false
        }
    }
    else {
        Add-Member -InputObject $_ -MemberType NoteProperty -Name "LinuxRdp" -Value $false
    }

    $_.SharedPassword = [System.Convert]::ToBoolean($_.SharedPassword)
    if ((Get-Member -InputObject $_ -Name 'Schedules') -and ($_.Schedules)) {
        Write-Host "Setting schedules for $($_.LabName)"
        $_.Schedules = Import-Schedules -schedules $_.Schedules
    }
}

Write-Verbose ($labs | ConvertTo-Json -Depth 10 | Out-String)

# Needs to create resources in this order, aka parallelize in these three groups, otherwise we get contentions:
# i.e. different jobs trying to create the same common resource (RG or lab account)
New-ResourceGroups  -ConfigObject $labs
New-Accounts        -ConfigObject $labs
New-AzLabMultiple   -ConfigObject $labs
