# NOTE:  This uses the Powershell Core (V2) support with Azure functions

# Route Configuration in the Azure Function:
# /subscriptions/{SUBSCRIPTIONID}/resourceGroups/{RESOURCEGROUPNAME}/providers/Microsoft.DevTestLab/labs/{LABNAME}

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# We should stop if we find an error
$ErrorActionPreference = "Stop"

# Write to the Azure Functions log stream.
Write-Host "Function to update the InternalSupport page in lab $($Request.Params.LABNAME) in subscription $($Request.Params.SUBSCRIPTIONID) started processing at $(Get-Date)"

# ---------------------------------------------------
# Confirm that we have valid route parameters and ApplicationSettings have been configured
# ---------------------------------------------------
# NOTE:  $Request.Params is populated via the Route Configuration in the Azure Function automatically by the functions infrastructure.
if (-not $Request.Params.SUBSCRIPTIONID) {
    Write-Error "Missing [SUBSCRIPTIONID] in the Rest API URL"
}
if (-not $Request.Params.RESOURCEGROUPNAME) {
    Write-Error "Missing [RESOURCEGROUPNAME] in the Rest API URL"
}
if (-not $Request.Params.LABNAME) {
    Write-Error "Missing [LABNAME] in the Rest API URL"
}
# NOTE:  $env:<appsettingname> is automatically populated via Application Settings (configuration) in the Azure Function
if (-not $env:ServicePrincipal_AppId) {
    Write-Error "Missing [ServicePrincipal_AppId] in the ApplicationSettings for the Azure Function"
}
if (-not $env:ServicePrincipal_Key) {
    Write-Error "Missing [ServicePrincipal_Key] in the ApplicationSettings for the Azure Function"
}
if (-not $env:ServicePrincipal_Tenant) {
    Write-Error "Missing [ServicePrincipal_Tenant] in the ApplicationSettings for the Azure Function"
}
if (-not $env:AzureFunctionUrl_ApplyUpdates) {
    Write-Error "Missing [AzureFunctionUrl_ApplyUpdates] in the ApplicationSettings for the Azure Function"
}
if (-not $env:AzureFunctionUrl_UpdateSupportPage) {
    Write-Error "Missing [AzureFunctionUrl_UpdateSupportPage] in the ApplicationSettings for the Azure Function"
}
if (-not $env:WindowsUpdateAllowedDays) {
    Write-Error "Missing [WindowsUpdateAllowedDays] in the ApplicationSettings for the Azure Function"
}

$pageTemplate = @'
# Information Page - {LABNAME} !
On this page, you'll find all the information, links & support information for your DevTest Lab envrionment.  You will also see information
about the existing Virtual Machines, Environments.  For any Virtual Machines that haven't been patched recently, there's a button to install
the latest windows updates on that particular virtual machine (the VM must be running!).  To refresh the page with the latest information 
please click the Update button below.

## Available Virtual Machines
{VIRTUALMACHINELIST}

## Support Information
This team lab is primarily self-supported!  Please get in touch with any feedback, 
concerns or help by contacting support < <support@contoso.com> >.

### Page Last Updated on {DATETIME}
<a style='width: 250px; padding: 10px; cursor: pointer; box-shadow: 6px 6px 5px; #999; 
-webkit-box-shadow: 6px 6px 5px #999; -moz-box-shadow: 6px 6px 5px #999; font-weight: bold; 
background: #ffff00; color: #000; border-radius: 10px; border: 1px solid #999; font-size: 150%;' 
type='button' href='{AZUREFUNCTIONURL_UPDATESUPPORTPAGE}' target='_blank'>Update Support Page</a>
<p></p>
<p></p>
'@

$virtualMachineTableTemplate = @'
Name | OS | Owner | Installed Artifacts | Updates
--- | --- | --- | --- | --- 
{VIRTUALMACHINETABLEROWS}
'@

$virtualMachineButtonTemplate = "<a href='{AZUREFUNCTIONURL_APPLYUPDATES}' target='_blank'>Run Windows Update</a>";

$htmlPageTemplateResponse = @'
<html>
  <head>
    <title>DevTest Lab Extensions</title>
    <link rel='icon shortcut' href='https://azurecomcdn.azureedge.net/cvt-cc7cfb2db134841032aa0a589fb58090be0b25d70fb9a887f22a0d84adf021a9/images/icon/favicon.ico'>
    {JAVASCRIPT}
  </head>
  <body>
    <div>
        <img alt='LabSuccessfullyUpdated.png' src='{IMAGEURL}'>
    </div>
  </body>
</html>
'@

$javascriptToCloseBrowserTab = @'
<script language='javascript' type='text/javascript'>
    // script to close the tab after the page has loaded
    setTimeout(function() {
        var x = confirm('Are you sure you want to close this tab?');
        if (x) {
            window.open('', '_parent', '');
            window.close();
        }
    }, 1000); // 1 second
</script>
'@

$htmlPageTemplateResponse = @'
<html>
  <head>
    <title>DevTest Lab Extensions</title>
    <link rel='icon shortcut' href='https://azurecomcdn.azureedge.net/cvt-cc7cfb2db134841032aa0a589fb58090be0b25d70fb9a887f22a0d84adf021a9/images/icon/favicon.ico'>
    <script language='javascript' type='text/javascript'>
    // script to close the tab after the page has loaded
    setTimeout(function() {
        var x = confirm('Are you sure you want to close this tab?');
        if (x) {
            window.open('', '_parent', '');
            window.close();
        }
    }, 1000); // 1 second
    </script>
  </head>
  <body>
    <div>
        <img alt='LabSuccessfullyUpdated.png' src='https://raw.githubusercontent.com/petehauge/azure-devtestlab/AzureFunctions/samples/DevTestLabs/AzureFunctions/LabSuccessfullyUpdated.png'>
    </div>
  </body>
