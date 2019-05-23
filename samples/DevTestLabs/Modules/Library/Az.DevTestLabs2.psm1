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

function PrintHashtable {
  param($hash)

  return ($hash.Keys | ForEach-Object { "$_ $($hash[$_])" }) -join "|"
}

# Getting labs that don't exist shouldn't fail, but return empty for composibility
# Also I am forced to do client side query because when you add -ExpandProperty to Get-AzureRmResource it disables wildcard?????
# Also I know that treating each case separately is ugly looking, but there are various bugs that might be fixed in Get-AzureRmResource
# at which point more queries can be moved server side, so leave it as it is for now.
function MyGetResourceLab {
  param($Name, $ResourceGroupName)

  $ResourceType = "Microsoft.DevTestLab/labs"
  if($ResourceGroupName -and (-not $ResourceGroupName.Contains("*"))) { # Proper RG
    if($Name -and (-not $Name.Contains("*"))) { # Proper RG, Proper Name
      Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -ResourceGroupName $ResourceGroupName -Name $Name -EA SilentlyContinue
    } else { #Proper RG, wild name
      Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -ResourceGroupName $ResourceGroupName -EA SilentlyContinue | Where-Object { $_.ResourceId -like "*/labs/$Name"}
    }
  } else { # Wild RG forces client side query anyhow
    Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -EA SilentlyContinue | Where-Object { $_.ResourceId -like "*/resourcegroups/$ResourceGroupName/*/labs/$Name"}
  }
}

function MyGetResourceVm {
  param($Name, $LabName, $ResourceGroupName)

  $ResourceType = "Microsoft.DevTestLab/labs/virtualMachines"

  if($ResourceGroupName -and (-not $ResourceGroupName.Contains("*"))) { # Proper RG
    if($LabName -and (-not $LabName.Contains("*"))) { # Proper RG, Proper LabName
      if($Name -and (-not $Name.Contains("*"))) { # Proper RG, Proper LabName, Proper Name
        if($azureRm) {
          Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -ResourceGroupName $ResourceGroupName -Name "$LabName/$Name" -EA SilentlyContinue
        } else { 
          Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -ResourceGroupName $ResourceGroupName -EA SilentlyContinue | Where-Object { $_.ResourceId -like "*/labs/$LabName/virtualmachines/$Name"}
        }
      } else { # Proper RG, Proper LabName, Improper Name
        Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -ResourceGroupName $ResourceGroupName -EA SilentlyContinue | Where-Object { $_.ResourceId -like "*/labs/$LabName/virtualmachines/$Name"}
      }
   } else { # Proper RG, Improper LabName
      Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -ResourceGroupName $ResourceGroupName -EA SilentlyContinue | Where-Object { $_.ResourceId -like "*/labs/$LabName/virtualmachines/$Name"}
   }
  } else { # Improper RG forces client side query anyhow
    Get-AzureRmResource -ExpandProperties -resourcetype $ResourceType -EA SilentlyContinue | Where-Object { $_.ResourceId -like "*/resourcegroups/$ResourceGroupName/*/labs/$LabName/virtualmachines/$Name"}
  }
}

function Get-AzureRmCachedAccessToken()
{
  $ErrorActionPreference = 'Stop'
  Set-StrictMode -Off

  if(-not (Get-Module AzureRm.Profile)) {
    Import-Module AzureRm.Profile
  }
  $azureRmProfileModuleVersion = (Get-Module AzureRm.Profile).Version
  # refactoring performed in AzureRm.Profile v3.0 or later
  if($azureRmProfileModuleVersion.Major -ge 3) {
    $azureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    if(-not $azureRmProfile.Accounts.Count) {
      Write-Error "Ensure you have logged in before calling this function."
    }
  } else {
    # AzureRm.Profile < v3.0
    $azureRmProfile = [Microsoft.WindowsAzure.Commands.Common.AzureRmProfileProvider]::Instance.Profile
    if(-not $azureRmProfile.Context.Account.Count) {
      Write-Error "Ensure you have logged in before calling this function."
    }
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
function Get-AzDtlLab {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$false,ValueFromPipelineByPropertyName = $true, ValueFromPipeline=$true, HelpMessage="Name of the lab(s) to retrieve.  This parameter supports wildcards at the beginning and/or end of the string.")]
    [ValidateNotNullOrEmpty()]
    [string]
    $Name = "*",

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of the resource group to get the lab from. It must be an existing one.")]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName = '*'
  )

  begin {. BeginPreamble}
  process {
    try {
      Write-verbose "Retrieving lab $Name"
      MyGetResourceLab -Name $Name -ResourceGroupName $ResourceGroupName
      Write-verbose "Retrieved lab $Name"
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function DeployLab {
  param (
    [parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]
    $arm,

    [parameter(Mandatory = $true)]
    $Lab,

    [parameter(Mandatory = $true)]
    $AsJob,

    [parameter(Mandatory = $true)]
    $Parameters,

    [parameter(mandatory = $false)]
    [switch]
    $IsNewLab = $false
  )
  Write-debug "DEPLOY ARM TEMPLATE`n$arm`nWITH PARAMS: $(PrintHashtable $Parameters)"

  $Name = $Lab.Name
  $ResourceGroupName = $Lab.ResourceGroupName

  if ($Name.Length -gt 40) {
    $deploymentName = "LabDeploy_" + $Name.Substring(0, 40)
  }
  else {
      $deploymentName = "LabDeploy" + $Name
  }
  Write-Verbose "Using deployment name $deploymentName with params`n $(PrintHashtable $Parameters)"

  if(-not $IsNewLab) {
    $existingLab = Get-AzureRmResource -Name $Name  -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if (-not $existingLab) {
        throw "'$Name' Lab already exists. This action is supposed to be performed on an existing lab."
    }
  }
  $jsonPath = StringToFile($arm)

  $sb = {
    param($deploymentName, $Name, $ResourceGroupName, $jsonPath, $Parameters, $justAz)

    if($justAz) {
      Enable-AzureRmAlias -Scope Local -Verbose:$false
    }
    $deployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $jsonPath -TemplateParameterObject $Parameters
    Write-debug "Deployment succeded with deployment of `n$deployment"

    Get-AzureRmResource -Name $Name -ResourceGroupName $ResourceGroupName -ExpandProperties
  }

  if($AsJob) {
    Start-Job      -ScriptBlock $sb -ArgumentList $deploymentName, $Name, $ResourceGroupName, $jsonPath, $Parameters, $justAz
  } else {
    Invoke-Command -ScriptBlock $sb -ArgumentList $deploymentName, $Name, $ResourceGroupName, $jsonPath, $Parameters, $justAz
  }
}

function DeployVm {
  param (
    [parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]
    $arm,

    [parameter(Mandatory = $true)]
    $vm,

    [parameter(Mandatory = $true)]
    $AsJob,

    [parameter(Mandatory = $true)]
    $Parameters,

    [parameter(mandatory = $false)]
    [switch]
    $IsNewVm = $false
  )
  Write-debug "DEPLOY ARM TEMPLATE`n$arm`nWITH PARAMS: $(PrintHashtable $Parameters)"

  $Name = $vm.ResourceId.Split('/')[10]
  $ResourceGroupName = $vm.ResourceGroupName

  if ($Name.Length -gt 40) {
    $deploymentName = "VMDeploy_" + $Name.Replace('/', '-').Substring(0, 40)
  }
  else {
      $deploymentName = "VMDeploy" + $Name.Replace('/', '-')
  }
  Write-Verbose "Using deployment name $deploymentName with params`n $(PrintHashtable $Parameters)"

  if(-not $IsNewVm) {
    $existingVM = Get-AzureRmResource -Name $Name  -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if (-not $existingVM) {
        throw "'$Name' VM already exists. This action is supposed to be performed on an existing lab."
    }
  }
  $jsonPath = StringToFile($arm)

  $sb = {
    param($deploymentName, $Name, $ResourceGroupName, $jsonPath, $Parameters, $justAz)

    if($justAz) {
      Enable-AzureRmAlias -Scope Local -Verbose:$false
    }
    $deployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $jsonPath -TemplateParameterObject $Parameters
    Write-debug "Deployment succeded with deployment of `n$deployment"

    Get-AzureRmResource -Name $Name -ResourceGroupName $ResourceGroupName -ExpandProperties
  }

  if($AsJob.IsPresent) {
    Start-Job      -ScriptBlock $sb -ArgumentList $deploymentName, $Name, $ResourceGroupName, $jsonPath, $Parameters, $justAz
  } else {
    Invoke-Command -ScriptBlock $sb -ArgumentList $deploymentName, $Name, $ResourceGroupName, $jsonPath, $Parameters, $justAz
  }
}

#TODO: reduce function below to just get ErrorActionPreference
function Get-CallerPreference
{
    <#
    .Synopsis
       Fetches "Preference" variable values from the caller's scope.
    .DESCRIPTION
       Script module functions do not automatically inherit their caller's variables, but they can be
       obtained through the $PSCmdlet variable in Advanced Functions.  This function is a helper function
       for any script module Advanced Function; by passing in the values of $ExecutionContext.SessionState
       and $PSCmdlet, Get-CallerPreference will set the caller's preference variables locally.
    .PARAMETER Cmdlet
       The $PSCmdlet object from a script module Advanced Function.
    .PARAMETER SessionState
       The $ExecutionContext.SessionState object from a script module Advanced Function.  This is how the
       Get-CallerPreference function sets variables in its callers' scope, even if that caller is in a different
       script module.
    .PARAMETER Name
       Optional array of parameter names to retrieve from the caller's scope.  Default is to retrieve all
       Preference variables as defined in the about_Preference_Variables help file (as of PowerShell 4.0)
       This parameter may also specify names of variables that are not in the about_Preference_Variables
       help file, and the function will retrieve and set those as well.
    .EXAMPLE
       Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

       Imports the default PowerShell preference variables from the caller into the local scope.
    .EXAMPLE
       Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -Name 'ErrorActionPreference','SomeOtherVariable'

       Imports only the ErrorActionPreference and SomeOtherVariable variables into the local scope.
    .EXAMPLE
       'ErrorActionPreference','SomeOtherVariable' | Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

       Same as Example 2, but sends variable names to the Name parameter via pipeline input.
    .INPUTS
       String
    .OUTPUTS
       None.  This function does not produce pipeline output.
    .LINK
       about_Preference_Variables
    #>

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

# Convert a string to a file so that it can be passed to functions that take a path. Assumes temporary files are deleted by the OS eventually.
function StringToFile([string] $text) {
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp.FullName -Value $text
  return $tmp.FullName
}

function GetComputeVm($vm) {
  return  Get-AzureRmResource -ResourceId $vm.Properties.computeId -ExpandProperties
}
#endregion

#region LAB ACTIONS

function New-AzDtlLab {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of the lab to create")]
    [ValidateLength(1,50)]
    [ValidateNotNullOrEmpty()]
    [string] $Name,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of the resource group to create the lab into. It must be an existing one.")]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      # We could create it, if it doesn't exist, but that would complicate matters as we'd need to take a location as well as parameter
      # Choose to keep it as simple as possible to start with.
      Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop | Out-Null

      $params = @{
        newLabName = $Name
      }

      # Need to create this as DeployLab takes a lab, which works better in all other cases
      $Lab = [pscustomobject] @{
        Name = $Name
        ResourceGroupName = $ResourceGroupName
      }

# Taken from official sample here: https://github.com/Azure/azure-devtestlab/blob/master/Samples/101-dtl-create-lab/azuredeploy.json
@"
{
  "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "newLabName": {
      "type": "string",
      "metadata": {
        "description": "The name of the new lab instance to be created"
      }
    }
  },
  "variables": {
    "labVirtualNetworkName": "[concat('Dtl', parameters('newLabName'))]"
  },
  "resources": [
    {
      "apiVersion": "2018-10-15-preview",
      "type": "Microsoft.DevTestLab/labs",
      "name": "[parameters('newLabName')]",
      "location": "[resourceGroup().location]",
      "resources": [
        {
          "apiVersion": "2018-10-15-preview",
          "name": "[variables('labVirtualNetworkName')]",
          "type": "virtualNetworks",
          "dependsOn": [
            "[resourceId('Microsoft.DevTestLab/labs', parameters('newLabName'))]"
          ]
        },
        {
          "apiVersion": "2018-10-15-preview",
          "name": "Public Environment Repo",
          "type": "artifactSources",
          "location": "[resourceGroup().location]",
          "dependsOn": [
            "[resourceId('Microsoft.DevTestLab/labs', parameters('newLabName'))]"
          ],
          "properties": {
            "status": "Enabled"
          }
        }
      ]
    }
  ],
  "outputs": {
    "labId": {
      "type": "string",
      "value": "[resourceId('Microsoft.DevTestLab/labs', parameters('newLabName'))]"
    }
  }
}
"@ | DeployLab -Lab $Lab -AsJob $AsJob -IsNewLab -Parameters $Params
    }
    catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {
  }
}

