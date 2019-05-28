# Contributing

When contributing to this repository, please first discuss the change you wish to make via issue,
email, or any other method with the owners of this repository before making a change. 

## Code Guidelines

1. Put the `ValueFromPipeline` attribute on the parameter you expect to come from the pipeline.
2. Return the correct object from your function (i.e. lab, vm or custom image) as to enable pipelining.
3. Re-query for the resource you are returning from the function as your function might have changed it, so you likely need the latest one.
4. Use the `begin/process/end` syntax and put `. BeginPreamble` in the `begin` part. This has to do with correct error management. Read the code for details.
5. Use the `foreach` pattern to enable taking multiple objects from the pipeline
6. Use the function below as a template on how to write the function

```Powershell
function Invoke-AzDtlVmClaim {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="VM to claim. Noop if already claimed.", ValueFromPipeline=$true)]
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
```

7. In the common case you are deploying an ARM template to a lab, use the utility function `DeployLab` as shown below

```Powershell
function New-AzDtlLab {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of the lab to create.")]
    [ValidateLength(1,50)]
    [ValidateNotNullOrEmpty()]
    [string] $Name,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of the resource group where to create the lab. It must already exist.")]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName,

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job.")]
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
YOUR ARM TEMPLATE GOES HERE
"@ | DeployLab -Lab $Lab -AsJob $AsJob -IsNewLab -Parameters $Params
    }
    catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {
  }
}
```

7. There is an equivalent for Deploying VMs

```Powershell
function Set-AzDtlVmShutdown {
  [CmdletBinding()]
  param(
    [parameter(Mandatory=$true,HelpMessage="Vm to apply policy to.", ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Vm,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The time (relative to timeZoneId) at which the Lab VMs will be automatically shutdown (E.g. 17:30, 20:00, 09:00).")]
    [ValidateLength(4,5)]
    [string] $ShutdownTime,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="The Windows time zone id associated with labVmShutDownTime (E.g. UTC, Pacific Standard Time, Central Europe Standard Time).")]
    [ValidateLength(3,40)]
    [string] $TimeZoneId,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Set schedule status.")]
    [ValidateSet('Enabled', 'Disabled')]
    [string] $ScheduleStatus = 'Enabled',

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Set this notification status.")]
    [ValidateSet('Enabled', 'Disabled')]
    [string] $NotificationSettings = 'Disabled',

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Time in minutes..")]
    [ValidateRange(1, 60)] #TODO: validate this is right??
    [int] $TimeInIMinutes = 15,

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Url to send notification to.")]
    [string] $ShutdownNotificationUrl = "https://mywebook.com",

    [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Email to send notification to.")]
    [string] $EmailRecipient = "someone@somewhere.com",

    [parameter(Mandatory=$false,HelpMessage="Run the command in a separate job.")]
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
YOUR ARM TEMPLATE GOES HERE
"@  | DeployVm -vm $v -AsJob $AsJob -Parameters $Params
     }
    } catch {
      Write-Error -ErrorRecord $_ -EA $callerEA
    }
  }
  end {}
}
```
8. Update [ScenarioAllFeatures.ps1](Scenarios/ScenarioAllFeatures.ps1) so that your feature goes into our automation test