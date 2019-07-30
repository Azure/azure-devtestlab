# NOTE:  This uses the Powershell Core (V2) support with Azure functions

# Route Configuration in the Azure Function:
# /subscriptions/{SUBSCRIPTIONID}/resourceGroups/{RESOURCEGROUPNAME}/providers/Microsoft.DevTestLab/labs/{LABNAME}/virtualmachines/{VIRTUALMACHINENAME}

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# We should stop if we find an error
$ErrorActionPreference = "Stop"

# Write to the Azure Functions log stream.
Write-Host "Function to apply the Windows Update artifact on a VM $($Request.Params.VIRTUALMACHINENAME) in lab $($Request.Params.LABNAME) in subscription $($Request.Params.SUBSCRIPTIONID) started processing at $(Get-Date)"

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
if (-not $Request.Params.VIRTUALMACHINENAME) {
    Write-Error "Missing [VIRTUALMACHINENAME] in the Rest API URL"
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

$javascriptToCloseBrowserTab = @'
<script language='javascript' type='text/javascript'>
    // script to close the tab after the page has loaded
    setTimeout(function() {
        var x = confirm('Are you sure you want to close this tab?');
        if (x) {
            window.open('', '_parent', '');
            window.close();
        }
    }, 5000); // 5 seconds
</script>
'@

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
        $vm = Get-AzResource -ResourceGroupName $Request.Params.RESOURCEGROUPNAME -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines' -Name "$($Request.Params.LABNAME)/$($Request.Params.VIRTUALMACHINENAME)" -ODataQuery '$expand=Properties($expand=ComputeVM)' -ApiVersion 2016-05-15
    }
    catch {
        Write-Error "Unable to find the Virtual Machine '$($Request.Params.VIRTUALMACHINENAME)' in Lab '$($Request.Params.LABNAME)'"
    }

    # Confirm the VM is running before applying the artifact
    if ($vm -and $vm.Properties.computeVm.statuses) {
        # Check the VM status, we should find "PowerState/running" if the VM is running
        $running = $vm.Properties.computeVm.statuses | Where-Object {$_.code -match "PowerState/running"}
        if ($running -and $vm.Properties.provisioningState -eq "Succeeded") {
            # The VM is running - let's apply the windows update artifact!

            $properties = @{
                "artifacts" = @(
                    @{
                        "artifactId" = "/subscriptions/$($Request.Params.SUBSCRIPTIONID)/resourceGroups/$($Request.Params.RESOURCEGROUPNAME)/providers/Microsoft.DevTestLab/labs/$($Request.Params.LABNAME)/artifactSources/public repo/artifacts/windows-install-windows-updates"
                    }
                )
            }

            # We fire and forget the request to apply artifacts, we don't want to block the function from completing until the artifact is applied
            Invoke-AzResourceAction `
                -ResourceGroupName $Request.Params.RESOURCEGROUPNAME `
                -Parameters $properties `
                -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines' `
                -ResourceName "$($Request.Params.LABNAME)/$($Request.Params.VIRTUALMACHINENAME)" `
                -Action "applyArtifacts" `
                -ApiVersion 2016-05-15 `
                -Force

            $htmlPageResponse = $htmlPageTemplateResponse.Replace("{JAVASCRIPT}", $javascriptToCloseBrowserTab).Replace("{IMAGEURL}", "https://raw.githubusercontent.com/petehauge/azure-devtestlab/AzureFunctions/samples/DevTestLabs/AzureFunctions/VirtualMachineSuccess.png")
        }
        else {
            # The VM isn't running, should return a different HTML page warning the user
            $htmlPageResponse = $htmlPageTemplateResponse.Replace("{IMAGEURL}", "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/DevTestLabs/AzureFunctions/VirtualMachineNotRunning.png")
        }
    }
    else {
        # Unable to get the status of the VM
        Write-Error "Unable to get the status of the VM $($Request.Params.VIRTUALMACHINENAME) in lab $($Request.Params.LABNAME) in subscription $($Request.Params.SUBSCRIPTIONID)"
    }
}
else {
    Write-Error "Subscription not found, perhaps the service principal doesn't have access?"
}

# Associate values to output bindings by calling 'Push-OutputBinding', return a nicely formatted HTML page (tab) that auto-closes
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    Body = $htmlPageResponse
    ContentType = 'text/html'
    StatusCode = 'OK'
})