function Remove-AzDtlLab {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="Lab object to remove", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        $resId = $l.ResourceId
        Write-Verbose "Started removal of lab $resId."
        if($AsJob.IsPresent) {
          Remove-AzureRmResource -ResourceId $resId -AsJob -Force
        } else {
          Remove-AzureRmResource -ResourceId $resId -Force
        }
        Write-Verbose "Removed lab $resId."
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

#endregion

#region VM ACTIONS

function Get-AzDtlVm {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="Lab object to remove", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$false,HelpMessage="Name of the vms to retrieve.  This parameter supports wildcards at the beginning and/or end of the string.")]
    [ValidateNotNullOrEmpty()]
    [string]
    $Name = "*",

    [parameter(Mandatory=$false,HelpMessage="Name of the vms to retrieve.  This parameter supports wildcards at the beginning and/or end of the string.")]
    [ValidateSet('Starting', 'Running', 'Stopping', 'Stopped', 'Deallocating', 'Deallocated', 'Any')]
    [string]
    $Status = 'Any'
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        $ResourceGroupName = $l.ResourceGroupName
        $LabName = $l.Name
        Write-verbose "Retrieving $Name VMs for lab $LabName in $ResourceGroupName"
        # Need to query client side to support wildcard at start of name as well (but this is bad as potentially many vms are involved)
        # Also notice silently continue for errors to return empty set for composibility
        # TODO: is there a cleaver way to make this less expensive? I.E. prequery without -ExpandProperties and then use the result to query again.
        $vms = MyGetResourceVm -Name "$Name" -LabName $LabName -ResourceGroupName $ResourceGroupName
        Write-verbose "Vms before status filter are $vms"
        if($vms -and ($Status -ne 'Any')) {
          return $vms | Where-Object { $Status -eq (Get-AzDtlVmStatus $_)}
        } else {
          return $vms
        }
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Get-AzDtlVmStatus {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="VM to start. Noop if already started.", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {

        if(-not $v.Properties.lastKnownPowerState) {
          return "Stopped"
        } else {
          return $v.Properties.lastKnownPowerState
        }

        # This is how to get it from the compute VM if the above turns out not to work
<#         $computeVm = GetComputeVm($v)
        $computeGroup = $computeVm.ResourceGroupName
        $name = $computeVm.Name

        $compVM = Get-AzureRmVM -ResourceGroupName $computeGroup -name $name -Status

        $statuses = $compVM.Statuses
        if(-not $statuses) {
          throw "Can't get status for VM $name in $computeGroup"
        }
        return ($statuses | Where Code -Like 'PowerState/*')[0].DisplayStatus
 #>
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Start-AzDtlVm {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="VM to start. Noop if already started.", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {
        Invoke-AzureRmResourceAction -ResourceId $v.ResourceId -Action "start" -Force | Out-Null
        $v | Get-AzDtlVm
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Stop-AzDtlVm {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="VM to stop. Noop if already stopped.", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {
        Invoke-AzureRmResourceAction -ResourceId $v.ResourceId -Action "stop" -Force | Out-Null
        $v  | Get-AzDtlVm
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Remove-AzDtlVm {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="VM to stop. Noop if already stopped.", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {
        Remove-AzureRmResource -ResourceId $vm.ResourceId -Force
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Invoke-AzDtlVmClaim {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="VM to stop. Noop if already stopped.", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {
        Invoke-AzureRmResourceAction -ResourceId $v.ResourceId -Action "claim" -Force | Out-Null
        $v  | Get-AzDtlVm
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Invoke-AzDtlVmUnClaim {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="VM to stop. Noop if already stopped.", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {
        Invoke-AzureRmResourceAction -ResourceId $v.ResourceId -Action "claim" -Force | Out-Null
        $v  | Get-AzDtlVm
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Set-AzDtlVmShutdown {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="Vm to apply policy to", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The time (relative to timeZoneId) at which the Lab VMs will be automatically shutdown (E.g. 17:30, 20:00, 09:00).")]
    [ValidateLength(4,5)]
    [string] $ShutdownTime,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The Windows time zone id associated with labVmShutDownTime (E.g. UTC, Pacific Standard Time, Central Europe Standard Time).")]
    [ValidateLength(3,40)]
    [string] $TimeZoneId,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Which schedule to get")]
    [ValidateSet('Enabled', 'Disabled')]
    [string] $ScheduleStatus = 'Enabled',

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Which schedule to get")]
    [ValidateSet('Enabled', 'Disabled')]
    [string] $NotificationSettings = 'Disabled',

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Which schedule to get")]
    [ValidateRange(1, 60)] #TODO: validate this is right??
    [int] $TimeInIMinutes = 15,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="An help")]
    [string] $ShutdownNotificationUrl = "https://mywebook.com",

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="An help")]
    [string] $EmailRecipient = "someone@somewhere.com",

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {
        $params = @{
          resourceName = $v.ResourceName
          labVmShutDownTime = $ShutdownTime
          timeZoneId = $TimeZoneId
          scheduleStatus = $ScheduleStatus
          notificationSettings = $NotificationSettings
          timeInMinutes = $TimeInIMinutes
          labVmShutDownURL = $ShutdownNotificationUrl
          emailRecipient = $EmailRecipient
        }
        Write-verbose "Set Shutdown with $(PrintHashtable $params)"
@"
{
  "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "resourceName": {
      "type": "string"
    },
    "labVmShutDownTime": {
      "type": "string",
      "minLength": 4,
      "maxLength": 5
    },
    "timeZoneId": {
      "type": "string",
      "minLength": 3
    },
    "scheduleStatus": {
      "type": "string"
    },
    "notificationSettings": {
      "type": "string"
    },
    "timeInMinutes": {
      "type": "int"
    },
    "labVmShutDownURL": {
        "type": "string"
    },
    "emailRecipient": {
        "type": "string"
    }
  },


  "resources": [
    {
      "apiVersion": "2016-05-15",
      "name": "[concat(parameters('resourceName'),'/LabVmsShutdown')]",
      "type": "microsoft.devtestlab/labs/virtualmachines/schedules",
      "location": "[resourceGroup().location]",

      "properties": {
        "status": "[trim(parameters('scheduleStatus'))]",
        "taskType": "LabVmsShutdownTask",
        "timeZoneId": "[string(parameters('timeZoneId'))]",
        "dailyRecurrence": {
          "time": "[string(parameters('labVmShutDownTime'))]"
        },
        "notificationSettings": {
            "status": "[trim(parameters('notificationSettings'))]",
            "timeInMinutes": "[parameters('timeInMinutes')]",
            "webHookUrl": "[trim(parameters('labVmShutDownURL'))]",
            "emailRecipient": "[trim(parameters('emailRecipient'))]"
        }
      }
    }
  ]
}
"@  | DeployVm -vm $v -AsJob $AsJob -Parameters $Params
     }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

#TODO: this returns a OK result resource created, but the UI doesn't show it. To investigate.
function Set-AzDtlShutdownPolicy {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="Lab to apply policy to", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Control level")]
    [ValidateSet('NoControl', 'FullControl', 'OnlyControlTime')]
    [string]
    $ControlLevel
  )

  begin {. BeginPreamble}
  process {
    throw "this returns a OK result resource created, but the UI doesn't show it. Investigate if it works and remove throw."
    try {
      foreach($l in $lab) {

        Switch($ControlLevel) {
          'FullControl'       { $threshold = "['None','Modify','OptOut']"}
          'OnlyControlTime'   { $threshold = "['None','Modify']"}
          'NoControl'         { $threshold = "['None']"}
        }


        $req =
@"
{
  "properties": {
      "description": "",
      "status": "Enabled",
      "factName": "ScheduleEditPermission",
      "threshold":`"$threshold`",
      "evaluatorType": "AllowedValuesPolicy",
  }
}
"@
        Write-verbose "Using $threshold on $($l.ResourceId)"

        $authHeaders = GetHeaderWithAuthToken
        $jsonPath = StringToFile($req)
        $subscriptionId = (Get-AzureRmContext).Subscription.Id
        $ResourceGroupName = $l.ResourceGroupName
        $labName = $l.Name
        $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$labName/policySets/default/policies/ScheduleEditPermission?api-version=2018-10-15-preview" | Out-Null
        Write-Verbose "Using url $url"

        Invoke-WebRequest -Headers $authHeaders -Uri $url -Method 'PUT' -InFile $jsonPath
        $l  | Get-AzDtlLab
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Get-AzDtlVmArtifact {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="Vm to get artifact from", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm
  )

  begin {. BeginPreamble}
  process {
    throw "There is a AzureRM 6.0 bug breaking this code."
    try {
      foreach($v in $Vm) {
        return (Get-AzureRmResource -ResourceId $v.ResourceId -ApiVersion 2016-05-15 -ODataQuery '$expand=Properties($expand=Artifacts)').Properties.Artifacts
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}
function Set-AzDtlVmArtifact {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="Vm to apply artifact to", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Name of the repository to get artifact from.")]
    [ValidateNotNullOrEmpty()]
    [string]
    $RepositoryName,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Name of the artifact to apply.")]
    [ValidateNotNullOrEmpty()]
    [string]
    $ArtifactName,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true,HelpMessage="Parameters for artifact. An array of hashtable, each one as @{name = xxx; value = yyy}")]
    [ValidateNotNullOrEmpty()]
    [array]
    $ArtifactParameters = @()
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {
        $ResourceGroupName = $v.ResourceGroupName

        #TODO: is there a better way? It doesn't seem to be in Expanded props of VM ...
        $DevTestLabName = $v.ResouceId.Split('/')[8]
        if(-not $DevTestLabName) {
          throw "VM Name for $v is not in the format 'RGName/VMName. Why?"
        }

        # Get internal repo name
        $repository = Get-AzureRmResource -ResourceGroupName $resourceGroupName `
          -ResourceType 'Microsoft.DevTestLab/labs/artifactsources' `
          -ResourceName $DevTestLabName -ApiVersion 2016-05-15 `
          | Where-Object { $RepositoryName -in ($_.Name, $_.Properties.displayName) } `
          | Select-Object -First 1

        if(-not $repository) {
          throw "Unable to find repository $RepositoryName in lab $DevTestLabName."
        }
        Write-verbose "Repository found is $($repository.Name)"

        # Get internal artifact name
        $template = Get-AzureRmResource -ResourceGroupName $ResourceGroupName `
          -ResourceType "Microsoft.DevTestLab/labs/artifactSources/artifacts" `
          -ResourceName "$DevTestLabName/$($repository.Name)" `
          -ApiVersion 2016-05-15 `
          | Where-Object { $ArtifactName -in ($_.Name, $_.Properties.title) } `
          | Select-Object -First 1

        if(-not $template) {
          throw "Unable to find template $ArtifactName in lab $DevTestLabName."
        }
        Write-verbose "Template artifact found is $($template.Name)"

        #TODO: is there a better way to construct this?
        $SubscriptionID = (Get-AzureRmContext).Subscription.Id
        $FullArtifactId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$DevTestLabName/artifactSources/$($repository.Name)/artifacts/$($template.Name)"
        Write-verbose "Using artifact id $FullArtifactId"

        $prop = @{
          artifacts = @(
            @{
              artifactId = $FullArtifactId
              parameters = $ArtifactParameters
            }
          )
        }

        Write-debug "Apply:`n $($prop | ConvertTo-Json)`n to $($v.ResourceId)."
        Write-verbose "Using $FullArtifactId on $($v.ResourceId)"
        Invoke-AzureRmResourceAction -Parameters $prop -ResourceId $v.ResourceId -Action "applyArtifacts" -ApiVersion 2016-05-15 -Force | Out-Null
        $v  | Get-AzDtlVm
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Set-AzDtlVmAutoStart {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="Vm to apply autostart to", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true,HelpMessage="Name of the repository to get artifact from.")]
    [bool]
    $AutoStartStatus = $true
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {
        Write-Verbose "Set AutoStart for $($v.ResourceId) to $AutoStartStatus"
        Set-AzureRmResource -ResourceId $v.ResourceId -Tag @{AutoStartOn = $AutoStartStatus} -Force | Out-Null
        $v  | Get-AzDtlVm
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

$templateVmCreation = @"
{
  "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "newVMName": {
      "type": "string"
    },
    "existingLabName": {
      "type": "string"
    }
  },
  "variables": {
    "labSubnetName": "[concat(variables('labVirtualNetworkName'), 'Subnet')]",
    "labVirtualNetworkId": "[resourceId('Microsoft.DevTestLab/labs/virtualnetworks', parameters('existingLabName'), variables('labVirtualNetworkName'))]",
    "labVirtualNetworkName": "[concat('Dtl', parameters('existingLabName'))]",
    "resourceName": "[concat(parameters('existingLabName'), '/', parameters('newVMName'))]",
    "resourceType": "Microsoft.DevTestLab/labs/virtualMachines"
  },
  "resources": [
    {
      "apiVersion": "2018-10-15-preview",
      "type": "Microsoft.DevTestLab/labs/virtualMachines",
      "name": "[variables('resourceName')]",
      "location": "[resourceGroup().location]",
      "properties": {
        "labVirtualNetworkId": "[variables('labVirtualNetworkId')]",
        "labSubnetName": "[variables('labSubnetName')]"
      }
    }
  ],
  "outputs": {
    "vmId": {
      "type": "string",
      "value": "[resourceId(variables('resourceType'), parameters('existingLabName'), parameters('newVMName'))]"
    }
  }
}
"@

# TODO: Consider adding parameters Name and ResourceGroupName tied to the pipeline by property
# to enable easier pipeline for csv files in the form [Name, ResourceGroupName, VMName, ...]
function New-AzDtlVm {
  [CmdletBinding()]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "", Scope="Function")]
  param(
    [parameter(Mandatory=$false, ValueFromPipeline=$true, HelpMessage="Lab object to create Vm into. This is not used if you specify Name/ResourceGroupName")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of Lab object to create Vm into")]
    [ValidateNotNullOrEmpty()]
    $Name,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of Resource Group where lab lives")]
    [ValidateNotNullOrEmpty()]
    $ResourceGroupName,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of VM to create")]
    [ValidateNotNullOrEmpty()]
    [string]
    $VmName,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Size of VM to create")]
    [ValidateNotNullOrEmpty()]
    [string]
    $Size,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="This is a claimable VM")]
    [Switch]
    $Claimable,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Public=separate IP Address, Shared=load balancers optimizes IP Addresses, Private=No public IP address")]
    [Validateset('Public','Private', 'Shared')]
    [string]
    $IpConfig = 'Shared',

    # We need to know the OS even in the custom image case to know which NAT rules to add in the shared IP scenario
    # TODO: perhaps the OS for a custom image can be retrieved. Then the user can not pass this, but we pay the price with one more network trip.
    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Which OS")]
    [Validateset('Windows','Linux')]
    [string]
    $OsType = 'Windows',

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Virtual Network id (defaults to id of virtual network name)")]
    [ValidateNotNullOrEmpty()]
    [string]
    $LabVirtualNetworkId = "",

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Virtual Network id (defaults to [VirtualNetworkName]Subnet)")]
    [ValidateNotNullOrEmpty()]
    [string]
    $LabSubnetName = "",

    [parameter(Mandatory=$true,HelpMessage="User Name", ValueFromPipelineByPropertyName = $true, ParameterSetName ='SSHCustom')]
    [parameter(Mandatory=$true,HelpMessage="User Name", ValueFromPipelineByPropertyName = $true, ParameterSetName ='SSHGallery')]
    [parameter(Mandatory=$false,HelpMessage="User Name", ValueFromPipelineByPropertyName = $true, ParameterSetName ='PasswordCustom')]
    [parameter(Mandatory=$true,HelpMessage="User Name", ValueFromPipelineByPropertyName = $true, ParameterSetName ='PasswordGallery')]
    [ValidateNotNullOrEmpty()]
    [string]
    $UserName = $null,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true,HelpMessage="Password", ParameterSetName ='PasswordCustom')]
    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Password", ParameterSetName ='PasswordGallery')]
    [ValidateNotNullOrEmpty()]
    [string] # We should support key vault retrival at some point
    $Password = $null,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="SSH Key", ParameterSetName ='SSHCustom')]
    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="SSH Key", ParameterSetName ='SSHGallery')]
    [ValidateNotNullOrEmpty()]
    [string]
    $SshKey,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Name of custom image to use or customImage object", ParameterSetName ='SSHCustom')]
    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Name of custom image to use or customImage object", ParameterSetName ='PasswordCustom')]
    [ValidateNotNullOrEmpty()]
    [Object]
    $CustomImage,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Name of Sku", ParameterSetName ='SSHGallery')]
    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Name of Sku", ParameterSetName ='PasswordGallery')]
    [ValidateNotNullOrEmpty()]
    [string]
    $Sku,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Publisher name", ParameterSetName ='SSHGallery')]
    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Publisher name", ParameterSetName ='PasswordGallery')]
    [ValidateNotNullOrEmpty()]
    [string]
    $Publisher, # Is this mandatory?

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Version", ParameterSetName ='SSHGallery')]
    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true,HelpMessage="Version", ParameterSetName ='PasswordGallery')]
    [ValidateNotNullOrEmpty()]
    [string]
    $Offer,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true,HelpMessage="Version", ParameterSetName ='SSHGallery')]
    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true,HelpMessage="Version", ParameterSetName ='PasswordGallery')]
    [ValidateNotNullOrEmpty()]
    [string]
    $Version = 'latest',

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {

      if((-not $lab) -and (-not ($Name -and $ResourceGroupName))) {
        throw "You need to specify either a Lab parameter or Name and ResourceGroupName parameters."
      }

      if(($Name -and (-not $ResourceGroupName)) -or ($ResourceGroupName -and (-not $Name))) {
        throw "You need to speficy both a Name and ResourceName parameter. You can't specify just one of them"
      }

      # Name and ResourceGroupName take precedence over the Lab parameter.
      if($Name) {
        $theLab = [pscustomobject] @{ Name = $Name; ResourceGroupName = $ResourceGroupName}
      } else {
        $theLab = $Lab
      }
      Write-debug "Lab is $theLab"

      # As pipeline goes, we are creating the same vm in multiple labs. It is unclear if that's the most common scenario
      # compared to create multiple identical vms in same lab. We could also consider a more complex pipeline binding to properties of
      # pipeline object, but it gets a bit complicated as $Lab is not a primitive type
      foreach($l in $theLab) {
        # We assume parameterset has ferreted out the set of correct parameters so we don't need to validate here
        # Also, we could consider a table based implementation, but $PSBoundParameters doesn't return default values
        # and alternatives to get *all* parameters are tricky, so going for simple 'if' statements here.
        # Also, for json translation they need to be Objects, not PSObjects, and not hashtable, which kind of forses the ugly Add-Member syntax

        $ResourceGroupName = $l.ResourceGroupName
        $Name = $l.Name

        $t = ConvertFrom-Json $templateVmCreation

        $p = $t.resources.properties
        $p | Add-Member -Name 'size' -Value $Size -MemberType NoteProperty

        if($Claimable) {$p | Add-Member -Name 'allowClaim' -Value $True -MemberType NoteProperty}

        # In the next two -force is needed because the property already exist in json with a different value
        if($LabVirtualNetworkId) { $p | Add-Member -Name 'labVirtualNetworkId' -Value $LabVirtualNetworkId -MemberType NoteProperty -Force}
        if($LabSubnetName) { $p | Add-Member -Name 'labSubnetName' -Value $LabSubnetName -MemberType NoteProperty -Force}
        if($UserName) { $p | Add-Member -Name 'userName' -Value $UserName -MemberType NoteProperty }
        if($Password) { $p | Add-Member -Name 'password' -Value $Password -MemberType NoteProperty }

        if($SshKey) {
          $p | Add-Member -Name 'isAuthenticationWithSshKey' -Value $true -MemberType NoteProperty
          $p | Add-Member -Name 'sshKey' -Value $SshKey -MemberType NoteProperty
        } else {
          $p | Add-Member -Name 'isAuthenticationWithSshKey' -Value $false -MemberType NoteProperty
        }

        if($IpConfig -eq 'Shared') {
          $p | Add-Member -Name 'disallowPublicIpAddress' -Value $True -MemberType NoteProperty
          if($OsType -eq 'Windows') { $port = 3389} else { $port = 22}
          $inboundNatRules = New-Object Object
          $inboundNatRules | Add-Member -Name 'transportProtocol' -Value 'tcp' -MemberType NoteProperty
          $inboundNatRules | Add-Member -Name 'backendPort' -Value $port -MemberType NoteProperty
          $sharedPublicIpAddressConfiguration = New-Object Object
          $sharedPublicIpAddressConfiguration | Add-Member -Name 'inboundNatRules' -Value @($inboundNatRules) -MemberType NoteProperty
          $networkInterface = New-Object Object
          $networkInterface | Add-Member -Name 'sharedPublicIpAddressConfiguration' -Value $sharedPublicIpAddressConfiguration -MemberType NoteProperty
          $p | Add-Member -Name 'networkInterface' -Value $networkInterface -MemberType NoteProperty
        }
        elseif($IpConfig -eq 'Public') {
          $p | Add-Member -Name 'disallowPublicIpAddress' -Value $False -MemberType NoteProperty
        } else {
          $p | Add-Member -Name 'disallowPublicIpAddress' -Value $True -MemberType NoteProperty
        }

        if($CustomImage) {
          if($CustomImage -is [string]) {
            $SubscriptionID = (Get-AzureRmContext).Subscription.Id
            $imageId = "/subscriptions/$SubscriptionID/ResourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$Name/customImages/$CustomImage"
            Write-Verbose "Using custom image (string) $CustomImage with resource id $imageId"
          } elseif($CustomImage.ResourceId) {
            $imageId = $CustomImage.ResourceId
            Write-Verbose "Using custom image (object) $CustomImage with resource id $imageId"
          } else {
            throw "CustomImage $CustomImage is not a string and not an object with a ResourceId property."
          }
          $p | Add-Member -Name 'customImageId' -Value $imageId -MemberType NoteProperty
        }

        if($Sku -or $Publisher -or $Offer) {
          $g = New-Object Object
          $g | Add-member -Name 'Sku' -Value $Sku -MemberType NoteProperty
          $g | Add-member -Name 'OsType' -Value $OsType -MemberType NoteProperty
          $g | Add-member -Name 'Publisher' -Value $Publisher -MemberType NoteProperty
          $g | Add-member -Name 'Version' -Value $Version -MemberType NoteProperty
          $g | Add-member -Name 'Offer' -Value $Offer -MemberType NoteProperty

          $p | Add-member -Name 'galleryImageReference' -Value $g -MemberType NoteProperty
        }

        $jsonToDeploy = ConvertTo-Json $t -Depth 6 # Depth defaults to 2, so it wouldn't print out the GalleryImageReference Property. Why oh why ...
        $deploymentName = "$Name-$VmName"
        Write-debug "JSON ABOUT TO BE DEPLOYED AS $deploymentName `n$jsonToDeploy"

        $jsonPath = StringToFile($jsonToDeploy)

        Write-Verbose "Starting deployment $deploymentName of $VmName in $Name"

        $sb = {
          param($deploymentName, $Name, $ResourceGroupName, $VmName, $jsonPath, $justAz)

          if($justAz) {
            Enable-AzureRmAlias -Scope Local -Verbose:$false
          }
          $deployment = New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName -TemplateFile $jsonPath -existingLabName $Name -newVmName $VmName
          Write-debug "Deployment succeded with deployment of `n$deployment"

          Get-AzureRmResource -Name "$Name/$VmName" -ResourceGroupName $ResourceGroupName -ExpandProperties
        }

        if($AsJob.IsPresent) {
          Start-Job      -ScriptBlock $sb -ArgumentList $deploymentName, $Name, $ResourceGroupName, $vmName, $jsonPath, $justAz
        } else {
          Invoke-Command -ScriptBlock $sb -ArgumentList $deploymentName, $Name, $ResourceGroupName, $vmName, $jsonPath, $justAz
        }
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

## Experimental ...
function Get-UnusedRgInSubscription {
  [CmdletBinding()]
  param()

  <#
  There are multiple RG that can be created by DTL:

  DTL lab: {labname}{13 random digits}
  VM/ENV: {vmname/envname}{6 random digits}

  Resource: {baseName}-{postFix}{count}
  Where postfix = IP/OSdisk/Vms/VMss/lb/nsg/nic/as
  Count= incrementing ordinal value

  This script uses the first two rules. It doesn't dwelve into resources.
  #>

  $rgs = Get-AzureRmResourceGroup
  $dtlNames = Get-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Select-Object -ExpandProperty Name
  $vmNames = Get-AzureRmVM | Select-Object -ExpandProperty Name

  $toDelete = @()
  foreach ($r in $rgs) {
    if($r.ResourceGroupName -match '(.+)(\d{13})') {
      $dtlName = $matches[1]
      if($dtlNames -contains $dtlName) {
        Write-Verbose "$($r.ResourceGroupName) is for $dtlName"
      } else {
        Write-Verbose "$dtlName is not an existing lab"
        $toDelete += $r
      }
    } elseif ($r.ResourceGroupName -match '(.+)(\d{6})') {
      $vmName = $matches[1]
      if($vmNames -contains $vmName) {
        Write-Verbose "$($r.ResourceGroupName) is for $vmName"
      } else {
        Write-Verbose "$vmName is not an existing VM"
        $toDelete += $r
      }
    }
  }

  $toDelete | Select-Object -ExpandProperty ResourceGroupName
}

function Get-AzureRmDtlNetorkCard { [CmdletBinding()] param($vm)}
function Get-AzDtlVmDisks { [CmdletBinding()] param($vm)}
function Import-AzureRmDtlVm { [CmdletBinding()] param($Name, $ResourceGroupName, $ImportParams)}
#endregion

#region ENVIRONMENT ACTIONS
function New-AzDtlLabEnvironment{
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of Lab to create environment into")]
    [ValidateNotNullOrEmpty()]
    $Name,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of Resource Group where lab lives")]
    [ValidateNotNullOrEmpty()]
    $ResourceGroupName,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, HelpMessage="Repository that contains base template name.")]
    [ValidateNotNullOrEmpty()]
    [string] $ArtifactRepositoryDisplayName,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, HelpMessage="Environment base template name.")]
    [ValidateNotNullOrEmpty()]
    [string] $TemplateName,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, HelpMessage="Environment instance name.")]
    [ValidateNotNullOrEmpty()]
    [string] $EnvironmentInstanceName,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, HelpMessage="User Id for the instance.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserId,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, HelpMessage="Environment base template parameters.")]
    [array]
    $EnvironmentParameterSet = @()
  )

  begin {. BeginPreamble}
  process {
    try{

      # Get Lab using Name and ResourceGroupName

      if ((-not $Name) -or (-not $ResourceGroupName)) { throw "Missing Name or ResourceGroupName parameters."}
      $Lab = Get-AzDtlLab -Name $Name -ResourceGroupName $ResourceGroupName

      if (-not $Lab) {throw "Unable to find lab $Name with Resource Group $ResourceGroupName"}

      # Get User Id
      if (-not $UserId) {
        $UserId = $((Get-AzureRmADUser -UserPrincipalName (Get-AzureRmContext).Account).Id.Guid)
        if (-not $UserId) {throw "Unable to get User Id."}
      }
           
      # Get the DevTest lab internal repository identifier
      $repository = Get-AzureRmResource -ResourceGroupName $Lab.ResourceGroupName `
        -ResourceType 'Microsoft.DevTestLab/labs/artifactsources' `
        -ResourceName $Lab.Name `
        -ApiVersion 2016-05-15 `
        | Where-Object { $ArtifactRepositoryDisplayName -in ($_.Name, $_.Properties.displayName) } `
        | Select-Object -First 1
      
      if (-not $repository) { throw "Unable to find repository $ArtifactRepositoryDisplayName in lab $($Lab.Name)." }

      # Get the internal environment template name
      $template = Get-AzureRmResource -ResourceGroupName $Lab.ResourceGroupName `
        -ResourceType "Microsoft.DevTestLab/labs/artifactSources/armTemplates" `
        -ResourceName "$($Lab.Name)/$($repository.Name)" `
        -ApiVersion 2016-05-15 `
        | Where-Object { $TemplateName -in ($_.Name, $_.Properties.displayName) } `
        | Select-Object -First 1
      
      if (-not $template) { throw "Unable to find template $TemplateName in lab $($Lab.Name)." } 

      $templateProperties = @{ "deploymentProperties" = @{ "armTemplateId" = "$($template.ResourceId)"; "parameters" = $EnvironmentParameterSet }; } 
    
      # Create the environment
      $deployment = New-AzureRmResource -Location $Lab.Location `
        -ResourceGroupName $Lab.ResourceGroupName `
        -Properties $templateProperties `
        -ResourceType 'Microsoft.DevTestLab/labs/users/environments' `
        -ResourceName "$($Lab.Name)/$UserId/$EnvironmentInstanceName" `
        -ApiVersion '2016-05-15' -Force

      Write-debug "Deployment succeded with deployment of `n$deployment"

      return $Lab
    }
    catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  } 
  end {
  }
 }

function Get-AzDtlLabEnvironment{
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Lab object to get environments from.")]
    [ValidateNotNullOrEmpty()]
    $Lab    
  )

  begin {. BeginPreamble}
  process {
    try{

     #Get LabId
     $labId = Get-AzDtlLab -Name $Lab.Name -ResourceGroupName $Lab.ResourceGroupName

     if (-not $labId) { throw "Unable to find lab $($Lab.Name) with resource group $($Lab.ResourceGroupName)." } 

     #Get all environments
     $environs = Get-AzureRmResource -ResourceGroupName $Lab.ResourceGroupName `
       -ResourceType 'Microsoft.DevTestLab/labs/users/environments' `
       -ResourceName "$($Lab.Name)/@all" `
       -ApiVersion '2016-05-15' 

     $labId | Add-Member -NotePropertyName 'environments' -NotePropertyValue $environs
     
     return $labId
     
    } 
    catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  } 
  end {
  }
}

#endregion

#region LAB PROPERTIES MANIPULATION

function Add-AzDtlLabUser {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Lab to add users to")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="User emails to add")]
    [ValidateNotNullOrEmpty()]
    [string]
    $UserEmail,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Role to add user emails to (defaults to dtl user)")]
    [ValidateNotNullOrEmpty()]
    [string]
    $Role = 'DevTest Labs User'
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        $ResourceGroupName = $l.ResourceGroupName
        $DevTestLabName = $l.Name
        Write-Verbose "Adding $UserEmail as $Role in $DevTestLabName."
        # We discard the return type because we want to return a Lab to continue the pipeline and the type doesn't seem to contain much useful
        New-AzureRmRoleAssignment -SignInName $UserEmail -RoleDefinitionName $Role `
          -ResourceGroupName $ResourceGroupName -ResourceName $DevTestLabName -ResourceType 'Microsoft.DevTestLab/labs' | Out-Null
        Write-Verbose "Added $UserEmail as $Role in $DevTestLabName."
        return $Lab
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}

function Add-AzDtlLabArtifactRepository {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Lab to add announcement to.")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Title of announcement.")]
    [ValidateNotNullOrEmpty()]
    [string] $ArtifactRepositoryDisplayName = "Team Repository",

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Markdown of announcement.")]
    [ValidateNotNullOrEmpty()]
    [string] $ArtifactRepoUri,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Expiration of announcement (format '2100-01-01T17:00:00+00:00').")]
    [ValidateNotNullOrEmpty()]
    [string] $ArtifactRepoBranch = "master",

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Expiration of announcement (format '2100-01-01T17:00:00+00:00').")]
    [ValidateNotNullOrEmpty()]
    [string] $ArtifactRepoFolder = "Artifacts/",

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Expiration of announcement (format '2100-01-01T17:00:00+00:00').")]
    [ValidateSet("VsoGit", "GitHub")]
    [string] $ArtifactRepoType = "GitHub",

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Expiration of announcement (format '2100-01-01T17:00:00+00:00').")]
    [ValidateNotNullOrEmpty()]
    [string] $ArtifactRepoSecurityToken,

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        $params = @{
          labName = $l.Name
          artifactRepositoryDisplayName = $ArtifactRepositoryDisplayName
          artifactRepoUri               = $ArtifactRepoUri
          artifactRepoBranch            = $ArtifactRepoBranch
          artifactRepoFolder            = $ArtifactRepoFolder
          artifactRepoType              = $ArtifactRepoType
          artifactRepoSecurityToken     = $ArtifactRepoSecurityToken
        }
        Write-verbose "Set Artifact repo with $(PrintHashtable $params)"

@"
{
  "`$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "labName": {
      "type": "string"
    },
    "artifactRepositoryDisplayName": {
      "type": "string"
    },
    "artifactRepoUri": {
      "type": "string"
    },
    "artifactRepoBranch": {
      "type": "string"
    },
    "artifactRepoFolder": {
      "type": "string"
    },
    "artifactRepoType": {
      "type": "string",
      "allowedValues": [ "VsoGit", "GitHub" ]
    },
    "artifactRepoSecurityToken": {
      "type": "securestring"
    }
  },
  "variables": {
    "artifactRepositoryName": "[concat('Repo-', uniqueString(subscription().subscriptionId))]"
  },
  "resources": [
    {
      "apiVersion": "2018-10-15-preview",
      "type": "Microsoft.DevTestLab/labs",
      "name": "[parameters('labName')]",
      "location": "[resourceGroup().location]",
      "resources": [
        {
          "apiVersion": "2018-10-15-preview",
          "name": "[variables('artifactRepositoryName')]",
          "type": "artifactSources",
          "dependsOn": [
            "[resourceId('Microsoft.DevTestLab/labs', parameters('labName'))]"
          ],
          "properties": {
            "uri": "[parameters('artifactRepoUri')]",
            "folderPath": "[parameters('artifactRepoFolder')]",
            "branchRef": "[parameters('artifactRepoBranch')]",
            "displayName": "[parameters('artifactRepositoryDisplayName')]",
            "securityToken": "[parameters('artifactRepoSecurityToken')]",
            "sourceType": "[parameters('artifactRepoType')]",
            "status": "Enabled"
          }
        }
      ]
    }
  ],
  "outputs": {
    "labId": {
      "type": "string",
      "value": "[resourceId('Microsoft.DevTestLab/labs', parameters('labName'))]"
    }
  }
}
"@ | DeployLab -Lab $l -AsJob $AsJob -Parameters $Params
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}

function Set-AzDtlLabAnnouncement {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Lab to add announcement to.")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Title of announcement.")]
    [ValidateNotNullOrEmpty()]
    [string] $Title,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Markdown of announcement.")]
    [ValidateNotNullOrEmpty()]
    [string] $AnnouncementMarkdown,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Expiration of announcement (format '2100-01-01T17:00:00+00:00').")]
    [ValidateNotNullOrEmpty()]
    [string] $Expiration = "2100-01-01T17:00:00+00:00",

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        $params = @{
          newLabName = $l.Name
          announcementTitle = $Title
          announcementMarkdown = $AnnouncementMarkdown
          announcementExpiration = $Expiration
        }
        Write-verbose "Set Lab Announcement with $(PrintHashtable $params)"

@"
      {
        "`$schema": "http://schema.management.azure.com/schemas/2014-04-01-preview/deploymentTemplate.json#",
        "contentVersion": "1.0.0.0",
        "parameters": {
            "newLabName": {
                "type": "string"
            },
            "announcementTitle": {
                "type": "string"
            },
            "announcementMarkdown": {
                "type": "string"
            },
            "announcementExpiration":{
                "type": "string"
            }
        },
        "resources": [
            {
                "apiVersion": "2018-10-15-preview",
                "name": "[parameters('newLabName')]",
                "type": "Microsoft.DevTestLab/labs",
                "location": "[resourceGroup().location]",
                "properties": {
                    "labStorageType": "Premium",
                    "announcement":
                    {
                        "enabled": "Enabled",
                        "expired": "False",
                        "expirationDate": "[parameters('announcementExpiration')]",
                        "markdown": "[parameters('announcementMarkdown')]",
                        "title": "[parameters('announcementTitle')]"
                    }
                }
            }
        ],
        "outputs": {
          "labId": {
            "type": "string",
            "value": "[resourceId('Microsoft.DevTestLab/labs', parameters('newLabName'))]"
          }
        }
    }
"@ | DeployLab -Lab $l -AsJob $AsJob -Parameters $Params
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}

