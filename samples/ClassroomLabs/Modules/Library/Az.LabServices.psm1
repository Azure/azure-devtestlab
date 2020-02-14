# TODO: consider polling on the operation returned by the API in the header as less expensive for RP
# TODO: consider creating proper PS1 documentation for each function

# We are using strict mode for added safety
Set-StrictMode -Version Latest

# We require a relatively new version of Powershell
#requires -Version 3.0

# To understand the code below read here: https://docs.microsoft.com/en-us/powershell/azure/migrate-from-azurerm-to-az?view=azps-2.1.0
# Having both the Az and AzureRm Module installed is not supported, but it is probably common. The library should work in such case, but warn.
# Checking for the presence of the Az module, brings it into memory which causes an exception if AzureRm is present installed in the system. So checking for absence of AzureRm instead.
# If both are absent, then the user will get an error later on when trying to access it.
# If you have the AzureRm module, then everything works fine
# If you have the Az module, we need to enable the AzureRmAliases

$azureRm = Get-Module -Name "AzureRM" -ListAvailable | Sort-Object Version.Major -Descending | Select-Object -First 1
$az = Get-Module -Name "Az.Accounts" -ListAvailable
$justAz = $az -and -not ($azureRm -and $azureRm.Version.Major -ge 6)
$justAzureRm = $azureRm -and (-not $az)

if ($azureRm -and $az) {
    Write-Warning "You have both Az and AzureRm module installed. That is not officially supported. For more read here: https://docs.microsoft.com/en-us/powershell/azure/migrate-from-azurerm-to-az"
}

if ($justAzureRm) {
    if ($azureRm.Version.Major -lt 6) {
        Write-Error "This module does not work correctly with version 5 or lower of AzureRM, please upgrade to a newer version of Azure PowerShell in order to use this module."
    }
    else {
        # This is not defaulted in older versions of AzureRM
        Enable-AzureRmContextAutosave -Scope CurrentUser -erroraction silentlycontinue
        Write-Warning "You are using the deprecated AzureRM module. For more info, read https://docs.microsoft.com/en-us/powershell/azure/migrate-from-azurerm-to-az"
    }
}

if ($justAz) {
    Enable-AzureRmAlias -Scope Local -Verbose:$false
    Enable-AzureRmContextAutosave -Scope CurrentUser -erroraction silentlycontinue
}

# We want to track usage of library, so adding GUID to user-agent at loading and removig it at unloading
$libUserAgent = "pid-dec6e7d9-d150-405e-985c-feeecb83e9d5"
[Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent($libUserAgent)

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.RemoveUserAgent($libUserAgent)
}

# The reason for using the following function and managing errors as done in the cmdlets below is described
# at the link here: https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/37#issuecomment-347257738
# The scheme permits writing the cmdlet code assuming the code after an error is not executed,
# and at the same time allows the caller to decide if the cmdlet *overall* should stop or continue for errors
# by using the standard ErrorAction syntax. It also mentions the correct cmdlet name in the text for the error
# without exposing the innards of the function. The price to pay is boilerplate code, reduced by BeginPreamble.
# You might think you might reduce boilerplate even more by creating a function that takes
# a scriptBlock and wrap it in the correct begin{} process {try{} catch{}} end {}
# but that ends up showing the source line of the error as such function, not the cmdlet.

# Import (with . syntax) this at the start of each begin block
function BeginPreamble {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Scope = "Function")]
    param()
    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    $callerEA = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
}

