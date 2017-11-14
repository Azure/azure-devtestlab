[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true)]
    [string] $firewallOperation
)
Write-Output "PowerShell $($PSVersionTable.PSVersion)"
Write-Output "Selected operation: $firewallOperation"
switch ($firewallOperation) {
    "Get Firewall Status" {
        & netsh advfirewall show allprofiles
    }    
    "Enable ICMP (ping)" {  
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
        & netsh advfirewall set allprofiles state on 
    }
    "Disable Firewall" {
        & netsh advfirewall set allprofiles state off
    }
    Default { Write-Output "No operation executed"}

}
if ($LASTEXITCODE -ne 0)
{
    throw 'The artifact failed to apply.'
}
