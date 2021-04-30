# Contributing
Contributions to the PowerShell library are encouraged and welcome!  When contributing to this repository, please first discuss the change you wish to make via issue, email, or any other method with the owners of this repository before making a change.

## Submitting Code
The best way to contribute code to the repository is to create a fork, apply & test your changes in the fork, and then create a pull request to submit the code back to this repository.  Remember these tips for your pull request:
* Include a good title and detailed description on the new contribution or the change
* Sample code (if appropriate) on how others can leveage the new feature/code/change
* Update [AllFeatures.ps1](Scenarios/AllFeatures.ps1) (if applicable) to publish a sample for your change

## Running Tests
We use [Pester](https://pester.dev/) to execute our PowerShell-based tests both locally and in GitHub Actions.  To execute tests for the library:
1. Clone the repository
2. Open a PowerShell window for test execution
3. Ensure that you have Pester installed (we require version 4):
    ```PowerShell
    Install-Module -Name Pester -Force -AllowClobber -RequiredVersion 4.10.1
    ```
2. Change directory to ./samples/ClassroomLabs/Modules/Library/Tests
3. Execute the relevent command:
    ```Powershell
    # To run all the tests from the
    # ./samples/ClassroomLabs/Modules/Library/Tests directory:
    Invoke-Pester *

    # To run just the 'fast' tests:
    Invoke-Pester Fast*
    ```

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

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "User name if shared password is enabled")]
        [string]
        $UserName,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password if shared password is enabled")]
        [string]
        $Password,

        [parameter(mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]
        $LinuxRdpEnabled = $false,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Quota of hours x users (defaults to 40)")]
        [int]
        $UsageQuotaInHours = 40,

        [parameter(mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch]
        $SharedPasswordEnabled = $false 
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
                if ($LinuxRdpEnabled) { $linuxRdpState = 'Enabled' } else { $linuxRdpState = 'Disabled' }

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
                        }
                    } | ConvertTo-Json) | Out-Null

                $lab = WaitProvisioning -uri $labUri -delaySec 60 -retryCount 120
                WaitProvisioning -uri $environmentSettingUri -delaySec 60 -retryCount 120 | Out-Null
                return $lab
            }
        }
        catch {
            Write-Error -ErrorRecord $_ -EA $callerEA
        }
    }
    end { }
}
```

7. Use the `WaitProvisioning` and `WaitPublishing` utility function as in the function above for long running operations.
8. Update [AllFeatures.ps1](Scenarios/AllFeatures.ps1) so that your feature goes into our automation test