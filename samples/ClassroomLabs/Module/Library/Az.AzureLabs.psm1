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

$ApiVersion = "api-version=2019-01-01-preview"

function GetLabAccountUri($ResourceGroupName) {
    $subscriptionId = (Get-AzureRmContext).Subscription.Id
    "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.LabServices/labaccounts"
}

function ConvertToUri($resource) {
    "https://management.azure.com" + $resource.Id
}

function InvokeRest($Uri, $Method, $Body, $params) {
    $authHeaders = GetHeaderWithAuthToken
    $fullUri = $Uri + '?' + $ApiVersion
    if($params) { $fullUri += '&' + $params }
    
    Write-Verbose "$Method : $fullUri"
    $result = Invoke-WebRequest -Uri $FullUri -Method $Method -Headers $authHeaders -Body $Body -SkipHeaderValidation
    $result.Content | ConvertFrom-Json
}

# The WaitXXX functions differ just for the property and value tested.
# We could use just one parametrized function instead,but left two for name clarity
# and to leave open option of having differing algos later on. Or maybe I am just lazy.
function WaitPublishing($uri, $delaySec, $retryCount, $params) {
    Write-Verbose "Retrying $retryCount times every $delaySec seconds."

    $tries = 0;
    $res = InvokeRest -Uri $uri -Method 'Get' -params $params

    while(-not ($res.properties.publishingState -eq 'Published')) {
        Write-Verbose "$tries : PublishingState = $($res.properties.publishingState)"
        if(-not ($tries -lt $retryCount)) {
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

    while(-not ($res.properties.provisioningState -eq 'Succeeded')) {
        Write-Verbose "$tries : ProvisioningState = $($res.properties.provisioningState)"
        if(-not ($tries -lt $retryCount)) {
            throw ("$retryCount retries of retrieving $uri with ProvisioningState = Succeeded failed")
        }
        Start-Sleep -Seconds $delaySec
        $res = InvokeRest -Uri $uri -Method 'Get' -params $params
        $tries += 1
    }
    return $res
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

        if($ResourceGroupName -and (-not $ResourceGroupName.Contains("*"))) { # Proper RG
          if($LabAccountName -and (-not $LabAccountName.Contains("*"))) { # Proper RG, Proper Name
            $uri = (GetLabAccountUri -ResourceGroupName $ResourceGroupName) + "/$LabAccountName"
            InvokeRest  -Uri $uri -Method 'Get'
          } else { #Proper RG, wild name
            $uri = GetLabAccountUri -ResourceGroupName $ResourceGroupName
            (InvokeRest  -Uri $uri -Method 'Get').Value | Where-Object {$_.name -like $LabAccountName}
          }
        } else { # Wild RG forces query by subscription
            $subscriptionId = (Get-AzureRmContext).Subscription.Id
            $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.LabServices/labaccounts"
            (InvokeRest  -Uri $uri -Method 'Get').Value | Where-Object { ($_.name -like $LabAccountName ) -and ($_.id.Split('/')[4] -like $ResourceGroupName)}
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
        $uri = (ConvertToUri -resource $la) + "/labs"
        (InvokeRest -Uri $uri -Method 'Get').Value | Where-Object {$_.Name -like $LabName}
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Remove-AzLab {
    [CmdletBinding()]
    param(
      [parameter(Mandatory=$true,HelpMessage="Lab Account to get labs from", ValueFromPipeline=$true)]
      [ValidateNotNullOrEmpty()]
      $Lab 
    )
  
    begin {. BeginPreamble}
    process {
      try {
        foreach($l in $Lab) {
          $uri = ConvertToUri -resource $l
          InvokeRest -Uri $uri -Method 'Delete'
        }
      } catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
      }
    }
    end {}
  }
  
function New-AzLab {
    [CmdletBinding()]
    param(
      [parameter(Mandatory=$true,HelpMessage="Lab Account to create lab into", ValueFromPipeline=$true)]
      [ValidateNotNullOrEmpty()]
      $LabAccount,
  
      [parameter(Mandatory=$true,HelpMessage="Name of Lab to create")]
      [ValidateNotNullOrEmpty()]
      $LabName,

      [parameter(Mandatory=$false,HelpMessage="Maximum number of users in lab (defaults to 5)")]
      [int]
      $MaxUsers = 5,

      [parameter(Mandatory=$false,HelpMessage="Quota of hours x users (defaults to 40)")]
      [int]
      $UsageQuotaInHours = 40,

      [parameter(Mandatory=$false,HelpMessage="Access mode for the lab (either Restricted or Open)")]
      [ValidateSet('Restricted', 'Open')]
      [string]
      $UserAccessMode = 'Restricted',

      [parameter(mandatory = $false)]
      [switch]
      $SharedPasswordEnabled = $false
  
 
    )
  
    begin {. BeginPreamble}
    process {
      try {
        foreach($la in $LabAccount) {
            $uri = (ConvertToUri -resource $la) + "/labs/" + $LabName
            $sharedPassword = if($SharedPasswordEnabled) {"Enabled"} else {"Disabled"}

            InvokeRest -Uri $uri -Method 'Put' -Body (@{
                location = $LabAccount.location
                properties = @{
                    maxUsersInLab = $MaxUsers.ToString()
                    usageQuota = "PT$($UsageQuotaInHours.ToString())H"
                    userAccessMode = $UserAccessMode
                    sharedPasswordEnabled = $sharedPassword
                }
            } | ConvertTo-Json) | Out-Null
            return WaitProvisioning -uri $uri -delaySec 60 -retryCount 120    
        }
      } catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
      }
    }
    end {}
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
        [parameter(Mandatory=$true,HelpMessage="Lab to create template VM into", ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    )

    $uri = (ConvertToUri -resource $lab) + '/EnvironmentSettings/Default'
    return InvokeRest -Uri $uri -Method 'Get'
  }

  function New-AzLabTemplateVM {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Scope="Function")]
    [CmdletBinding()]
    param(
      [parameter(Mandatory=$true,HelpMessage="Lab to create template VM into", ValueFromPipeline=$true)]
      [ValidateNotNullOrEmpty()]
      $Lab,
  
      [parameter(Mandatory=$true,HelpMessage="Shared Image or Gallery image to use")]
      [ValidateNotNullOrEmpty()]
      $Image,

      [parameter(Mandatory=$true,HelpMessage="Size for template VM")]
      [ValidateSet('Small', 'Medium', 'MediumNested', 'Large', 'GPU')]
      $Size,

      [parameter(Mandatory=$false,HelpMessage="Quota of hours x users (defaults to 40)")]
      [String]
      $Title = "A test title",

      [parameter(Mandatory=$false,HelpMessage="Quota of hours x users (defaults to 40)")]
      [String]
      $Description = "Template Description",

      [parameter(Mandatory=$true,HelpMessage="User name if shared password is enabled")]
      [string]
      $UserName,


      [parameter(Mandatory=$true,HelpMessage="Password if shared password is enabled")]
      [string]
      $Password,

      [parameter(mandatory = $false)]
      [switch]
      $LinuxRdpEnabled = $false  
    )
  
    begin {. BeginPreamble}
    process {
      try {
        foreach($l in $Lab) {

            $sizesHash = @{
                'Small'         = 'Basic'
                'Medium'        = 'Standard'
                'MediumNested'  = 'Virtualization'
                'Large'         = 'Performance'
                'GPU'           = 'GPU'
            }
            $sizeJson = $sizesHash[$Size]

            $uri = (ConvertToUri -resource $l) + '/EnvironmentSettings/Default'

            $imageType = if($image.id -match '/galleryimages/') {'galleryImageResourceId'} else {'sharedImageResourceId'}

            if($LinuxRdpEnabled) {$linux = 'Enabled'} else {$linux = 'Disabled'}

            $body = @{
                location = $l.location
                properties = @{
                    title = $title
                    description = $Description
                    resourceSettings = @{
                        $imageType = $image.id
                        size = $sizeJson
                        referenceVm = @{
                            userName = $UserName
                            password = $Password
                        }
                    }
                    LinuxRdpEnabled = $linux
                }
            }
            $jsonBody = $body | ConvertTo-Json -Depth 10
            Write-Verbose "BODY: $jsonBody"
            InvokeRest -Uri $uri -Method 'Put' -Body $jsonBody | Out-Null
            WaitProvisioning -uri $uri -delaySec 60 -retryCount 120 | Out-Null

            return Get-AzLabAgain -lab $l
        }
      } catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
      }
    }
    end {}
  }

  function Publish-AzLab {
    param(
        [parameter(Mandatory=$true,HelpMessage="Lab to create template VM into", ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    )
    begin {. BeginPreamble}
    process {
      try {
        foreach($l in $Lab) {
          $uri = (ConvertToUri -resource $Lab) + '/EnvironmentSettings/Default'

          $publishUri = $uri + '/publish'
          $publishBody = @{useExistingImage = $false} | ConvertTo-Json
          InvokeRest -Uri $publishUri -Method 'Post' -Body $publishBody | Out-Null

          $uriProv = (ConvertToUri -resource $l) + '/EnvironmentSettings/Default'
          # As a simple scheme, we check every minute for 1.5 hours
          WaitPublishing -uri $uriProv -delaySec 60 -retryCount 90 -params '$expand=properties(%24expand%3DresourceSettings(%24expand%3DreferenceVm(%24expand%3DvmStateDetails)))' | Out-Null

          return Get-AzLabAgain -lab $l
        }
      } catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
      }
  }
  end {}
  }

  function Get-AzLabAccountSharedImage {
    [CmdletBinding()]
    param(
      [parameter(Mandatory=$true,HelpMessage="Lab Account to get shared images from", ValueFromPipeline=$true)]
      [ValidateNotNullOrEmpty()]
      $LabAccount 
    )
  
    begin {. BeginPreamble}
    process {
      try {
        foreach($la in $LabAccount) {
          $uri = (ConvertToUri -resource $la) + "/SharedImages"
          (InvokeRest -Uri $uri -Method 'Get').Value | Where-Object {$_.properties.isEnabled}
        }
      } catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
      }
    }
    end {}
  }

  function Get-AzLabAccountGalleryImage {
    [CmdletBinding()]
    param(
      [parameter(Mandatory=$true,HelpMessage="Lab Account to get shared images from", ValueFromPipeline=$true)]
      [ValidateNotNullOrEmpty()]
      $LabAccount 
    )
  
    begin {. BeginPreamble}
    process {
      try {
        foreach($la in $LabAccount) {
          $uri = (ConvertToUri -resource $la) + "/GalleryImages"
          (InvokeRest -Uri $uri -Method 'Get').Value | Where-Object {$_.properties.isEnabled}
        }
      } catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
      }
    }
    end {}
  }

  function Add-AzLabUser {
    param(
        [parameter(Mandatory=$true,HelpMessage="Lab to add users to", ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory=$true,HelpMessage="Users to add to the lab")]
        [string[]]
        $Emails

    )
    begin {. BeginPreamble}
    process {
      try {
        foreach($l in $Lab) {
          $uri = (ConvertToUri -resource $Lab) + '/addUsers'

          $body = @{emailAddresses = $Emails} | ConvertTo-Json
          InvokeRest -Uri $uri -Method 'Post' -Body $body | Out-Null

          return Get-AzLabAgain -lab $l
        }
      } catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
      }
  }
  end {}
  }

  function Get-AzLabUser {
    param(
        [parameter(Mandatory=$true,HelpMessage="Lab to get users from", ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab
    )
    begin {. BeginPreamble}
    process {
      try {
        foreach($l in $Lab) {
          $uri = (ConvertToUri -resource $Lab) + '/users'

          return (InvokeRest -Uri $uri -Method 'Get').Value
        }
      } catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
      }
  }
  end {}
  }

  function Remove-AzLabUser {
    param(
        [parameter(Mandatory=$true,HelpMessage="Lab to remove users from", ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory=$true,HelpMessage="User to remove")]
        [ValidateNotNullOrEmpty()]
        $User
       
    )
    begin {. BeginPreamble}
    process {
      try {
        foreach($l in $Lab) {
          $userName = $User.name
          $uri = (ConvertToUri -resource $Lab) + '/users/' + $userName

          return InvokeRest -Uri $uri -Method 'Delete'
        }
      } catch {
        Write-Error -ErrorRecord $_ -EA $callerEA
      }
  }
  end {}
  }

  Export-ModuleMember -Function Get-AzLabAccount,
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
                                Remove-AzLabUser
