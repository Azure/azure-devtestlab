#region COMMON FUNCTIONS
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

$azureRm  = Get-Module -Name "AzureRM.Profile" -ListAvailable
$az       = Get-Module -Name "Az.Accounts" -ListAvailable
$justAz   = $az -and (-not $azureRm)

if($azureRm -and $az) {
  Write-Warning "You have both Az and AzureRm module installed. That is not officially supported. For more read here: https://docs.microsoft.com/en-us/powershell/azure/migrate-from-azurerm-to-az"
}

if($azureRm) {
  # This is not defaulted in older versions of AzureRM
  Enable-AzureRmContextAutosave -Scope CurrentUser -erroraction silentlycontinue
  Write-Warning "You are using the deprecated AzureRM module. For more info, read https://docs.microsoft.com/en-us/powershell/azure/migrate-from-azurerm-to-az"
}
if($justAz) {
  Enable-AzureRmAlias -Scope Local -Verbose:$false
}

# We want to track usage of library, so adding GUID to user-agent at loading and removig it at unloading
$libUserAgent = "pid-bd1d84d0-5ddb-4ab9-b951-393e656bb054"
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
# a scriptBlock and wrap it in the correct begig{} process {try{} catch{}} end {}
# but that ends up showing the source line of the error as such function, not the cmdlet.

# Import (with . syntax) this at the start of each begin block
function BeginPreamble {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Scope="Function")]
  param()
  Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
  $callerEA = $ErrorActionPreference
  $ErrorActionPreference = 'Stop'
}

#TODO: reduce function below to just get ErrorActionPreference
# Taken from https://gallery.technet.microsoft.com/scriptcenter/Inherit-Preference-82343b9d
function Get-CallerPreference
{
    [CmdletBinding(DefaultParameterSetName = 'AllVariables')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_.GetType().FullName -eq 'System.Management.Automation.PSScriptCmdlet' })]
        $Cmdlet,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(ParameterSetName = 'Filtered', ValueFromPipeline = $true)]
        [string[]]
        $Name
    )

    begin
    {
        $filterHash = @{}
    }

    process
    {
        if ($null -ne $Name)
        {
            foreach ($string in $Name)
            {
                $filterHash[$string] = $true
            }
        }
    }

    end
    {
        # List of preference variables taken from the about_Preference_Variables help file in PowerShell version 4.0

        $vars = @{
            'ErrorView' = $null
            'FormatEnumerationLimit' = $null
            'LogCommandHealthEvent' = $null
            'LogCommandLifecycleEvent' = $null
            'LogEngineHealthEvent' = $null
            'LogEngineLifecycleEvent' = $null
            'LogProviderHealthEvent' = $null
            'LogProviderLifecycleEvent' = $null
            'MaximumAliasCount' = $null
            'MaximumDriveCount' = $null
            'MaximumErrorCount' = $null
            'MaximumFunctionCount' = $null
            'MaximumHistoryCount' = $null
            'MaximumVariableCount' = $null
            'OFS' = $null
            'OutputEncoding' = $null
            'ProgressPreference' = $null
            'PSDefaultParameterValues' = $null
            'PSEmailServer' = $null
            'PSModuleAutoLoadingPreference' = $null
            'PSSessionApplicationName' = $null
            'PSSessionConfigurationName' = $null
            'PSSessionOption' = $null

            'ErrorActionPreference' = 'ErrorAction'
            'DebugPreference' = 'Debug'
            'ConfirmPreference' = 'Confirm'
            'WhatIfPreference' = 'WhatIf'
            'VerbosePreference' = 'Verbose'
            'WarningPreference' = 'WarningAction'
        }


        foreach ($entry in $vars.GetEnumerator())
        {
            if (([string]::IsNullOrEmpty($entry.Value) -or -not $Cmdlet.MyInvocation.BoundParameters.ContainsKey($entry.Value)) -and
                ($PSCmdlet.ParameterSetName -eq 'AllVariables' -or $filterHash.ContainsKey($entry.Name)))
            {
                $variable = $Cmdlet.SessionState.PSVariable.Get($entry.Key)

                if ($null -ne $variable)
                {
                    if ($SessionState -eq $ExecutionContext.SessionState)
                    {
                        Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                    }
                    else
                    {
                        $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                    }
                }
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'Filtered')
        {
            foreach ($varName in $filterHash.Keys)
            {
                if (-not $vars.ContainsKey($varName))
                {
                    $variable = $Cmdlet.SessionState.PSVariable.Get($varName)

                    if ($null -ne $variable)
                    {
                        if ($SessionState -eq $ExecutionContext.SessionState)
                        {
                            Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                        }
                        else
                        {
                            $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                        }
                    }
                }
            }
        }

    } # end

} # function Get-CallerPreference