function Set-AzDtlLabSupport {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Lab to add support message to.")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Markdown of support message.")]
    [ValidateNotNullOrEmpty()]
    [string] $SupportMarkdown,

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        $params = @{
          newLabName = $l.Name
          supportMessageMarkdown = $SupportMarkdown
        }
        Write-verbose "Set Lab Support with $(PrintHashtable $params)"

@"
{
  "`$schema": "http://schema.management.azure.com/schemas/2014-04-01-preview/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
      "newLabName": {
          "type": "string"
      },
      "supportMessageMarkdown": {
          "type": "string"
      }
  },
  "resources": [
      {
          "apiVersion": "2018-10-15-preview",
          "name": "[parameters('newLabName')]",
          "type": "Microsoft.DevTestLab/labs",
          "location": "[resourceGroup().location]",
          "properties": {
              "labStorageType": "Premium",
              "support":
              {
                  "enabled": "Enabled",
                  "markdown": "[parameters('supportMessageMarkdown')]"
              }
          }
      }
  ],
    "outputs": {
      "labId": {
        "type": "string",
        "value": "[resourceId('Microsoft.DevTestLab/labs', parameters('newLabName'))]"
      }
    }
  }
"@ | DeployLab -Lab $l -AsJob $AsJob -Parameters $Params
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}

