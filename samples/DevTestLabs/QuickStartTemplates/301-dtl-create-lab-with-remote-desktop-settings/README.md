# Create a new DevTestLab instance

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2Fsamples%2FDevTestLabs%2FQuickStartTemplates%2F301-dtl-create-lab-with-remote-desktop-settings%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

This template creates a new DevTest Lab with remoted desktop configuration settings.

The effect of setting these properties is that whenever a user clicks the "Connect" button on a Virtual Machine, the resulting generated RDP file will include the appropriate settings.  The available settings are:

**Experience**:  Set the connection speed as a proxy for how much data to send over the network.  The RDP client sends & receives less information when a slower 'speed' is selected.  This is the same setting found in the RDP client (start -> Run, "mstsc", select "Experience" tab)

Experience Level:  Must be an integer from 1 to 7, following this table:
   * 1  -  Modem (56 kbps)
   * 2  -  Low-speed broadband (256kbps – 2 Mbps)
   * 3  -  Satellite (2 Mbps – 16 Mbps with high latency)
   * 4  -  High-speed broadband (2 Mbps – 10 Mbps)
   * 5  -  WAN (10 Mbps or higher with high latency)
   * 6  -  LAN (10 Mbps or higher)
   * 7  -  Detect connection quality automatically

**Remote Desktop Gatway**:  The RDP Gateway settings can be found on the "advanced" tab of the remote desktop client.  To enable the Lab to automatically use the RDP Gatway, just include the correct URL in the `ExtendedProperties`.

Must be a fully qualified name like customrds.eastus.cloudapp.azure.com or an IP address.