</html>
'@

# ---------------------------------------------------
# Setup creds and log into Azure
# ---------------------------------------------------
$secpasswd = ConvertTo-SecureString $env:ServicePrincipal_Key -AsPlainText -Force
$pscreds = New-Object System.Management.Automation.PSCredential ($env:ServicePrincipal_AppId, $secpasswd)

# Log into Azure with the service principal
$login = Login-AzAccount -ServicePrincipal -Tenant $env:ServicePrincipal_Tenant -Credential $pscreds

# Make sure we're looking at the right subscription
$sub = Select-AzSubscription -SubscriptionId $Request.Params.SUBSCRIPTIONID

# ---------------------------------------------------
# Confirm subscription and lab exist
# ---------------------------------------------------

if ($sub) {
    # Get the Virtual Machine details
    try {
        $devTestLab = Get-AzResource -ResourceName $Request.Params.LABNAME -ResourceGroupName $Request.Params.RESOURCEGROUPNAME -ResourceType 'Microsoft.DevTestLab/labs' -ApiVersion 2017-04-26-preview
        $vms = Get-AzResource -ResourceGroupName $Request.Params.RESOURCEGROUPNAME -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines' -Name "$($Request.Params.LABNAME)" -ODataQuery '$expand=Properties($expand=Artifacts)' -ApiVersion 2016-05-15
    }
    catch {
        Write-Error "Unable to find Lab $($Request.Params.LABNAME), perhaps the Resource Group '$($Request.Params.RESOURCEGROUPNAME)' or Lab '$($Request.Params.LABNAME)' doesn't exist?"
    }

    # Assemble the table of virtual machines
    if ($vms) {
        $virtualMachineTable = ($vms | ForEach-Object {
            if ($_.Properties.artifacts) {
                $artifacts = ($_.Properties.artifacts | 
                    Sort-Object -Property @{Expression={$_.InstallTime.Length -gt 0}; Descending = $true}, InstallTime |
                    Where-Object {
                        $artifactName = ($_.artifactId.Split("/") | Select -Last 1)
                        $artifactName -ne "windows-install-windows-updates" -and $artifactName -ne "windows-noop"
                    } |
                    ForEach-Object {
                        if ($_.InstallTime) {
                            $artifactInstallTime = (Get-Date $_.InstallTime).ToShortDateString() + ", "
                        }
                        "$($_.artifactId.Split("/") | Select -Last 1)  ($artifactInstallTime$($_.Status))"
                    }) -join "<br/>"

                $latestWindowsUpdateArtifact = $_.Properties.Artifacts |
                    Where-Object {($_.artifactId.Split("/") | Select -Last 1) -eq "windows-install-windows-updates"} |
                    Sort-Object -Property @{Expression="InstallTime"; Descending=$true} |
                    Select -First 1
            }
            else {
                $artifacts = ""
                $latestWindowsUpdateArtifact = $null
            }

            if ($_.Properties.OsType -eq "Linux" -or ($latestWindowsUpdateArtifact -and (Get-Date $latestWindowsUpdateArtifact.InstallTime).AddDays($env:WindowsUpdateAllowedDays) -gt (Get-Date))) {
                $windowsUpdateButton = ""
            }
            else {
                $windowsUpdateButton = $virtualMachineButtonTemplate.Replace("{AZUREFUNCTIONURL_APPLYUPDATES}", ($env:AzureFunctionUrl_ApplyUpdates).Replace("{VIRTUALMACHINENAME}", $_.Name))
            }

            if ($_.Properties.AllowClaim) {
                $owner = "*[ CLAIMABLE ]*"
            }
            else {
                $owner = $_.Properties.OwnerUserPrincipalName
            }

            "$($_.Name) | $($_.Properties.OsType) | $owner | $artifacts | $windowsUpdateButton"
        }) -join "`n"

        $virtualMachineList = $virtualMachineTableTemplate.Replace("{VIRTUALMACHINETABLEROWS}", $virtualMachineTable)
    }
    else {
        $virtualMachineList = "No Virtual Machines"
    }

    $finalMarkdown = $pageTemplate.Replace(
                            "{VIRTUALMACHINELIST}", $virtualMachineList).Replace(
                            "{AZUREFUNCTIONURL_UPDATESUPPORTPAGE}", $env:AzureFunctionUrl_UpdateSupportPage).Replace(
                            "{SUBSCRIPTIONID}", $Request.Params.SUBSCRIPTIONID).Replace(
                            "{RESOURCEGROUPNAME}", $Request.Params.RESOURCEGROUPNAME).Replace(
                            "{LABNAME}", $request.Params.LABNAME).Replace(
                            "{DATETIME}", (Get-Date).ToString())

    $props = $devTestLab.Properties

    if ($props.support -eq $null) {
        $props | Add-Member -Name "support" -Type NoteProperty -value @{enabled = "Enabled";markdown = $finalMarkdown}
    }
    else {
        $props.support.enabled = "Enabled"
        $props.support.markdown = $finalMarkdown
    }

    Set-AzResource -ResourceId $devTestLab.ResourceId -Properties $props -ApiVersion 2017-04-26-preview -Force | Out-Null

}
else {
    Write-Error "Subscription not found, perhaps the service principal doesn't have access?"
}

Write-Host "Request to update the Lab Information has been completed!  You will see updates shortly for Lab: $($Request.Params.LABNAME)"

# Associate values to output bindings by calling 'Push-OutputBinding', return a nicely formatted HTML page (tab) that auto-closes
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    Body = $htmlPageTemplateResponse
    ContentType = 'text/html'
    StatusCode = 'OK'
})