function Set-AzDtlLabRdpSettings {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Lab to add RDP settings to.")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Experience level RDP connection.")]
    [ValidateRange(1,7)]
    [int] $ExperienceLevel,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="URL of Gateway for RDP.")]
    [ValidateNotNullOrEmpty()]
    [string] $GatewayUrl,


    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        $params = @{
          newLabName = $l.Name
          experienceLevel = $ExperienceLevel
          gatewayUrl = $GatewayUrl
        }
        Write-verbose "Set Rdp Settings with $(PrintHashtable $params)"
@"
{
  "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "newLabName": {
      "type": "string",
      "metadata": {
        "description": "The name of the new lab instance to be created."
      }
    },
    "experienceLevel": {
      "type": "int",
      "minValue": 1,
      "maxValue": 7
    },
    "gatewayUrl": {
      "type": "string"
    }
  },
  "resources": [
    {
      "apiVersion": "2018-10-15-preview",
      "type": "Microsoft.DevTestLab/labs",
      "name": "[parameters('newLabName')]",
      "location": "[resourceGroup().location]",
      "properties":{
        "extendedProperties":{
          "RdpConnectionType": "[parameters('experienceLevel')]",
          "RdpGateway":"[parameters('gatewayUrl')]"
        }
      }
    }
  ],
  "outputs": {
    "labId": {
      "type": "string",
      "value": "[resourceId('Microsoft.DevTestLab/labs', parameters('newLabName'))]"
    }
  }
}
"@ | DeployLab -Lab $l -AsJob $AsJob -Parameters $Params
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}

