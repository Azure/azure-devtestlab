# Contributing

When contributing to this repository, please first discuss the change you wish to make via issue,
email, or any other method with the owners of this repository before making a change.

## Code Guidelines

1. Put the `ValueFromPipeline` attribute on the parameter you expect to come from the pipeline.
2. Return the correct object from your function (i.e. lab, vm or image) as to enable pipelining.
3. Re-query for the resource you are returning from the function as your function might have changed it, so you likely need the latest one.
4. Use the `begin/process/end` syntax and put `. BeginPreamble` in the `begin` part. This has to do with correct error management. Read the code for details.
5. Use the `foreach` pattern to enable taking multiple objects from the pipeline
6. Use the function below as a template on how to write the function

```Powershell
function New-AzLab {
    [CmdletBinding()]
    param(
      [parameter(Mandatory=$true,HelpMessage="Lab Account to create lab into", ValueFromPipeline=$true)]
      [ValidateNotNullOrEmpty()]
      $LabAccount,
  
      [parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="Name of Lab to create")]
      [ValidateNotNullOrEmpty()]
      $LabName,

      [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Maximum number of users in lab (defaults to 5)")]
      [int]
      $MaxUsers = 5,

      [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Quota of hours x users (defaults to 40)")]
      [int]
      $UsageQuotaInHours = 40,

      [parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, HelpMessage="Access mode for the lab (either Restricted or Open)")]
      [ValidateSet('Restricted', 'Open')]
      [string]
      $UserAccessMode = 'Restricted',

      [parameter(mandatory = $false, ValueFromPipelineByPropertyName = $true)]
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
```

7. Use the `WaitProvisioning` and `WaitPublishing` utility function as in the function above for long running operations.
8. Update [AllFeatures.ps1](Scenarios/AllFeatures.ps1) so that your feature goes into our automation test