# TODO: consider reducing function below to just get ErrorActionPreference
# Taken from https://gallery.technet.microsoft.com/scriptcenter/Inherit-Preference-82343b9d
function Get-CallerPreference {
    [CmdletBinding(DefaultParameterSetName = 'AllVariables')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_.GetType().FullName -eq 'System.Management.Automation.PSScriptCmdlet' })]
        $Cmdlet,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(ParameterSetName = 'Filtered', ValueFromPipeline = $true)]
        [string[]]
        $Name
    )

    begin {
        $filterHash = @{ }
    }

    process {
        if ($null -ne $Name) {
            foreach ($string in $Name) {
                $filterHash[$string] = $true
            }
        }
    }

    end {
        # List of preference variables taken from the about_Preference_Variables help file in PowerShell version 4.0

        $vars = @{
            'ErrorView'                     = $null
            'FormatEnumerationLimit'        = $null
            'LogCommandHealthEvent'         = $null
            'LogCommandLifecycleEvent'      = $null
            'LogEngineHealthEvent'          = $null
            'LogEngineLifecycleEvent'       = $null
            'LogProviderHealthEvent'        = $null
            'LogProviderLifecycleEvent'     = $null
            'MaximumAliasCount'             = $null
            'MaximumDriveCount'             = $null
            'MaximumErrorCount'             = $null
            'MaximumFunctionCount'          = $null
            'MaximumHistoryCount'           = $null
            'MaximumVariableCount'          = $null
            'OFS'                           = $null
            'OutputEncoding'                = $null
            'ProgressPreference'            = $null
            'PSDefaultParameterValues'      = $null
            'PSEmailServer'                 = $null
            'PSModuleAutoLoadingPreference' = $null
            'PSSessionApplicationName'      = $null
            'PSSessionConfigurationName'    = $null
            'PSSessionOption'               = $null

            'ErrorActionPreference'         = 'ErrorAction'
            'DebugPreference'               = 'Debug'
            'ConfirmPreference'             = 'Confirm'
            'WhatIfPreference'              = 'WhatIf'
            'VerbosePreference'             = 'Verbose'
            'WarningPreference'             = 'WarningAction'
        }


        foreach ($entry in $vars.GetEnumerator()) {
            if (([string]::IsNullOrEmpty($entry.Value) -or -not $Cmdlet.MyInvocation.BoundParameters.ContainsKey($entry.Value)) -and
                ($PSCmdlet.ParameterSetName -eq 'AllVariables' -or $filterHash.ContainsKey($entry.Name))) {
                $variable = $Cmdlet.SessionState.PSVariable.Get($entry.Key)

                if ($null -ne $variable) {
                    if ($SessionState -eq $ExecutionContext.SessionState) {
                        Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                    }
                    else {
                        $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                    }
                }
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'Filtered') {
            foreach ($varName in $filterHash.Keys) {
                if (-not $vars.ContainsKey($varName)) {
                    $variable = $Cmdlet.SessionState.PSVariable.Get($varName)

                    if ($null -ne $variable) {
                        if ($SessionState -eq $ExecutionContext.SessionState) {
                            Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                        }
                        else {
                            $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                        }
                    }
                }
            }
        }

    } # end

} # function Get-CallerPreference

function PrintHashtable {
    param($hash)

    return ($hash.Keys | ForEach-Object { "$_ $($hash[$_])" }) -join "|"
}

# Taken from https://gallery.technet.microsoft.com/scriptcenter/ConvertFrom-ISO8601Duration-704763e0
function ConvertFrom-ISO8601Duration {
    
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([System.TimeSpan])]

    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [Alias('ISO8601', 'String')]
        [string]$Duration
    )

    $pattern = '^P?T?((?<Years>\d+)Y)?((?<Months>\d+)M)?((?<Weeks>\d+)W)?((?<Days>\d+)D)?(T((?<Hours>\d+)H)?((?<Minutes>\d+)M)?((?<Seconds>\d*(\.)?\d*)S)?)$'

    if ($Duration -match $pattern) {
        Set-StrictMode -Off
        $dt = [datetime]::MinValue
        Write-Verbose (PrintHashtable -hash $Matches)

        if ($Matches.Seconds) { $dt = $dt.AddSeconds($Matches.Seconds) }
        if ($Matches.Minutes) { $dt = $dt.AddMinutes($Matches.Minutes) }
        if ($Matches.Hours) { $dt = $dt.AddHours($Matches.Hours) }
        if ($Matches.Days) { $dt = $dt.AddDays($Matches.Days) }
        if ($Matches.Weeks) { $dt = $dt.AddDays(7 * $Matches.Weeks) }
        if ($Matches.Months) { $dt = $dt.AddMonths($Matches.Months) }
        if ($Matches.Years) { $dt = $dt.AddYears($Matches.Years) }
        $dt - [datetime]::MinValue
    }
    else {
        Write-Warning 'The provided string does not match the ISO 8601 duration format'
    }
}

function Get-AzureRmCachedAccessToken() {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Off

    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if (-not $azureRmProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."
    }

    $currentAzureContext = Get-AzureRmContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
    Write-Debug ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
    return $token.AccessToken
}

function GetHeaderWithAuthToken {

    $authToken = Get-AzureRmCachedAccessToken
    Write-Debug $authToken

    $header = @{
        'Content-Type'  = 'application/json'
        "Authorization" = "Bearer " + $authToken
        "Accept"        = "application/json;odata=fullmetadata"
    }

    return $header
}

$ApiVersion = 'api-version=2019-01-01-preview'

function GetLabAccountUri($ResourceGroupName) {
    $subscriptionId = (Get-AzureRmContext).Subscription.Id
    return "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.LabServices/labaccounts"
}