function Set-AzDtlLabShutdown {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Lab to operate on.")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The time (relative to timeZoneId) at which the Lab VMs will be automatically shutdown (E.g. 17:30, 20:00, 09:00).")]
    [ValidateLength(4,5)]
    [string] $ShutdownTime,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The Windows time zone id associated with labVmShutDownTime (E.g. UTC, Pacific Standard Time, Central Europe Standard Time).")]
    [ValidateLength(3,40)]
    [string] $TimeZoneId,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Which schedule to get")]
    [ValidateSet('Enabled', 'Disabled')]
    [string] $ScheduleStatus = 'Enabled',

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Which schedule to get")]
    [ValidateSet('Enabled', 'Disabled')]
    [string] $NotificationSettings = 'Disabled',

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Which schedule to get")]
    [ValidateRange(1, 60)] #TODO: validate this is right??
    [int] $TimeInIMinutes = 15,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="An help")]
    [string] $ShutdownNotificationUrl = "https://mywebook.com",

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="An help")]
    [string] $EmailRecipient = "someone@somewhere.com",

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        $params = @{
          newLabName = $l.Name
          labVmShutDownTime = $ShutdownTime
          timeZoneId = $TimeZoneId
          scheduleStatus = $ScheduleStatus
          notificationSettings = $NotificationSettings
          timeInMinutes = $TimeInIMinutes
          labVmShutDownURL = $ShutdownNotificationUrl
          emailRecipient = $EmailRecipient
        }
        Write-verbose "Set Shutdown with $(PrintHashtable $params)"