function Get-AzureRmCachedAccessToken()
{
  $ErrorActionPreference = 'Stop'
  Set-StrictMode -Off

    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azureRmProfile.Accounts.Count) {
        Write-Error "Ensure you have logged in before calling this function."
    }

  $currentAzureContext = Get-AzureRmContext
  $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azureRmProfile)
  Write-Debug ("Getting access token for tenant" + $currentAzureContext.Subscription.TenantId)
  $token = $profileClient.AcquireAccessToken($currentAzureContext.Subscription.TenantId)
  $token.AccessToken
}

function GetHeaderWithAuthToken {

  $authToken = Get-AzureRmCachedAccessToken
  Write-Debug $authToken

  $header = @{
      'Content-Type' = 'application\json'
      "Authorization" = "Bearer " + $authToken
  }

  return $header
}

$ApiVersion = "?api-version=2018-10-15"

function GetLabAccountUri($ResourceGroupName) {
    $subscriptionId = (Get-AzureRmContext).Subscription.Id
    "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.LabServices/labaccounts"
}

function ConvertToUri($resource) {
    "https://management.azure.com" + $resource.Id
}

function InvokeRest($Uri, $Method) {
    $authHeaders = GetHeaderWithAuthToken
    $fullUri = $Uri + $ApiVersion
    Write-Verbose "$Method : $fullUri"
    $result = Invoke-WebRequest -Headers $authHeaders -Uri $FullUri -Method $Method
    $result.Content | ConvertFrom-Json
}

function Get-AzLabAccount {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$false,HelpMessage="Resource Group Containing the lab account", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $ResourceGroupName = '*',

    [parameter(Mandatory=$false,HelpMessage="Name of Lab Account to retrieve (your can use * and ?)")]
    [ValidateNotNullOrEmpty()]
    $LabAccountName = '*'

  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($rg in $ResourceGroupName) {
        $ResourceType = 'Microsoft.LabServices/labAccounts'

        if($ResourceGroupName -and (-not $ResourceGroupName.Contains("*"))) { # Proper RG
          if($LabAccountName -and (-not $LabAccountName.Contains("*"))) { # Proper RG, Proper Name
            Get-AzureRmResource -ExpandProperties -ResourceType $ResourceType -ResourceGroupName $ResourceGroupName -Name $LabAccountName -EA SilentlyContinue
          } else { #Proper RG, wild name
            Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -ResourceGroupName $ResourceGroupName -EA SilentlyContinue `
                | Where-Object { $_.Name -like $LabAccountName}
        }
        } else { # Wild RG forces query by subscription
            Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -EA SilentlyContinue `
                | Where-Object { ($_.ResourceGroupName -like $ResourceGroupName) -and ($_.Name -like $LabAccountName)}
        }
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Get-AzLab {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="Lab Account to get labs from", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $LabAccount,

    [parameter(Mandatory=$false,HelpMessage="Name of Lab to retrieve (your can use * and ?)")]
    [ValidateNotNullOrEmpty()]
    $LabName = '*'

  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($la in $LabAccount) {
        $ResourceType = 'Microsoft.LabServices/labAccounts/labs'
        $ResourceGroupName = $LabAccount.ResourceGroupName
        Get-AzureRmResource -ExpandProperties -ResourceType $ResourceType -ResourceGroupName $ResourceGroupName -EA SilentlyContinue `
            | Where-Object {$_.Name -like $LabName}
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}