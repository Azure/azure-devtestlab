# Contributing

When contributing to this repository, please first discuss the change you wish to make via issue,
email, or any other method with the owners of this repository before making a change. 

Please note we have a code of conduct, please follow it in all your interactions with the project.

## Coding hints
1. Put the `ValueFromPipeline` attribute on the parameter you expect to come from the pipeline.
1. Return the correct object from your function (i.e. lab, vm or custom image) as to enable pipelining.
2. Re-query for the resource you are returning from the function as your function might have changed it, so you likely need the latest one.
3. Use the `begin/process/end` syntax and put `. BeginPreamble` in the `begin` part. This has to do with correct error management. Read the code for details.
4. Use the `foreach` pattern to enable taking multiple objects from the pipeline
5. Use the function below as a template on how to write the function

```powershell
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
```
6. In the common case you are deploying an ARM template to a lab, use the utility function `DeployLab` as shown below

```powershell
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
      Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction Stop | Out-Null

      $params = @{
        newLabName = $Name
      }

      $Lab = [pscustomobject] @{
        Name = $Name
        ResourceGroupName = $ResourceGroupName
      }
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

```powershell
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
YOUR ARM TEMPLATE
}
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

## Code of Conduct

### Our Pledge

In the interest of fostering an open and welcoming environment, we as
contributors and maintainers pledge to making participation in our project and
our community a harassment-free experience for everyone, regardless of age, body
size, disability, ethnicity, gender identity and expression, level of experience,
nationality, personal appearance, race, religion, or sexual identity and
orientation.

### Our Standards

Examples of behavior that contributes to creating a positive environment
include:

* Using welcoming and inclusive language
* Being respectful of differing viewpoints and experiences
* Gracefully accepting constructive criticism
* Focusing on what is best for the community
* Showing empathy towards other community members

Examples of unacceptable behavior by participants include:

* The use of sexualized language or imagery and unwelcome sexual attention or
advances
* Trolling, insulting/derogatory comments, and personal or political attacks
* Public or private harassment
* Publishing others' private information, such as a physical or electronic
  address, without explicit permission
* Other conduct which could reasonably be considered inappropriate in a
  professional setting

### Our Responsibilities

Project maintainers are responsible for clarifying the standards of acceptable
behavior and are expected to take appropriate and fair corrective action in
response to any instances of unacceptable behavior.

Project maintainers have the right and responsibility to remove, edit, or
reject comments, commits, code, wiki edits, issues, and other contributions
that are not aligned to this Code of Conduct, or to ban temporarily or
permanently any contributor for other behaviors that they deem inappropriate,
threatening, offensive, or harmful.

### Scope

This Code of Conduct applies both within project spaces and in public spaces
when an individual is representing the project or its community. Examples of
representing a project or community include using an official project e-mail
address, posting via an official social media account, or acting as an appointed
representative at an online or offline event. Representation of a project may be
further defined and clarified by project maintainers.

### Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be
reported by contacting the project team at lucabol@microsoft.com. All
complaints will be reviewed and investigated and will result in a response that
is deemed necessary and appropriate to the circumstances. The project team is
obligated to maintain confidentiality with regard to the reporter of an incident.
Further details of specific enforcement policies may be posted separately.

Project maintainers who do not follow or enforce the Code of Conduct in good
faith may face temporary or permanent repercussions as determined by other
members of the project's leadership.

### Attribution

This Code of Conduct is adapted from the [Contributor Covenant][homepage], version 1.4,
available at [http://contributor-covenant.org/version/1/4][version]

[homepage]: http://contributor-covenant.org
[version]: http://contributor-covenant.org/version/1/4/