@"
{
  "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "newLabName": {
      "type": "string"
    },
    "labVmShutDownTime": {
      "type": "string",
      "minLength": 4,
      "maxLength": 5
    },
    "timeZoneId": {
      "type": "string",
      "minLength": 3
    },
    "scheduleStatus": {
      "type": "string"
    },
    "notificationSettings": {
      "type": "string"
    },
    "timeInMinutes": {
      "type": "int"
    },
    "labVmShutDownURL": {
        "type": "string"
    },
    "emailRecipient": {
        "type": "string"
    }
  },

  "resources": [
    {
      "apiVersion": "2018-10-15-preview",
      "type": "Microsoft.DevTestLab/labs",
      "name": "[trim(parameters('newLabName'))]",
      "location": "[resourceGroup().location]",

      "resources": [
        {
          "apiVersion": "2018-10-15-preview",
          "name": "LabVmsShutdown",
          "type": "schedules",
          "dependsOn": [
            "[resourceId('Microsoft.DevTestLab/labs', parameters('newLabName'))]"
          ],
          "properties": {
            "status": "[trim(parameters('scheduleStatus'))]",
            "taskType": "LabVmsShutdownTask",
            "timeZoneId": "[string(parameters('timeZoneId'))]",
            "dailyRecurrence": {
              "time": "[string(parameters('labVmShutDownTime'))]"
            },
            "notificationSettings": {
                "status": "[trim(parameters('notificationSettings'))]",
                "timeInMinutes": "[parameters('timeInMinutes')]"
            }
          }
        },
        {
            "apiVersion": "2018-10-15-preview",
            "name": "AutoShutdown",
            "type": "notificationChannels",
            "properties": {
                "events": [
                    {
                        "eventName": "Autoshutdown"
                    }
                ],
                "webHookUrl": "[trim(parameters('labVmShutDownURL'))]",
                "emailRecipient": "[trim(parameters('emailRecipient'))]"
            },
            "dependsOn": [
                "[resourceId('Microsoft.DevTestLab/labs', parameters('newLabName'))]"
            ]
        }
      ]
    }
  ],
  "outputs": {
    "labId": {
      "type": "string",
      "value": "[resourceId('Microsoft.DevTestLab/labs', parameters('newLabName'))]"
    }
  }
}
"@ | DeployLab -Lab $l -AsJob $AsJob -Parameters $Params
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}