function ConvertToUri($resource) {
    "https://management.azure.com" + $resource.Id
}

function InvokeRest($Uri, $Method, $Body, $params) {
    $authHeaders = GetHeaderWithAuthToken

    $fullUri = $Uri + '?' + $ApiVersion

    if ($params) { $fullUri += '&' + $params }

    if ($body) { Write-Verbose $body }    
    $result = Invoke-WebRequest -Uri $FullUri -Method $Method -Headers $authHeaders -Body $Body -UseBasicParsing
    $resObj = $result.Content | ConvertFrom-Json
    
    # Happens with Post commands ...
    if (-not $resObj) { return $resObj }

    if (Get-Member -inputobject $resObj -name "Value" -Membertype Properties) {
        return $resObj.Value | Enrich
    }
    else {
        return $resObj | Enrich
    }
}

# The WaitXXX functions differ just for the property and value tested.
# We could use just one parametrized function instead,but left two for name clarity
# and to leave open option of having differing algos later on. Or maybe I am just lazy.
function WaitPublishing($uri, $delaySec, $retryCount, $params) {
    Write-Verbose "Retrying $retryCount times every $delaySec seconds."

    $tries = 0;
    $res = InvokeRest -Uri $uri -Method 'Get' -params $params

    while (-not ($res.properties.publishingState -eq 'Published')) {
        Write-Verbose "$tries : PublishingState = $($res.properties.publishingState)"
        if (-not ($tries -lt $retryCount)) {
            throw ("$retryCount retries of retrieving $uri with PublishingState = Published failed")
        }
        Start-Sleep -Seconds $delaySec
        $res = InvokeRest -Uri $uri -Method 'Get' -params $params
        $tries += 1
    }
    return $res
}

function WaitProvisioning($uri, $delaySec, $retryCount, $params) {
    Write-Verbose "Retrying $retryCount times every $delaySec seconds."

    $tries = 0;
    $res = InvokeRest -Uri $uri -Method 'Get' -params $params

    while (-not ($res.properties.provisioningState -eq 'Succeeded')) {
        Write-Verbose "$tries : ProvisioningState = $($res.properties.provisioningState)"
        if (-not ($tries -lt $retryCount)) {
            throw ("$retryCount retries of retrieving $uri with ProvisioningState = Succeeded failed")
        }
        Start-Sleep -Seconds $delaySec
        $res = InvokeRest -Uri $uri -Method 'Get' -params $params
        $tries += 1
    }
    return $res
}

function WaitStatusChange($uri, $delaySec, $retryCount, $params, $status) {
    Write-Verbose "Retrying $retryCount times every $delaySec seconds."

    $tries = 0;
    $res = InvokeRest -Uri $uri -Method 'Get' -params $params

    while (-not ($res.status -eq $status)) {
        Write-Verbose "$tries : Status = $($res.status)"
        if (-not ($tries -lt $retryCount)) {
            throw ("$retryCount retries of retrieving $uri with Status = $status failed")
        }
        Start-Sleep -Seconds $delaySec
        $res = InvokeRest -Uri $uri -Method 'Get' -params $params
        $tries += 1
    }
    return $res
}

# This function adds properties to the returned resource to make it more easily queryable and reportable
function Enrich {
    [CmdletBinding()]
    param([parameter(Mandatory = $true, ValueFromPipeline = $true)] $resource)

    begin { . BeginPreamble }

    process {
        foreach ($rs in $resource) {
            if ($rs.id) {
                $parts = $rs.id.Split('/')
                $len = $parts.Count

                # The id for a VM looks like this:
                # /subscriptions/SS/resourcegroups/RG/providers/microsoft.labservices/labaccounts/LA/labs/LAB/environmentsettings/default/environments/VM

                # The code below figures out the kind of resources by how deeep in the Id we are and add appropriate properties depending on the type
                if ($len -ge 4) { $rs | Add-Member -MemberType NoteProperty -Name ResourceGroupName -Value $parts[4] -Force }
                if ($len -ge 8) { $rs | Add-Member -MemberType NoteProperty -Name LabAccountName -Value $parts[8] -Force }
                if ($len -ge 10) { $rs | Add-Member -MemberType NoteProperty -Name LabName -Value $parts[10] -Force }
      
                if (($len -eq 15) -and ($parts[13] -eq 'Environments')) {
                    # it's a vm
                    if (Get-Member -inputobject $rs.properties -name "lastKnownPowerState" -Membertype Properties) {
                        $rs | Add-Member -MemberType NoteProperty -Name Status -Value $rs.properties.lastKnownPowerState -Force
                    }
                    else {
                        $rs | Add-Member -MemberType NoteProperty -Name Status -Value 'Unknown' -Force
                    }

                    if ($rs.properties.isClaimed -and $rs.properties.claimedByUserPrincipalId) {
                        $rs | Add-Member -MemberType NoteProperty -Name UserPrincipal -Value $rs.properties.claimedByUserPrincipalId -Force           
                    }
                    else {
                        $rs | Add-Member -MemberType NoteProperty -Name UserPrincipal -Value '' -Force           
                    }
                }
            }
            return $rs
        }
    }
    end { }
}

