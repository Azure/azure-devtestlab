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

    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)

    $currentAzureContext = Get-AzureRmContext

    if ($currentAzureContext) {
        $tenantId = $currentAzureContext.Subscription.TenantId
    }
    else {
        # There are cases where we don't have the context, like running in Azure Automation
        # Fallback is to pull the tenant ID out of the AzureRmProfile if it's there
        $tenantId = $azureRmProfile.DefaultContext.Tenant.Id
    }

    Write-Debug ("Getting access token for tenant" + $tenantId)
    $token = $profileClient.AcquireAccessToken($tenantId)
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
    #Variables for retry logic
    $maxCallCount = 3 #Max number of calls to attempt
    $retryIntervalInSeconds = 5 
    $shouldRetry = $false
    $currentCallCount = 0

    $authHeaders = GetHeaderWithAuthToken

    $fullUri = $Uri + '?' + $ApiVersion
    
    if ($params) { $fullUri += '&' + $params }

    if ($body) { Write-Verbose $body }

    do{
        try{
            $currentCallCount += 1
            $shouldRetry = $false
            $result = Invoke-WebRequest -Uri $FullUri -Method $Method -Headers $authHeaders -Body $Body -UseBasicParsing 
        }catch{
            #if we have reach max number of calls, rethrow error no matter what it is
            if($currentCallCount -eq $maxCallCount){
                throw
            }

            #retry if Rest method is GET
            if ($Method -eq 'Get'){
                $shouldRetry = $true
            }

            $StatusCode = $null
            if ($_.PSObject.Properties.Item('Exception') -and `
                $_.Exception.PSObject.Properties.Item('Response') -and `
                $_.Exception.Response.PSObject.Properties.Item('StatusCode') -and `
                $_.Exception.Response.StatusCode.PSObject.Properties.Item('value__')){
                $StatusCode = $_.Exception.Response.StatusCode.value__
            }
            Write-Verbose "Response status code for '$Uri' is '$StatusCode'"
            switch($StatusCode){
                401 { $shouldRetry = $false } #Don't retry on Unauthorized error, regardless of what kind of call
                404 { $shouldRetry = $false } #Don't retry on NotFound error, even if it is a GET call
                503 { $shouldRetry = $true} #Always safe to retry on ServerUnavailable
            }

            if ($shouldRetry){
                 #Sleep before retrying call
                Write-Verbose "Retrying after interval of $retryIntervalInSeconds seconds. Status code for previous attempt: $StatusCode"
                Start-Sleep -Seconds $retryIntervalInSeconds
            }else{
                #propogate error if not retrying
                throw
            }
        }
    }while($shouldRetry -and ($currentCallCount -lt $maxCallCount))
    $resObj = $result.Content | ConvertFrom-Json
    
    # Happens with Post commands ...
    if (-not $resObj) { return $resObj }

    Write-Verbose "ResObj: $resObj"

    # Need to make it unique because the rest call returns duplicate ones (bug)
    if (Get-Member -inputobject $resObj -name "Value" -Membertype Properties) {
        return $resObj.Value | Sort-Object -Property id -Unique | Enrich
    }
    else {
        return $resObj | Sort-Object -Property id -Unique | Enrich
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

function WaitDeleting($uri, $delaySec, $retryCount) {
    Write-Verbose "Retrying $retryCount times every $delaySec seconds."
    try {
        $tries = 0;
        $res = InvokeRest -Uri $uri -Method 'Get'
        if ($res.PSObject.Properties.Item('properties') -and `
            $res.properties.PSObject.Properties.Item('provisioningState')) {
            while ($res.properties.provisioningState -eq 'Deleting') {
                Write-Verbose "$tries : ProvisioningState = $($res.properties.provisioningState)"
                if ($tries -ge $retryCount) {
                    throw ("$retryCount retries of retrieving $uri with ProvisioningState = Deleting has either failed or is taking longer than the timeout.")
                }
                Start-Sleep -Seconds $delaySec
                $res = InvokeRest -Uri $uri -Method 'Get'
                $tries += 1
            }
        } else {
            throw ("Result missing provisioning state.")
        }
    } catch {
        $StatusCode = $null
        if ($_.PSObject.Properties.Item('Exception') -and `
                $_.Exception.PSObject.Properties.Item('Response') -and `
                $_.Exception.Response.PSObject.Properties.Item('StatusCode') -and `
                $_.Exception.Response.StatusCode.PSObject.Properties.Item('value__')){
                $StatusCode = $_.Exception.Response.StatusCode.value__
        } else {
            $StatusCode = 408
        }
        
        if($StatusCode -eq 404) {
            return @()
        } else {
            throw
        }
    }
    
    return @()
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
function WaitTemplateStatusChange($uri, $delaySec, $retryCount, $params, $status) {
    Write-Verbose "Retrying $retryCount times every $delaySec seconds."

    $tries = 0;
    $res = InvokeRest -Uri $uri -Method 'Get' -params $params

    while (-not ($res.properties.latestOperationResult.status -eq $status)) {
        Write-Verbose "$tries : Status = $($res.properties.latestOperationResult.status)"
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
            if ($rs.PSobject.Properties.name -match "id") {
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
                Write-Verbose "Creating Lab Account $LabAccountName REST call."
                $lab = InvokeRest -Uri $uri -Method "Put" -Body $body
                WaitProvisioning -uri $uri -delaySec 60 -retryCount 120 | Out-Null
                return $lab
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

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Azure resource for shared gallery.")]
        [ValidateNotNullOrEmpty()]
        $SharedGallery,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Shared gallery resource id.")]
        [ValidateNotNullOrEmpty()]
        [string]$SharedGalleryId
    )

    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = ConvertToUri -resource $la

                if ($SharedGallery){

                    $sharedGalleryName = $SharedGallery.Name

                    # Bizarre. Using Get-AzLibrary returns an object with Id property, Get-AzResource one with ResourceId. This should work for both.
                    if (Get-Member -inputobject $SharedGallery -name "ResourceId" -Membertype Properties) {
                        $sharedLibraryId = $SharedGallery.ResourceId
                    } else {
                        $sharedLibraryId = $SharedGallery.Id
                    }
                }
                elseif ($SharedGalleryId) {
                    # /subscriptions/ebfb37db-8168-4a51-aa4d-4e5e2efa4f54/resourceGroups/MSPTestRG/providers/Microsoft.Compute/galleries/TestSharedGallery
                    $sharedGalleryName = $SharedGalleryId.split('/')[8]
                    $sharedLibraryId = $SharedGalleryId
                }
                else {
                    Write-Error "Must pass in either SharedGallery or SharedGalleryId to New-AzlabAccountSharedGallery commandlet"
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
                            $StatusCode = $null
                            if ($_.PSObject.Properties.Item('Exception') -and `
                                $_.Exception.PSObject.Properties.Item('Response') -and `
                                $_.Exception.Response.PSObject.Properties.Item('StatusCode') -and `
                                $_.Exception.Response.StatusCode.PSObject.Properties.Item('value__')){
                                $StatusCode = $_.Exception.Response.StatusCode.value__
                            }
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
        $Lab,

        [parameter(mandatory = $false, HelpMessage = "Wait for Deletion to complete before continuing.", ValueFromPipelineByPropertyName = $true)]
        [bool]
        $EnableWaitForDelete = $true
    )
  
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $uri = ConvertToUri -resource $l
                InvokeRest -Uri $uri -Method 'Delete'
                if ($EnableWaitForDelete) {
                    WaitDeleting -uri $uri -delaySec 60 -retryCount 60
                }
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

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Shared Image or Gallery image to use")]
        [ValidateNotNullOrEmpty()]
        $Image,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Size for template VM")]
        [ValidateNotNullOrEmpty()]
        $Size,
            
        [parameter(mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]
        $GpuDriverEnabled = $false,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "User name if shared password is enabled")]
        [string]
        $UserName,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password if shared password is enabled")]
        [string]
        $Password,

        [parameter(mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]
        $LinuxRdp = $false,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Quota of hours x users (defaults to 40)")]
        [int]
        $UsageQuotaInHours = 40,

        [parameter(mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]
        $SharedPasswordEnabled = $false,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Idle Shutdown Grace Period (0 is off)")]
        [int]
        $idleGracePeriod = 15,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Disconnect on Idle Grace Period (0 is off)")]
        [int]
        $idleOsGracePeriod = 0,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Shutdown on No Connect Grace Period (0 is off)")]
        [int]
        $idleNoConnectGracePeriod = 15,
        
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Enabled AAD connected labs.  NOTE:  If this Id is a teams team than the lab will be marked as a teams lab.")]
        [string] $AadGroupId,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Should this lab contain a Template VM?  Enabled = Yes, and Disabled = No")]
        [ValidateSet('Enabled', 'Disabled')]
        [string] $TemplateVmState = "Enabled"

    )
  
    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $labAccountUri = (ConvertToUri -resource $la)
                $createUri = $labAccountUri + "/createLab"
                $labUri = $labAccountUri + "/labs/" + $LabName
                $environmentSettingUri = $labUri + "/environmentsettings/default"
                $sharedPassword = if ($SharedPasswordEnabled) { "Enabled" } else { "Disabled" }
                $imageType = if ($image.id -match '/galleryimages/') { 'galleryImageResourceId' } else { 'sharedImageResourceId' }
                if ($LinuxRdp) {$linuxRdpState = 'Enabled'} else { $linuxRdpState = 'Disabled' }
                if ($GpuDriverEnabled) {$gpuDriverState = 'Enabled'} else { $gpuDriverState = 'Disabled' }
                if ($idleGracePeriod -eq 0) {$idleShutdownMode = "None"} else {$idleShutdownMode = "OnDisconnect"}
                if ($idleOsGracePeriod -eq 0) {$enableDisconnectOnIdle = "Disabled"} else {$enableDisconnectOnIdle = "Enabled"}
                if ($idleNoConnectGracePeriod -eq 0) {$enableNoConnectShutdown = "Disabled"} else {$enableNoConnectShutdown = "Enabled"}

                if ($LinuxRdp) {
                InvokeRest -Uri $createUri -Method 'Post' -Body (@{
                        name = $LabName
                        labParameters = @{
                            $imageType = $image.id
                            linuxRdpState = $linuxRdpState
                            password = $Password
                            username = $UserName
                            userQuota = "PT$($UsageQuotaInHours.ToString())H"
                            vmSize = $Size
                            sharedPasswordState = $sharedPassword
                            templateVmState = $TemplateVmState
                            installGpuDriverEnabled = $gpuDriverState
                            aadGroupId = $AadGroupId
                        }
                    } | ConvertTo-Json) | Out-Null
                } else {

                    InvokeRest -Uri $createUri -Method 'Post' -Body (@{
                        name = $LabName
                        labParameters = @{
                            $imageType = $image.id
                            linuxRdpState = $linuxRdpState
                            password = $Password
                            username = $UserName
                            userQuota = "PT$($UsageQuotaInHours.ToString())H"
                            vmSize = $Size
                            sharedPasswordState = $sharedPassword
                            templateVmState = $TemplateVmState
                            idleShutdownMode = $idleShutdownMode
                            idleGracePeriod = "PT$($idleGracePeriod.ToString())M"
                            enableDisconnectOnIdle = $enableDisconnectOnIdle
                            idleOsGracePeriod = "PT$($idleOsGracePeriod.ToString())M"
                            enableNoConnectShutdown = $enableNoConnectShutdown
                            idleNoConnectGracePeriod = "PT$($idleNoConnectGracePeriod.ToString())M"
                            installGpuDriverEnabled = $gpuDriverState
                            aadGroupId = $AadGroupId
                        }
                    } | ConvertTo-Json) | Out-Null
                }

                #Wait for lab to be created.
                $lab = WaitProvisioning -uri $labUri -delaySec 60 -retryCount 120
                #Wait for template to be provisioned.  Even labs without a template will return a environmentsetting object.
                $defaultEnvironmentSetting = WaitProvisioning -uri $environmentSettingUri -delaySec 60 -retryCount 120
                
                if ($GpuDriverEnabled) {

                    # The template VM needs to be restarted for the GPU drivers to finish installing properly
                    # This will eventually be done within the product, but for now, we need to do this explicitly
                    Write-Verbose "Start template VM after installing GPU drivers"
                    Get-AzLabTemplateVm $lab | Start-AzLabTemplateVm
                    Get-AzLabTemplateVm $lab | Stop-AzLabTemplateVm
                    Write-Verbose "Stopped template VM"
                }

                return $lab
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
        [string]
        $MaxUsers,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Access mode for the lab (either Restricted or Open)")]
        [ValidateSet('Restricted', 'Open')]
        [string]
        $UserAccessMode,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Enabled', 'Disabled')]
        [string]
        $SharedPasswordEnabled,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Quota of hours x users (defaults to 40)")]
        [string]
        $UsageQuotaInHours,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Set the AAD Group for the lab.")]
        [string]
        $AADGroupIdForLab
    )
  
    begin { . BeginPreamble }
    process {
        try {

            foreach ($l in $Lab) {
                $ResourceGroupName = $l.id.split('/')[4]
                $LabAccountName = $l.id.split('/')[8]
                $LabName = $l.Name
                $LabAccount = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName
                $CurrentLab = Get-AzLab -LabAccount $LabAccount -LabName $LabName

                Write-Verbose "Lab to update:\n$($lab | ConvertTo-Json)"
                if ($MaxUsers -gt 0) {
                        $CurrentLab.properties | Add-Member -MemberType NoteProperty -Name maxUsersInLab -Value $MaxUsers -force
                }
                if ($UserAccessMode) {
                    $CurrentLab.properties | Add-Member -MemberType NoteProperty -Name userAccessMode -Value $UserAccessMode  -force
                }
                #
                if ($SharedPasswordEnabled) {
                    $CurrentLab.properties | Add-Member -MemberType NoteProperty -Name sharedPasswordEnabled -Value $SharedPasswordEnabled  -force
                }
                if ($UsageQuotaInHours) {
                    $CurrentLab.properties | Add-Member -MemberType NoteProperty -Name usageQuota -Value "PT$($UsageQuotaInHours)H" -force
                }
                if ($AADGroupIdForLab) {
                    $CurrentLab.properties | Add-Member -MemberType NoteProperty -Name aadGroupId -Value $AADGroupIdForLab -force
                }
                # update lab
                $uri = (ConvertToUri -resource $LabAccount) + "/labs/" + $LabName

                $lab = InvokeRest -Uri $uri -Method 'PUT' -Body ($CurrentLab | ConvertTo-Json)
                return WaitProvisioning -uri $uri -delaySec 60 -retryCount 120
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

function Stop-AzLabTemplateVm {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Template Vm to stop.", ValueFromPipeline = $true)]
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
                return WaitTemplateStatusChange -uri $baseUri -delaySec 15 -retryCount 240 -status 'Succeeded'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}
function Start-AzLabTemplateVm {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Template Vm to stop.", ValueFromPipeline = $true)]
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
                return WaitTemplateStatusChange -uri $baseUri -delaySec 15 -retryCount 240 -status 'Succeeded'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}


function Get-AzLabVmAgain($vm) {
    $uri = ConvertToUri -resource $vm
    return InvokeRest -Uri $uri -Method 'Get'
}


function Get-AzLabTemplateVm {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to get Template VM from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    )

    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $uri = (ConvertToUri -resource $l) + '/EnvironmentSettings/Default'
                InvokeRest -Uri $uri -Method 'Get'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Set-AzLabTemplateVM {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "The Template VM to update.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $TemplateVm,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Quota of hours x users (defaults to 40)")]
        [String]
        $Title,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Quota of hours x users (defaults to 40)")]
        [String]
        $Description
    )
  
    begin { . BeginPreamble }
    process {
        try {
            foreach ($t in $TemplateVm) {
                $uri = (ConvertToUri -resource $t)

                if($PSBoundParameters.ContainsKey('Title')) {
                    $t.properties | Add-Member -MemberType NoteProperty -Name "title" -Value $Title -Force
                }

                if($PSBoundParameters.ContainsKey('Description')) {
                    $t.properties | Add-Member -MemberType NoteProperty -Name "description" -Value $Description -Force
                }

                $body = @{
                    location   = $t.location
                    properties = $t.properties
                }
                $jsonBody = $body | ConvertTo-Json -Depth 10
                Write-Verbose "BODY: $jsonBody"
                $lab = InvokeRest -Uri $uri -Method 'PUT' -Body $jsonBody
                WaitProvisioning -uri $uri -delaySec 60 -retryCount 120 | Out-Null
                return $lab
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
                $uri = (ConvertToUri -resource $Lab) + '/environmentsettings/default'

                $publishUri = $uri + '/publish'
                $publishBody = @{useExistingImage = $false } | ConvertTo-Json
                InvokeRest -Uri $publishUri -Method 'Post' -Body $publishBody | Out-Null

                $uriProv = (ConvertToUri -resource $l) + '/EnvironmentSettings/Default'
                # As a simple scheme, we check every minute for 1.5 hours
                WaitPublishing -uri $uriProv -delaySec 120 -retryCount 120 -params '$expand=properties(%24expand%3DresourceSettings(%24expand%3DreferenceVm(%24expand%3DvmStateDetails)))' | Out-Null

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

function Get-AzLabAccountSharedGallery {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to get attached Shared Gallery.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccount
    )

    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = (ConvertToUri -resource $la) + "/SharedGalleries/" 
                return InvokeRest -Uri $uri -Method 'Get'
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
        $LabAccount,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Are the images enabled?  Enabled = Yes, and Disabled = No")]
        [ValidateSet('Enabled', 'Disabled', 'All')]
        [string] $EnableState = "Enabled"
    )
  
    begin { . BeginPreamble }
    process {
        try {
            
            foreach ($la in $LabAccount) {
                $uri = (ConvertToUri -resource $la) + "/SharedImages"

                if ($EnableState -eq "All") {
                    $response = InvokeRest -Uri $uri -Method 'Get'
                }
                else {
                    $response = InvokeRest -Uri $uri -Method 'Get' | Where-Object { $_.properties.EnableState -eq $EnableState }
                }
                
                return $response
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Set-AzLabAccountSharedImage {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Shared image to update.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $SharedImage,

        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Should this image be enabled?  Enabled = Yes, and Disabled = No")]
        [ValidateSet('Enabled', 'Disabled')]
        [string] $EnableState = "Enabled"
    )
  
    begin { . BeginPreamble }
    process {
        try {

            foreach ($image in $SharedImage) {
                $ResourceGroupName = $image.id.split('/')[4]
                $LabAccountName = $image.id.split('/')[8]
                $LabAccount = Get-AzLabAccount -ResourceGroupName $ResourceGroupName -LabAccountName $LabAccountName

                Write-Verbose "Image to update:\n$($image | ConvertTo-Json)"

                $body = @{
                    id = $image.id
                    name = $image.name
                    properties =
                    @{
                        EnableState = $EnableState
                        sharedGalleryId = $image.properties.sharedGalleryId
                        osType = $image.properties.osType
                        imageType = $image.properties.imageType
                        displayName = $image.properties.displayName
                        definitionName = $image.properties.definitionName
                    }
                } | ConvertTo-Json

                $uri = (ConvertToUri -resource $LabAccount) + "/SharedImages/"+ $image.name

                $updatedImage = InvokeRest -Uri $uri -Method 'PUT' -Body ($body)
                Write-Verbose "Updated image\n$($updatedImage | ConvertTo-Json)"
                return WaitProvisioning -uri $uri -delaySec 60 -retryCount 120
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

function Set-AzLabUser {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to remove users from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Users to update")]
        [ValidateNotNullOrEmpty()]
        $User,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Setting the additional quota for a user in hours")]
        [ValidateNotNullOrEmpty()]
        $AdditionalUsageQuota
       
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                foreach ($u in $User) {
                    $userName = $u.name
                    $uri = (ConvertToUri -resource $Lab) + '/users/' + $userName
                    $body = @{"properties" = @{additionalUsageQuota = "PT$($AdditionalUsageQuota.ToString())H"}} | ConvertTo-Json

                    return InvokeRest -Uri $uri -Method 'Put' -Body $body
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

function Sync-AzLabADUsers {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab to sync users.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($l in $Lab) {
                $uri = (ConvertToUri -resource $Lab) + '/syncUserList'
                $body = $null
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
# Decided on a separate function instead of adding a switch to Get-AzLabStudentVm as the concept of Status doesn't make sense.
# It would create a situation when you could pass Status=Stopped and -Current at the same time.
function Get-AzLabStudentCurrentVm {
    [CmdletBinding()]
    param()
    try {
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        if($PSVersionTable.PSEdition -eq "Core" -and $IsMacOS) {
            Write-Error "Not supported on MAC"
            Exit
        }

        if($PSVersionTable.PSEdition -eq "Core" -and $IsLinux) {
            $ipAddresses = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Select-Object -ExpandProperty Addresses | Select-Object -ExpandProperty IpAddressToString 
        } else {
            $ipAddresses = Get-NetIPAddress | Select-Object -ExpandProperty IpAddress
        }
        Write-Verbose "Ip address(es) for the current machines: $($ipAddresses -join ', ')"

        $studentLabVms = Get-AzLabStudentVm
        $studentLabVms = $studentLabVms | Where-Object { $ipAddresses.Contains($_.virtualMachineDetails.privateIpAddress) }
        Write-Verbose "Found lab virtual machines that also match local ip address for classes: $($($studentLabVms | Select-Object -ExpandProperty name) -join ', ')"

        try{
            #Using Azure Compute Metadata service.  Using the tagsList property on the compute metadata to find the lab name
            $tags = Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/instance/compute/tagsList?api-version=2019-11-01' -Headers @{"Metadata"="true"} -TimeoutSec 5 
            $labName = $tags | Where-Object name -eq 'LabName' | Select-Object -expand value
            if ($labName){
                Write-Verbose "Found lab name for current machine: $labName"
                $studentLabVms = $studentLabVms | Where-Object {$_.Name -eq $labName}
                Write-Verbose "Found lab virtual machines that also match lab name: $($($studentLabVms | Select-Object -ExpandProperty name) -join ', ')"
            }else{
                Write-Verbose "Unable to find lab name for current virtual machine."
            }
        }catch{
            Write-Verbose "Unable to gather virtual machine metadata to determine lab name for virtual machine. "
        }

        return $studentLabVms
    }
    catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
    } finally {
        $ErrorActionPreference = $callerEA
    }
}
function InvokeStudentRest {
    param([parameter()]$uri, [parameter()]$body = "")

    $currentAzureContext = Get-AzureRmContext
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient([Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId).AccessToken
    if ($null -eq $token)
    {
        Write-Error "Unable to get authorization information."
    }
    $headers = @{
        'Authorization' = "Bearer $token"
    }

    $fullUri = "$($uri)?$ApiVersion"
    Write-debug $token
    Write-Verbose $fullUri
    Write-Verbose $body
    return Invoke-RestMethod -Uri $fullUri -Method 'Post' -Headers $headers -Body $body -ContentType 'application/json'
}
function Get-AzLabStudentVm {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "State of VM to retrieve")]
        [ValidateSet('Starting', 'Running', 'Stopping', 'Stopped', 'Failed', 'Restarting', 'ApplyingArtifacts', 'UpgradingVmAgent', 'Creating', 'Deleting', 'Corrupted', 'Unknown', 'Any')]
        $Status = 'Any'
    )

    # Cannot use the standard preamble and other utility functions in the library as certain variables are not present
    # when connecting as a student (i.e. $PSCmdlet). I have not investigated the reasons deeply. Even AcquireAccessToken works differently.
    # It must have something to do with different azure context types, but life is too short to figure all of that out.
    # Instead replacing the preamble with just caching the errorAction and avoid using standard library APIs.
    # Deeper thoughts could be spent in figuring out if we need separate APIs for students vs administrators.
    try {
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $uri = "https://management.azure.com/providers/Microsoft.LabServices/users/NoUsername/listAllEnvironments"
        $vms = InvokeStudentRest -uri $uri

        if($vms -and (Get-Member -inputobject $vms -name "environments" -Membertype Properties)) {
            $envs = $vms.environments
            if ($Status -ne 'Any') {
                $envs = $envs | Where-Object { $_.lastKnownPowerState -eq $Status }  
            }
            return $envs
        } else {
            return @()
        }
    }
    catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
    } finally {
        $ErrorActionPreference = $callerEA
    }
}
function Stop-AzLabStudentVm {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Vm to stop", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $studentVm
    )
    try {
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $uri = "https://management.azure.com/providers/Microsoft.LabServices/users/NoUsername/StopEnvironment"
        $body = @{
            'environmentId' = $studentVm.id
        } | ConvertTo-Json

        InvokeStudentRest -uri $uri -body $body
    }
    catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
    } finally {
        $ErrorActionPreference = $callerEA
    }

}
function Start-AzLabStudentVm {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Vm to start", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $studentVm
    )
    try {
        $callerEA = $ErrorActionPreference
        $ErrorActionPreference = 'Stop'

        $uri = "https://management.azure.com/providers/Microsoft.LabServices/users/NoUsername/StartEnvironment"
        $body = @{
            'environmentId' = $studentVm.id
        } | ConvertTo-Json

        InvokeStudentRest -uri $uri -body $body
    }
    catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
    } finally {
        $ErrorActionPreference = $callerEA
    }

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
    
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "The Windows time zone id associated with labVmStartup (E.g. UTC, Pacific Standard Time, Central Europe Standard Time).  See Time zones are https://docs.microsoft.com/rest/api/maps/timezone/get-timezone-enum-windows.")]
        [ValidateLength(3, 40)]
        [string] $TimeZoneId = "W. Europe Standard Time",
    
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Days when to start the VM when using a weekly schedule.")]
        [Array] $WeekDays = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'),

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Notes for the class meeting.")]
        $Notes = "",

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Event type.")]
        [ValidateSet("Standard", "Stop")]
        [string] $EventType = "Standard"
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
                $duntil = [datetime]::New($edate.Year, $edate.Month, $edate.Day, 23, 59, 59)
                $fullUntil = $duntil.ToString('o')

                if ($EventType -eq "Stop") {
                    $startEnabledState = "Disabled"
                    $endEnabledState = "Enabled"
                }
                else {
                    $startEnabledState = "Enabled"
                    $endEnabledState = "Enabled"
                }
              
                #'Daily' schedule is actually a 'Weekly' schedule repeated everyday of the week.
                if ($Frequency -eq 'Daily'){
                    $Frequency = 'Weekly'
                    $WeekDays = @('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')
                }

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
                                enableState = $startEnabledState
                                actionType  = "Start"
                            }
                            endAction         = @{
                                enableState = $endEnabledState
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
                                enableState = $startEnabledState
                                actionType  = "Start"
                            }
                            endAction   = @{
                                enableState = $endEnabledState
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

function Get-AzLabAccountPricingAndAvailability {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Lab Account to get shared images from", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccount 
    )
    begin { . BeginPreamble }
    process {
        try {
            foreach ($la in $LabAccount) {
                $uri = (ConvertToUri -resource $la) + "/GetPricingAndAvailability"

                return InvokeRest -Uri $uri -Method 'POST'
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}

function Convert-UsageQuotaToHours {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $RawTimeSpan
    )

    $usage = [System.Xml.XmlConvert]::ToTimeSpan($RawTimeSpan)
    return [math]::Ceiling($usage.TotalHours)
}


Export-ModuleMember -Function   Get-AzLabAccount,
                                Get-AzLab,
                                New-AzLab,
                                Get-AzLabAccountSharedImage,
                                Set-AzLabAccountSharedImage,
                                Get-AzLabAccountGalleryImage,
                                Remove-AzLab,
                                Get-AzLabTemplateVM,
                                Set-AzLabTemplateVM,
                                Publish-AzLab,
                                Add-AzLabUser,
                                Set-AzLabUser,
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
                                Remove-AzLabAccountSharedGallery,
                                Get-AzLabAccountSharedGallery,
                                Get-AzLabAccountPricingAndAvailability,
                                Stop-AzLabTemplateVm,
                                Start-AzLabTemplateVm,
                                Get-AzLabStudentVm,
                                Get-AzLabStudentCurrentVm,
                                Stop-AzLabStudentVm,
                                Start-AzLabStudentVm,
                                Sync-AzLabADUsers,
                                Convert-UsageQuotaToHours