function Set-AzDtlLabStartup {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Lab to operate on.")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The time (relative to timeZoneId) at which the Lab VMs will be automatically shutdown (E.g. 17:30, 20:00, 09:00).")]
    [ValidateLength(4,5)]
    [string] $StartupTime,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The Windows time zone id associated with labVmStartup (E.g. UTC, Pacific Standard Time, Central Europe Standard Time).")]
    [ValidateLength(3,40)]
    [string] $TimeZoneId,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Days when to start the VM")]
    [Array] $WeekDays = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'),

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        $params = @{
          labName = $l.Name
          labVmStartupTime = $StartupTime
          timeZoneId = $TimeZoneId
          weekDays = $WeekDays
        }
        Write-verbose "Set Startup with $(PrintHashtable $params)"
@"
{
  "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "labName": {
      "type": "string"
    },
    "labVmStartupTime": {
      "type": "string",
      "minLength": 4,
      "maxLength": 5
    },
    "timeZoneId": {
      "type": "string",
      "minLength": 3
    },
    "weekDays": {
      "type": "array"
    }
  },

  "resources": [
    {
      "apiVersion": "2018-10-15-preview",
      "type": "microsoft.devtestlab/labs/schedules",
      "name": "[concat(parameters('labName'), '/', 'LabVmAutoStart')]",
      "location": "[resourceGroup().location]",
      "properties": {
        "status": "Enabled",
        "timeZoneId": "[string(parameters('timeZoneId'))]",
        "weeklyRecurrence": {
          "time": "[string(parameters('labVmStartupTime'))]",
          "weekdays": "[parameters('weekDays')]"
        },
        "taskType": "LabVmsStartupTask",
        "notificationSettings": {
          "status": "Disabled",
          "timeInMinutes": 15
        }
      }
    }
  ],
  "outputs": {
    "labId": {
      "type": "string",
      "value": "[resourceId('Microsoft.DevTestLab/labs', parameters('labName'))]"
    }
  }
}
"@ | DeployLab -Lab $l -AsJob $AsJob -Parameters $Params
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}

function Get-AzDtlLabSchedule {
  Param(
    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Lab to operate on")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Which schedule to get")]
    [ValidateSet('AutoStart', 'AutoShutdown')]
    $ScheduleType
  )
  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        if($ScheduleType -eq 'AutoStart') {
          $ResourceName = "$($l.Name)/LabVmAutoStart"
        } else {
          $ResourceName = "$($l.Name)/LabVmsShutdown"
        }

        try {
          # Why oh why Silentlycontinue does not work here
          Get-AzureRmResource -Name $ResourceName -ResourceType "Microsoft.DevTestLab/labs/schedules" -ResourceGroupName $l.ResourceGroupName -ApiVersion 2016-05-15 -ea silentlycontinue
        } catch {
          return @() # Do we need compositionality here or should we just let the exception goes through?
        }
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}

function Get-AzureRmDtlNetwork { [CmdletBinding()] param($Name, $ResourceGroupName)}
function Get-AzureRmDtlLoadBalancers { [CmdletBinding()] param($Name, $ResourceGroupName)}
function Get-AzureRmDtlCosts { [CmdletBinding()] param($Name, $ResourceGroupName)}
function Get-AzDtlLabAnnouncement { [CmdletBinding()] param($Name, $ResourceGroupName)}
function Get-AzureRmDtlInternalSupport { [CmdletBinding()] param($Name, $ResourceGroupName)}
function Get-AzureRmDtlRepositories { [CmdletBinding()] param($Name, $ResourceGroupName)}
function Get-AzureRmDtlMarketplaceImages { [CmdletBinding()] param($Name, $ResourceGroupName)}
function Get-AzureRmDtlRdpSettings { [CmdletBinding()] param($Name, $ResourceGroupName)}

function Set-AzureRmDtlMarketplaceImages { [CmdletBinding()] param($Name, $ResourceGroupName, $ImagesParams)}
#endregion

#region CUSTOM IMAGE MANIPULATION
function New-AzDtlCustomImageFromVm {
  [CmdletBinding()]
  param(

    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="The time (relative to timeZoneId) at which the Lab VMs will be automatically shutdown (E.g. 17:30, 20:00, 09:00).")]
    [ValidateNotNullOrEmpty()]
    $Vm,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="The Windows time zone id associated with labVmStartup (E.g. UTC, Pacific Standard Time, Central Europe Standard Time).")]
    [ValidateSet('NonSysprepped', 'SysprepRequested', 'SysprepApplied')]
    [string] $WindowsOsState = 'NonSysprepped',

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The Windows time zone id associated with labVmStartup (E.g. UTC, Pacific Standard Time, Central Europe Standard Time).")]
    [ValidateNotNullOrEmpty()]
    [string] $ImageName,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The Windows time zone id associated with labVmStartup (E.g. UTC, Pacific Standard Time, Central Europe Standard Time).")]
    [ValidateNotNullOrEmpty()]
    [string] $ImageDescription,

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )

  begin {. BeginPreamble}
  process {
    try {
      foreach($v in $Vm) {
        $labName = $Vm.ResourceId.Split('/')[8]
        Write-Verbose "Creating it in lab $labName"
        $l = Get-AzDtlLab -Name $LabName -ResourceGroupName $vm.ResourceGroupName

        $params = @{
          existingLabName = $labName
          existingVMResourceId = $v.ResourceId
          windowsOsState = $WindowsOsState
          imageName = $ImageName
          imageDescription = $ImageDescription
        }
        Write-verbose "Set Startup with $(PrintHashtable $params)"
@"
{
  "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "existingLabName": {
      "type": "string",
      "metadata": {
        "description": "Name of an existing lab where the custom image will be created."
      }
    },
    "existingVMResourceId": {
      "type": "string",
      "metadata": {
        "description": "Resource ID of an existing VM from which the custom image will be created."
      }
    },
      "windowsOsState": {
      "type": "string",
      "allowedValues": [
        "NonSysprepped",
        "SysprepRequested",
        "SysprepApplied"
        ],
      "defaultValue": "NonSysprepped",
      "metadata": {
        "description": "State of Windows on the machine. It can be one of three values NonSysprepped, SysprepRequested, and SysprepApplied"
      }
    },
    "imageName": {
      "type": "string",
      "metadata": {
        "description": "Name of the custom image being created or updated."
      }
    },
    "imageDescription": {
      "type": "string",
      "defaultValue": "",
      "metadata": {
        "description": "Details about the custom image being created or updated."
      }
    }
  },
  "variables": {
    "resourceName": "[concat(parameters('existingLabName'), '/', parameters('imageName'))]",
    "resourceType": "Microsoft.DevTestLab/labs/customimages"
  },
  "resources": [
    {
      "apiVersion": "2018-10-15-preview",
      "name": "[variables('resourceName')]",
      "type": "Microsoft.DevTestLab/labs/customimages",
      "properties": {
        "description": "[parameters('imageDescription')]",
        "vm": {
          "sourceVmId": "[parameters('existingVMResourceId')]",
          "windowsOsInfo": {
            "windowsOsState": "[parameters('windowsOsState')]"
          }
        }
      }
    }
  ],
  "outputs": {
    "customImageId": {
      "type": "string",
      "value": "[resourceId(variables('resourceType'), parameters('existingLabName'), parameters('imageName'))]"
    }
  }
}
"@ | DeployLab -Lab $l -AsJob $AsJob -Parameters $Params | Out-Null

        $l | Get-AzDtlCustomImage | Where-Object {$_.Name -eq $ImageName}
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}

