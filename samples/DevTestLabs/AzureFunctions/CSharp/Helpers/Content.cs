using Microsoft.Azure.Management.DevTestLabs.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Rest.Azure;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace AzureFunctions
{
    public class Content
    {
        readonly static string pageTemplate = @"
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
";

        readonly static string virtualMachineTableTemplate = @"Name | OS | Owner | Installed Artifacts | Updates
--- | --- | --- | --- | --- 
{VIRTUALMACHINETABLEROWS}
";
        readonly static string virtualMachineButtonTemplate = "<a href='{AZUREFUNCTIONURL_APPLYUPDATES}' target='_blank'>Run Windows Update</a>";

        readonly internal static string htmlPageTemplateResponse = @"
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
";
        readonly internal static string javascriptToCloseBrowserTab = @"
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
";

        private ILogger Log { get; set; }

        private string FunctionUrl_ApplyUpdates { get; set; }
        private string FunctionUrl_UpdateSupportPage { get; set; }
        private int WindowsUpdateAllowedDays { get; set; }

        private string VirtualMachineTable { get; set; }


        internal string SubscriptionId { get; set; }

        internal string ResourceGroupName { get; set; }

        internal string DevTestLabName { get; set; }

        internal Content(ILogger functionsLog)
        {
            // Save the log for use later
            Log = functionsLog;

            // Initialize our helper library for querying Application Settings
            var settings = new Settings(functionsLog);

            // Get the application settings we need to build the templates, strings & content
            FunctionUrl_ApplyUpdates = settings.GetSetting<string>("AzureFunctionUrl_ApplyUpdates");
            FunctionUrl_UpdateSupportPage = settings.GetSetting<string>("AzureFunctionUrl_UpdateSupportPage");
            WindowsUpdateAllowedDays = settings.GetSetting<int>("WindowsUpdateAllowedDays");

            // Confirm that we were able to get the settings
            if (FunctionUrl_ApplyUpdates == null || FunctionUrl_UpdateSupportPage == null || WindowsUpdateAllowedDays == 0)
            {
                throw new ArgumentException("Unable to retrieve necessary application settings to proceed..");
            }
        }

        internal void AddVirtualMachines(IPage<LabVirtualMachine> virtualMachines)
        {
            StringBuilder VMString = new StringBuilder();

            foreach (var vm in virtualMachines)
            {
                // Information we need for the Virtual Machines: Name, OS, Claimable, Owner, applied artifacts, Needs Windows Updates
                Log.LogInformation($"  ..getting properties for Virtual Machine: '{vm.Name}'");

                // Initialize our variables up front in case we don't have any artifacts on this VM
                string artifactStatus = string.Empty;
                ArtifactInstallProperties latestWindowsUpdateArtifact = null;

                // Use linq to format up a nice list of artifacts, dates & status to include in the markdown
                if (vm.Artifacts != null && vm.Artifacts.Count > 0)
                {
                    artifactStatus = string.Join("<br/>", (from a in vm.Artifacts
                                                               // Exclude Windows Update artifact since it's run multiple times, would make the list too long
                                                           let artifactName = a.ArtifactId.Split('/').Reverse().First()
                                                           where artifactName != "windows-install-windows-updates" &&
                                                           // Exclude the No-Op artifact, it's added automatically by DTL when needed
                                                           artifactName != "windows-noop"
                                                           orderby a.InstallTime.HasValue descending, a.InstallTime // we want "skipped" and "pending" artifacts at the end
                                                           select (a.ArtifactTitle + "  (" + (a.InstallTime.HasValue ? a.InstallTime.Value.ToShortDateString() + ", " : "") +
                                                           a.Status + ")")));

                    latestWindowsUpdateArtifact = (from a in vm.Artifacts
                                                   where a.ArtifactId.Split('/').Reverse().First() == "windows-install-windows-updates"
                                                   orderby a.InstallTime descending
                                                   select a).FirstOrDefault();
                }

                var windowsUpdateButton = string.Empty;
                if (vm.OsType == "Linux" || (latestWindowsUpdateArtifact != null && latestWindowsUpdateArtifact.InstallTime.Value.AddDays(WindowsUpdateAllowedDays) > DateTime.Now))
                {
                    // we make it blank if this VM doesn't need updates
                    windowsUpdateButton = "";
                }
                else
                {
                    // use the button template to format the markdown for this column
                    windowsUpdateButton = virtualMachineButtonTemplate.Replace("{AZUREFUNCTIONURL_APPLYUPDATES}", FunctionUrl_ApplyUpdates.Replace("{VIRTUALMACHINENAME}", vm.Name));
                }

                string ownerColumn = vm.OwnerUserPrincipalName;

                if (vm.AllowClaim.HasValue && vm.AllowClaim.Value)
                {
                    ownerColumn = "*[ CLAIMABLE ]*";
                }

                // Row contents:  Name | OS | Owner | Artifacts | Updates
                VMString.AppendLine($"{vm.Name} | {vm.OsType} | {ownerColumn} | {artifactStatus} | {windowsUpdateButton}");
            }

            VirtualMachineTable = VMString.ToString();
        }

        internal string GetMarkdown()
        {
            string finalSupportMarkdownPage;

            // If we found virtual machines, let's embed them in the markdown file
            if (VirtualMachineTable.Length == 0)
            {
                finalSupportMarkdownPage = pageTemplate.Replace("{VIRTUALMACHINELIST}", "No Virtual Machines");
            }
            else
            {
                finalSupportMarkdownPage = pageTemplate.Replace("{VIRTUALMACHINELIST}",
                virtualMachineTableTemplate.Replace("{VIRTUALMACHINETABLEROWS}", VirtualMachineTable.ToString()));
            }

            // Let's replace in the rest of the variables
            finalSupportMarkdownPage = finalSupportMarkdownPage.Replace("{AZUREFUNCTIONURL_UPDATESUPPORTPAGE}", FunctionUrl_UpdateSupportPage)
                .Replace("{SUBSCRIPTIONID}", SubscriptionId)
                .Replace("{RESOURCEGROUPNAME}", ResourceGroupName)
                .Replace("{LABNAME}", DevTestLabName)
                .Replace("{DATETIME}", DateTime.Now.ToString());

            return finalSupportMarkdownPage;
        }

        internal enum responseType
        {
            LabSuccess,
            VirtualMachineSuccess,
            VirtualMachineNotRunning
        }

        internal static string GetHtmlResponse(responseType response, bool autoCloseTab)
        {
            var imgUrl = string.Empty;

            switch (response)
            {
                case responseType.LabSuccess:
                    imgUrl = "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/DevTestLabs/AzureFunctions/LabSuccessfullyUpdated.png";
                    break;
                case responseType.VirtualMachineSuccess:
                    imgUrl = "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/DevTestLabs/AzureFunctions/VirtualMachineSuccess.png";
                    break;
                case responseType.VirtualMachineNotRunning:
                    imgUrl = "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/DevTestLabs/AzureFunctions/VirtualMachineNotRunning.png";
                    break;
                default:
                    throw new ArgumentException("Invalid value passed to internal GetHtmlResponse method");
            }

            if (autoCloseTab)
            {
                return htmlPageTemplateResponse.Replace("{JAVASCRIPT}", javascriptToCloseBrowserTab).Replace("{IMAGEURL}", imgUrl);
            }
            else
            {
                return htmlPageTemplateResponse.Replace("{JAVASCRIPT}", "").Replace("{IMAGEURL}", imgUrl);
            }
        }
    }
}