function New-AzLabAccount {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Resource Group to contain the lab account", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $ResourceGroupName,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of Lab Account to create")]
        [ValidateNotNullOrEmpty()]
        $LabAccountName
    )

    begin { . BeginPreamble }
    process {
        try {
            foreach ($rgName in $ResourceGroupName) {
                $rg = Get-AzureRmResourceGroup -name $rgName
                $subscriptionId = (Get-AzureRmContext).Subscription.Id
                $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourcegroups/$rgName/providers/microsoft.labservices/labaccounts/$LabAccountName"
                $body = @{
                    location = $rg.Location
                } | ConvertTo-Json -Depth 10
                InvokeRest -Uri $uri -Method "Put" -Body $body | Out-Null
                return WaitProvisioning -uri $uri -delaySec 60 -retryCount 120
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Remove-AzLabAccount {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to Remove.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccount
    )

    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = ConvertToUri -resource $la
                return InvokeRest -Uri $uri -Method 'Delete'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function New-AzLabAccountSharedGallery {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to Remove.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccount,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Azure resource for shared gallery.")]
        [ValidateNotNullOrEmpty()]
        $SharedGallery
    )

    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = ConvertToUri -resource $la
                $sharedGalleryName = $SharedGallery.Name

                # Bizarre. Using Get-AzLibrary returns an object with Id property, Get-AzResource one with ResourceId. This should work for both.
                if (Get-Member -inputobject $SharedGallery -name "ResourceId" -Membertype Properties) {
                    $sharedLibraryId = $SharedGallery.ResourceId
                } else {
                    $sharedLibraryId = $SharedGallery.Id
                }

                $fullUri = $uri + "/SharedGalleries/$sharedGalleryName"

                return InvokeRest -Uri $fullUri -Method 'Put' -Body (@{
                    properties = @{
                        galleryId = $sharedLibraryId
                    }
                } | ConvertTo-Json)
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Remove-AzLabAccountSharedGallery {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to Remove.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccount,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Azure resource for shared gallery.")]
        [ValidateNotNullOrEmpty()]
        $SharedGalleryName
    )

    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = ConvertToUri -resource $la

                $fullUri = $uri + "/SharedGalleries/$sharedGalleryName"

                InvokeRest -Uri $fullUri -Method 'Delete' | Out-Null
                return $la
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Get-AzLabAccount {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Resource Group Containing the lab account", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $ResourceGroupName = '*',

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true , HelpMessage = "Name of Lab Account to retrieve (your can use * and ?)")]
        [ValidateNotNullOrEmpty()]
        $LabAccountName = '*'
    )

    begin { . BeginPreamble }
    process {
        try {
            foreach ($rg in $ResourceGroupName) {

                if ($ResourceGroupName -and (-not $ResourceGroupName.Contains("*"))) {
                    # Proper RG
                    if ($LabAccountName -and (-not $LabAccountName.Contains("*"))) {
                        # Proper RG, Proper Name
                        # A get for a single resource returns 404 if it doesn't exist, so need to convert to empty array.
                        try {
                            $uri = (GetLabAccountUri -ResourceGroupName $ResourceGroupName) + "/$LabAccountName"
                            InvokeRest  -Uri $uri -Method 'Get'
                        } catch {
                            $StatusCode = $_.Exception.Response.StatusCode.value__
                            if($StatusCode -eq 404) {
                                return @()
                            } else {
                                Write-Error $_
                            }
                        }
                    }
                    else {
                        #Proper RG, wild name
                        $uri = GetLabAccountUri -ResourceGroupName $ResourceGroupName
                        InvokeRest  -Uri $uri -Method 'Get' | Where-Object { $_.name -like $LabAccountName }
                    }
                }
                else {
                    # Wild RG forces query by subscription
                    $subscriptionId = (Get-AzureRmContext).Subscription.Id
                    $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.LabServices/labaccounts"
                    InvokeRest  -Uri $uri -Method 'Get' | Where-Object { ($_.name -like $LabAccountName ) -and ($_.id.Split('/')[4] -like $ResourceGroupName) }
                }
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Get-AzLab {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to get labs from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccount,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of Lab to retrieve (your can use * and ?)")]
        [ValidateNotNullOrEmpty()]
        $LabName = '*'

    )

    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = (ConvertToUri -resource $la) + "/labs"
                InvokeRest -Uri $uri -Method 'Get' | Where-Object { $_.Name -like $LabName }
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

# TODO: should this be synchronous (aka wait for completion of deletion)?
function Remove-AzLab {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to get labs from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab 
    )
  
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $uri = ConvertToUri -resource $l
                return InvokeRest -Uri $uri -Method 'Delete'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}
  
function New-AzLab {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to create lab into", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccount,
  
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of Lab to create")]
        [ValidateNotNullOrEmpty()]
        $LabName,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Maximum number of users in lab (defaults to 5)")]
        [int]
        $MaxUsers = 5,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Quota of hours x users (defaults to 40)")]
        [int]
        $UsageQuotaInHours = 40,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Access mode for the lab (either Restricted or Open)")]
        [ValidateSet('Restricted', 'Open')]
        [string]
        $UserAccessMode = 'Restricted',

        [parameter(mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]
        $SharedPasswordEnabled = $false 
    )
  
    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = (ConvertToUri -resource $la) + "/labs/" + $LabName
                $sharedPassword = if ($SharedPasswordEnabled) { "Enabled" } else { "Disabled" }

                InvokeRest -Uri $uri -Method 'Put' -Body (@{
                        location   = $LabAccount.location
                        properties = @{
                            maxUsersInLab         = $MaxUsers.ToString()
                            usageQuota            = "PT$($UsageQuotaInHours.ToString())H"
                            userAccessMode        = $UserAccessMode
                            sharedPasswordEnabled = $sharedPassword
                        }
                    } | ConvertTo-Json) | Out-Null
                return WaitProvisioning -uri $uri -delaySec 60 -retryCount 120    
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Set-AzLab {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to set properties for.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Maximum number of users in lab.")]
        [int]
        $MaxUsers = 5,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Quota of hours x users.")]
        [int]
        $UsageQuotaInHours = 40,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Access mode for the lab (either Restricted or Open)")]
        [ValidateSet('Restricted', 'Open')]
        [string]
        $UserAccessMode = 'Restricted',

        [parameter(mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]
        $SharedPasswordEnabled = $false 
    )
  
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $ResourceGroupName = $l.id.split('/')[4]
                $LabAccountName = $l.id.split('/')[8]
                $LabName = $l.Name
                $LabAccount = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName

                $dateTime = ConvertFrom-ISO8601Duration -Duration $l.properties.usageQuota
                Write-Verbose($dateTime)

                $mu = if ($PSBoundParameters.ContainsKey('MaxUsers')) { $MaxUsers } else { $l.properties.maxUsersInLab }
                $uq = if ($PSBoundParameters.ContainsKey('UsageQuotaInHours')) { $UsageQuotaInHours } else { $dateTime.TotalHours }
                $ua = if ($PSBoundParameters.ContainsKey('UserAccessMode')) { $UserAccessMode } else { $l.properties.userAccessMode }
                $sp = if ($PSBoundParameters.ContainsKey('SharedPasswordEnabled')) {
                    $SharedPasswordEnabled
                }
                else {
                    if (Get-Member -inputobject $l.properties -name "sharedPasswordEnabled" -Membertype Properties) {
                        $l.properties.sharedPasswordEnabled -eq 'Enabled'
                    }
                    else {
                        $false
                    }
                }
           
                return New-AzLab -LabAccount $LabAccount -LabName $LabName -MaxUsers $mu -UsageQuotaInHours $uq -UserAccessMode $ua -SharedPasswordEnabled:$sp
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
} 

# We need this to refresh a lab, labs are not created in the user subscription, so can't just Get-AzResource on the id
function Get-AzLabAgain($lab) {
    $resourceGroupName = $lab.id.Split('/')[4]
    $labAccountName = $lab.id.Split('/')[8]
    $labName = $lab.id.Split('/')[10]
    $labAccount = Get-AzLabAccount -ResourceGroupName $resourceGroupName -LabAccountName $labAccountName
    return $labAccount | Get-AzLab -LabName $labName
}

function Get-AzLabTemplateVM {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to create template VM into", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    )

    $uri = (ConvertToUri -resource $lab) + '/EnvironmentSettings/Default'
    return InvokeRest -Uri $uri -Method 'Get'
}

function Get-AzLabVmAgain($vm) {
    $uri = ConvertToUri -resource $vm
    return InvokeRest -Uri $uri -Method 'Get'
}

function Get-AzLabTemplateVM {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to create template VM into", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    )

    $uri = (ConvertToUri -resource $lab) + '/EnvironmentSettings/Default'
    return InvokeRest -Uri $uri -Method 'Get'
}

function New-AzLabTemplateVM {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Scope = "Function")]
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to create template VM into", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,
  
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Shared Image or Gallery image to use")]
        [ValidateNotNullOrEmpty()]
        $Image,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Size for template VM")]
        [ValidateSet('Small', 'Medium', 'MediumNested', 'Large', 'GPU')]
        $Size,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Quota of hours x users (defaults to 40)")]
        [String]
        $Title = "A test title",

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Quota of hours x users (defaults to 40)")]
        [String]
        $Description = "Template Description",

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "User name if shared password is enabled")]
        [string]
        $UserName,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password if shared password is enabled")]
        [string]
        $Password,

        [parameter(mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]
        $LinuxRdpEnabled = $false  
    )
  
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {

                $sizesHash = @{
                    'Small'        = 'Basic'
                    'Medium'       = 'Standard'
                    'MediumNested' = 'Virtualization'
                    'Large'        = 'Performance'
                    'GPU'          = 'GPU'
                }
                $sizeJson = $sizesHash[$Size]

                $uri = (ConvertToUri -resource $l) + '/EnvironmentSettings/Default'

                $imageType = if ($image.id -match '/galleryimages/') { 'galleryImageResourceId' } else { 'sharedImageResourceId' }

                if ($LinuxRdpEnabled) { $linux = 'Enabled' } else { $linux = 'Disabled' }

                $body = @{
                    location   = $l.location
                    properties = @{
                        title            = $title
                        description      = $Description
                        resourceSettings = @{
                            $imageType  = $image.id
                            size        = $sizeJson
                            referenceVm = @{
                                userName = $UserName
                                password = $Password
                            }
                        }
                        LinuxRdpEnabled  = $linux
                    }
                }
                $jsonBody = $body | ConvertTo-Json -Depth 10
                Write-Verbose "BODY: $jsonBody"
                InvokeRest -Uri $uri -Method 'Put' -Body $jsonBody | Out-Null
                WaitProvisioning -uri $uri -delaySec 60 -retryCount 120 | Out-Null

                return Get-AzLabAgain -lab $l
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Publish-AzLab {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to create template VM into", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $uri = (ConvertToUri -resource $Lab) + '/EnvironmentSettings/Default'

                $publishUri = $uri + '/publish'
                $publishBody = @{useExistingImage = $false } | ConvertTo-Json
                InvokeRest -Uri $publishUri -Method 'Post' -Body $publishBody | Out-Null

                $uriProv = (ConvertToUri -resource $l) + '/EnvironmentSettings/Default'
                # As a simple scheme, we check every minute for 1.5 hours
                WaitPublishing -uri $uriProv -delaySec 60 -retryCount 90 -params '$expand=properties(%24expand%3DresourceSettings(%24expand%3DreferenceVm(%24expand%3DvmStateDetails)))' | Out-Null

                # We need this so that the lab UI shows the home page instead of the 'Done' button
                $t = $l | Get-AzLabTemplateVM
                $t.properties.configurationState = 'Completed'
                $completedBody = $t | ConvertTo-Json -Depth 20
                InvokeRest -Uri $uri -Method 'Put' -Body $completedBody | Out-Null

                return Get-AzLabAgain -lab $l
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Get-AzLabAccountSharedImage {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to get shared images from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccount 
    )
  
    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = (ConvertToUri -resource $la) + "/SharedImages"
                return InvokeRest -Uri $uri -Method 'Get' | Where-Object { $_.properties.EnableState -eq 'Enabled' }
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Get-AzLabAccountGalleryImage {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to get shared images from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccount 
    )
  
    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = (ConvertToUri -resource $la) + "/GalleryImages"
                InvokeRest -Uri $uri -Method 'Get' | Where-Object { $_.properties.isEnabled }
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Add-AzLabUser {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to add users to", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Users to add to the lab")]
        [string[]]
        $Emails

    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $uri = (ConvertToUri -resource $Lab) + '/addUsers'

                $body = @{emailAddresses = $Emails } | ConvertTo-Json
                InvokeRest -Uri $uri -Method 'Post' -Body $body | Out-Null

                return Get-AzLabAgain -lab $l
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Get-AzLabUser {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to get users from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Email to match users to (you can use '*', '?', etc...)")]
        [ValidateNotNullOrEmpty()]
        $Email = '*'       
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $uri = (ConvertToUri -resource $Lab) + '/users'

                return InvokeRest -Uri $uri -Method 'Get' | Where-Object { $_.properties.email -like $Email }
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Remove-AzLabUser {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to remove users from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Users to remove")]
        [ValidateNotNullOrEmpty()]
        $User
       
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                foreach ($u in $User) {
                    $userName = $u.name
                    $uri = (ConvertToUri -resource $Lab) + '/users/' + $userName

                    return InvokeRest -Uri $uri -Method 'Delete'
                }
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Register-AzLabUser {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to remove users from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "User to remove")]
        [ValidateNotNullOrEmpty()]
        $User
       
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $userName = $User.name
                $invitationCode = $lab.properties.invitationCode
                $body = @{registrationCode = $invitationCode } | ConvertTo-Json

                $uri = "https://management.azure.com/providers/Microsoft.LabServices/users/$userName/register"

                return InvokeRest -Uri $uri -Method 'Post' -Body $body
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Get-AzLabVm {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to get VMs from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "User this VM belongs to (you can use *,?, etc...)")]
        $ClaimByUser = $null,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "State of VM to retrieve")]
        [ValidateSet('Starting', 'Running', 'Stopping', 'Stopped', 'Failed', 'Restarting', 'ApplyingArtifacts', 'UpgradingVmAgent', 'Creating', 'Deleting', 'Corrupted', 'Unknown', 'Any')]
        $Status = 'Any'
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $uri = (ConvertToUri -resource $Lab) + '/environmentsettings/Default/environments'

                $vms = InvokeRest -Uri $uri -Method 'Get'
                if ($ClaimByUser) {
                    $vms = $vms `
                    | Where-Object { ($_.properties.isClaimed) -and ($_.properties.claimedByUserPrincipalId -eq $ClaimByUser.name) }
                }
                if ($Status -ne 'Any') {
                    $vms = $vms | Where-Object { $_.Status -eq $Status }  
                }
                return $vms
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Get-AzLabForVm {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Vm to get status for", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Vm

    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($v in $vm) {
                $ResourceGroupName = $v.id.split('/')[4]
                $LabAccountName = $v.id.split('/')[8]
                $LabName = $v.id.split('/')[10]
                $LabAccount = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName
                return $LabAccount | Get-AzLab -LabName $LabName       
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Start-AzLabVm {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Vm to start.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Vm

    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($v in $vm) {
                $baseUri = (ConvertToUri -resource $v)
                $uri = $baseUri + '/start'
                InvokeRest -Uri $uri -Method 'Post' | Out-Null
                return WaitStatusChange -uri $baseUri -delaySec 15 -retryCount 240 -status 'Running'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Stop-AzLabVm {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Vm to stop.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Vm

    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($v in $vm) {
                $baseUri = (ConvertToUri -resource $v)
                $uri = $baseUri + '/stop'
                InvokeRest -Uri $uri -Method 'Post' | Out-Null
                return WaitStatusChange -uri $baseUri -delaySec 15 -retryCount 240 -status 'Stopped'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Send-AzLabUserInvitationEmail {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to invite users to", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Users to invite")]
        [ValidateNotNullOrEmpty()]
        $User,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Text of invitation")]
        [ValidateNotNullOrEmpty()]
        $InvitationText = "You have been invited to an Azure Lab Services lab!"
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                foreach ($u in $User) {
                    $body = @{
                        emailAddresses = @($u.properties.email)
                        extraMessage   = $InvitationText
                    } | ConvertTo-Json

                    $uri = (ConvertToUri -resource $l) + '/sendEmail'

                    InvokeRest -Uri $uri -Method 'Post' -Body $body | Out-Null

                    # We could check the status of the email with $user.properties.registrationLinkEmail = 'sent'
                    # But why bother? As email is by its nature asynchronous ...
                    return Get-AzLabAgain -lab $l
                }
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Get-AzLabSchedule {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to get users from.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab      
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $uri = (ConvertToUri -resource $Lab) + '/environmentsettings/default/schedules'

                return InvokeRest -Uri $uri -Method 'Get'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Remove-AzLabSchedule {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Schedule to remove", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Schedule
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($s in $Schedule) {
                $uri = ConvertToUri -resource $s

                return InvokeRest -Uri $uri -Method 'Delete'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function New-AzLabSchedule {
    param(
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Lab to associate the schedule to.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Frequency of the class (either Weekly, Daily or Once).")]
        [ValidateSet('Once', 'Weekly', 'Daily')]
        [string] $Frequency = 'Weekly',

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Start Date for the class.")]
        [ValidateNotNullOrEmpty()]
        [string] $FromDate = (Get-Date).ToString(),

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "End Date for the class.")]
        [ValidateNotNullOrEmpty()]
        [string] $ToDate = (Get-Date).AddMonths(4).ToString(),

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "The time (relative to timeZoneId) at which the Lab VMs will be automatically started (E.g. 17:30, 20:00, 09:00).")]
        [ValidateLength(4, 5)]
        [string] $StartTime = "08:00",

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "The time (relative to timeZoneId) at which the Lab VMs will be automatically shutdown (E.g. 17:30, 20:00, 09:00).")]
        [ValidateLength(4, 5)]
        [string] $EndTime = "10:00",
    
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "The Windows time zone id associated with labVmStartup (E.g. UTC, Pacific Standard Time, Central Europe Standard Time).")]
        [ValidateLength(3, 40)]
        [string] $TimeZoneId = "W. Europe Standard Time",
    
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Days when to start the VM.")]
        [Array] $WeekDays = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'),

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Notes for the class meeting.")]
        $Notes = ""
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                # TODO: ask for algo to generate schedule names
                $name = 'Default_' + (Get-Random -Minimum 10000 -Maximum 99999)

                $uri = (ConvertToUri -resource $Lab) + "/environmentsettings/default/schedules/$name"

                $sdate = [datetime]::Parse($FromDate)
                $stime = [datetime]::Parse($StartTime)
                $startd = [datetime]::New($sdate.Year, $sdate.Month, $sdate.Day, $stime.Hour, $stime.Minute, 0)
                $fullStart = $startd.ToString('o')

          
                $etime = [datetime]::Parse($EndTime)
                $endd = [datetime]::New($sdate.Year, $sdate.Month, $sdate.Day, $etime.Hour, $etime.Minute, 0)
                $fullEnd = $endd.ToString('o')

                $edate = [datetime]::Parse($ToDate)
                $duntil = [datetime]::New($edate.Year, $edate.Month, $edate.Day, $stime.Hour, $stime.Minute, 0)
                $fullUntil = $duntil.ToString('o')

                if ($Frequency -eq 'Weekly') {
                    $body = @{
                        properties = @{
                            enableState       = 'Enabled'
                            start             = $fullStart
                            end               = $fullEnd
                            recurrencePattern = @{
                                frequency = $Frequency
                                weekDays  = $WeekDays
                                interval  = 1
                                until     = $fullUntil
                            }
                            timeZoneId        = $TimeZoneId

                            startAction       = @{
                                enableState = "Enabled"
                                actionType  = "Start"
                            }
                            endAction         = @{
                                enableState = "Enabled"
                                actionType  = "Stop"
                            }
                            notes             = $Notes
                        }
                    } | ConvertTo-Json -depth 10
                }
                else {
                    # TODO: Consider checking parameters more instead of just plucking the ones I need
                    $body = @{
                        properties = @{
                            enableState = 'Enabled'
                            start       = $fullStart
                            end         = $fullEnd
                            timeZoneId  = $TimeZoneId
                            startAction = @{
                                enableState = "Enabled"
                                actionType  = "Start"
                            }
                            endAction   = @{
                                enableState = "Enabled"
                                actionType  = "Stop"
                            }
                            notes       = $Notes
                        }
                    } | ConvertTo-Json -depth 10
                }

                Write-Verbose $body

                return InvokeRest -Uri $uri -Method 'Put' -Body $body
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

Export-ModuleMember -Function   Get-AzLabAccount,
                                Get-AzLab,
                                New-AzLab,
                                Get-AzLabAccountSharedImage,
                                Get-AzLabAccountGalleryImage,
                                Remove-AzLab,
                                New-AzLabTemplateVM,
                                Get-AzLabTemplateVM,
                                Publish-AzLab,
                                Add-AzLabUser,
                                Get-AzLabUser,
                                Remove-AzLabUser,
                                Get-AzLabVm,
                                Register-AzLabUser,
                                Send-AzLabUserInvitationEmail,
                                Set-AzLab,
                                Get-AzLabSchedule,
                                New-AzLabSchedule,
                                Remove-AzLabSchedule,
                                New-AzLabAccount,
                                Remove-AzLabAccount,
                                Start-AzLabVm,
                                Stop-AzLabVm,
                                Get-AzLabForVm,
                                New-AzLabAccountSharedGallery,
                                Remove-AzLabAccountSharedGallery