function Import-AzDtlCustomImageFromUri {
  Param(
    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Lab to operate on")]
    [ValidateNotNullOrEmpty()]
    $Lab,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Uri to get VHD from")]
    [ValidateNotNullOrEmpty()]
    [string]
    $Uri,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Uri to get VHD from")]
    [ValidateSet('Linux', 'Windows')]
    [string]
    $ImageOsType,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Uri to get VHD from")]
    [bool]
    $IsVhdSysPrepped = $false,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Uri to get VHD from")]
    [ValidateNotNullOrEmpty()]
    [string]
    $ImageName,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Uri to get VHD from")]
    [ValidateNotNullOrEmpty()]
    [string]
    $ImageDescription = "",

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job")]
    [switch] $AsJob = $False
  )
  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {

        $sb = {
          param($l, $Uri, $ImageOsType, $IsVhdSysPrepped, $ImageName, $ImageDescription, $justAz)

          if($justAz) {
            Enable-AzureRmAlias -Scope Local -Verbose:$false
          }
          # Get storage account for the lab
          $labRgName= $l.ResourceGroupName
          $sourceLab = $l
          $DestStorageAccountResourceId = $sourceLab.Properties.artifactsStorageAccount
          $DestStorageAcctName = $DestStorageAccountResourceId.Substring($DestStorageAccountResourceId.LastIndexOf('/') + 1)
          $storageAcct = (Get-AzureRMStorageAccountKey  -StorageAccountName $DestStorageAcctName -ResourceGroupName $labRgName)
          $DestStorageAcctKey = $storageAcct.Value[0]
          $DestStorageContext = New-AzureStorageContext -StorageAccountName $DestStorageAcctName -StorageAccountKey $DestStorageAcctKey
          New-AzureStorageContainer -Context $DestStorageContext -Name 'uploads' -EA SilentlyContinue

          # Copy vhd at uri to storage account
          # TODO: it probably uses one more thread than needed.
          $handle = Start-AzureStorageBlobCopy -srcUri $Uri -DestContainer 'uploads' -DestBlob $ImageName -DestContext $DestStorageContext -Force
          Write-Verbose "Started copying $ImageName from $Uri ..."
          $copyStatus = $handle | Get-AzureStorageBlobCopyState

          while (($copyStatus | Where-Object {$_.Status -eq "Pending"}) -ne $null) {
              $copyStatus | Where-Object {$_.Status -eq "Pending"} | ForEach-Object {
                  [int]$perComplete = ($_.BytesCopied/$_.TotalBytes)*100
                  Write-Verbose ("    Copying " + $($_.Source.Segments[$_.Source.Segments.Count - 1]) + " to " + $DestStorageAcctName + " - $perComplete% complete" )
              }
              Start-Sleep -Seconds 60
              $copyStatus = $handle | Get-AzureStorageBlobCopyState
          }

          $copyStatus | Where-Object {$_.Status -ne "Success"} | ForEach-Object {
            throw "    Error copying image $($_.Source.Segments[$_.Source.Segments.Count - 1]), $($_.StatusDescription)"
          }

          $copyStatus | Where-Object {$_.Status -eq "Success"} | ForEach-Object {
            Write-Verbose "    Completed copying image $($_.Source.Segments[$_.Source.Segments.Count - 1]) to $DestStorageAcctName - 100% complete"
          }

          # Create custom images
          $params = @{
            existingLabName = $l.Name
            existingVhdUri = $DestStorageContext.BlobEndPoint + "uploads/" + $ImageName
            imageOsType = $ImageOsType
            isVhdSysPrepped = $IsVhdSysPrepped
            imageName = $ImageName
            imageDescription = $ImageDescription
          }
          Write-verbose "New custom image with $(PrintHashtable $params)"

@"
{
    "`$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
      "existingLabName": {
        "type": "string"
      },
      "existingVhdUri": {
        "type": "string"
      },
      "imageOsType": {
        "type": "string",
        "defaultValue": "Windows",
        "allowedValues": [
          "Linux",
          "Windows"
        ]
      },
      "isVhdSysPrepped": {
        "type": "bool",
        "defaultValue": false
      },
      "imageName": {
        "type": "string"
      },
      "imageDescription": {
        "type": "string",
        "defaultValue": ""
      }
    },
    "variables": {
      "resourceName": "[concat(parameters('existingLabName'), '/', parameters('imageName'))]",
      "resourceType": "Microsoft.DevTestLab/labs/customimages"
    },
    "resources": [
      {
        "apiVersion": "2016-05-15",
        "name": "[variables('resourceName')]",
        "type": "Microsoft.DevTestLab/labs/customimages",
        "properties": {
          "author": "None",
          "vhd": {
            "imageName": "[parameters('existingVhdUri')]",
            "sysPrep": "[parameters('isVhdSysPrepped')]",
            "osType": "[parameters('imageOsType')]"
          },
          "description": "[parameters('imageDescription')]"
        }
      }
    ],
    "outputs": {
      "customImageId": {
        "type": "string",
        "value": "[resourceId(variables('resourceType'), parameters('existingLabName'), parameters('imageName'))]"
      }
    }
  }
"@ | DeployLab -Lab $l -AsJob $false -Parameters $Params | Out-Null

          # Now that we have created the custom image we can remove the vhd
          Remove-AzureStorageBlob -Context $DestStorageContext -Container 'uploads' -Blob $ImageName | Out-Null
          $l | Get-AzDtlCustomImage | Where-Object {$_.Name -eq "$ImageName"}
        }

        if($AsJob.IsPresent) {
          Start-Job      -ScriptBlock $sb -ArgumentList $l, $Uri, $ImageOsType, $IsVhdSysPrepped, $ImageName, $ImageDescription, $justAz
        } else {
          Invoke-Command -ScriptBlock $sb -ArgumentList $l, $Uri, $ImageOsType, $IsVhdSysPrepped, $ImageName, $ImageDescription, $justAz
        }
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}

function Get-AzDtlCustomImage {
  Param(
    [parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Lab to operate on")]
    [ValidateNotNullOrEmpty()]
    $Lab
  )
  begin {. BeginPreamble}
  process {
    try {
      foreach($l in $Lab) {
        Get-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs/customImages' -ResourceName $l.Name -ResourceGroupName $l.ResourceGroupName  -ApiVersion '2016-05-15'
      }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }

  end {}
}
#endregion

#region EXPORTS
New-Alias -Name 'Dtl-NewLab'              -Value New-AzDtlLab
New-Alias -Name 'Dtl-RemoveLab'           -Value Remove-AzDtlLab
New-Alias -Name 'Dtl-GetLab'              -Value Get-AzDtlLab
New-Alias -Name 'Dtl-GetVm'               -Value Get-AzDtlVm
New-Alias -Name 'Dtl-StartVm'             -Value Start-AzDtlVm
New-Alias -Name 'Dtl-StopVm'              -Value Stop-AzDtlVm
New-Alias -Name 'Dtl-ClaimVm'             -Value Invoke-AzDtlVmClaim
New-Alias -Name 'Dtl-UnClaimVm'           -Value Invoke-AzDtlVmUnClaim
New-Alias -Name 'Dtl-RemoveVm'            -Value Remove-AzDtlVm
New-Alias -Name 'Dtl-NewVm'               -Value New-AzDtlVm
New-Alias -Name 'Dtl-AddUser'             -Value Add-AzDtlLabUser
New-Alias -Name 'Dtl-SetLabAnnouncement'  -Value Set-AzDtlLabAnnouncement
New-Alias -Name 'Dtl-SetLabSupport'       -Value Set-AzDtlLabSupport
New-Alias -Name 'Dtl-SetLabRdp'           -Value Set-AzDtlLabRdpSettings
New-Alias -Name 'Dtl-AddLabRepo'          -Value Add-AzDtlLabArtifactRepository
New-Alias -Name 'Dtl-ApplyArtifact'       -Value Set-AzDtlVmArtifact
New-Alias -Name 'Dtl-GetLabSchedule'      -Value Get-AzDtlLabSchedule
New-Alias -Name 'Dtl-SetLabShutdown'      -Value Set-AzDtlLabShutdown
New-Alias -Name 'Dtl-SetLabStartup'       -Value Set-AzDtlLabStartup
New-Alias -Name 'Dtl-SetLabShutPolicy'    -Value Set-AzDtlShutdownPolicy
New-Alias -Name 'Dtl-SetAutoStart'        -Value Set-AzDtlVmAutoStart
New-Alias -Name 'Dtl-SetVmShutdown'       -Value Set-AzDtlVmShutdown
New-Alias -Name 'Dtl-GetVmStatus'         -Value Get-AzDtlVmStatus
New-Alias -Name 'Dtl-GetVmArtifact'       -Value Get-AzDtlVmArtifact
New-Alias -Name 'Dtl-ImportCustomImage'   -Value Import-AzDtlCustomImageFromUri
New-Alias -Name 'Dtl-GetCustomImage'      -Value Get-AzDtlCustomImage
New-Alias -Name 'Dtl-NewCustomImage'      -Value New-AzDtlCustomImageFromVm

New-Alias -Name 'Claim-AzureRmDtlVm'      -Value Invoke-AzDtlVmClaim
New-Alias -Name 'UnClaim-AzureRmDtlVm'    -Value Invoke-AzDtlVmUnClaim

New-Alias -Name 'Dtl-NewEnvironment'      -Value New-AzDtlLabEnvironment
New-Alias -Name 'Dtl-GetEnvironment'      -Value Get-AzDtlLabEnvironment

Export-ModuleMember -Function New-AzDtlLab,
                              Remove-AzDtlLab,
                              Get-AzDtlLab,
                              Get-AzDtlVm,
                              Start-AzDtlVm,
                              Stop-AzDtlVm,
                              Invoke-AzDtlVmClaim,
                              Invoke-AzDtlVmUnClaim,
                              New-AzDtlVm,
                              Get-UnusedRgInSubscription,
                              Remove-AzDtlVm,
                              Add-AzDtlLabUser,
                              Set-AzDtlLabAnnouncement,
                              Set-AzDtlLabSupport,
                              Set-AzDtlLabRdpSettings,
                              Add-AzDtlLabArtifactRepository,
                              Set-AzDtlVmArtifact,
                              Get-AzDtlLabSchedule,
                              Set-AzDtlLabShutdown,
                              Set-AzDtlLabStartup,
                              New-AzDtlLabEnvironment,
                              Get-AzDtlLabEnvironment,
                              Set-AzDtlShutdownPolicy,
                              Set-AzDtlVmAutoStart,
                              Set-AzDtlVmShutdown,
                              Get-AzDtlVmStatus,
                              Get-AzDtlVmArtifact,
                              Import-AzDtlCustomImageFromUri,
                              Get-AzDtlCustomImage,
                              New-AzDtlCustomImageFromVm

Export-ModuleMember -Alias *
#endregion