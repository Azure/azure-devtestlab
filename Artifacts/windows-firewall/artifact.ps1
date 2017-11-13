[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true)]
    [string] $firewallOperation
)
Write-Output ("Powershell "+$PSVersionTable.PSVersion.Major.ToString()+"."+$PSVersionTable.PSVersion.Minor.ToString()+"."+$PSVersionTable.PSVersion.Build.ToString()+"."+$PSVersionTable.PSVersion.Revision.ToString())
Write-Output "Selected operation: $firewallOperation"
switch ($firewallOperation) {
    "Firewall Status" {
        & netsh advfirewall show allprofiles
    }    
    "Enable ICMP (ping)" {  
        # PS commands work on ly on powershel 5 and higher
        # New-NetFirewallRule -DisplayName "Allow inbound ICMPv4" -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -RemoteAddress any -Action Allow
        # New-NetFirewallRule -DisplayName "Allow inbound ICMPv6" -Direction Inbound -Protocol ICMPv6 -IcmpType 8 -RemoteAddress any -Action Allow        
        & netsh advfirewall firewall add rule name="ICMP Allow incoming V4 echo request" protocol=icmpv4:8,any dir=in action=allow
        & netsh advfirewall firewall add rule name="ICMP Allow incoming V6 echo request" protocol=icmpv6:8,any dir=in action=allow
    }
    "Enable RDP Port (tcp/3389)" {
        & netsh advfirewall firewall add rule name="Allow RDP Connections from anywhere" protocol=tcp localport=3389 remoteip=any dir=in action=allow
    }
    "Enable SSH Port (tcp/22)" {
        & netsh advfirewall firewall add rule name="Allow SSH Connections from anywhere" protocol=tcp localport=22 remoteip=any dir=in action=allow
    }
    "Enable HTTP/HTTPS Port (tcp/80,443)" {
        & netsh advfirewall firewall add rule name="Allow HTTP/HTTPS Connections from anywhere" protocol=tcp localport=80,443 remoteip=any dir=in action=allow
    }
    "Enable Firewall" {
        # PS commands work on ly on powershel 5 and higher
        # Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        & netsh advfirewall set allprofiles state on 
    }
    "Disable Firewall" {
        #Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
        & netsh advfirewall set allprofiles state off
    }
    Default { Write-Output "No operation executed"}
}
