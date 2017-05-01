<#
Creates a self signed certificate and imports it into you Personal and Root stores. 
I used this when setting up a new development site on dev machine.
#>
Param(
    [ValidateNotNullOrEmpty()]
    [string]$dnsName
)


##################################################################################################

#
# Powershell Configurations
#

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.  
$ErrorActionPreference = "Stop"

# Ensure that current process can run scripts. 
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

If(-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    #build up the deploy arguments
    $arguments = "-file `"{0}`"" -f $script:MyInvocation.MyCommand.Path
    
    # Start the new process
    Start-Process powershell.exe -Verb runas -ArgumentList $arguments
    exit
}
else
{
    $pfx = new-SelfSignedCertificate -DnsName $dnsName -CertStoreLocation cert:\LocalMachine\My
    $friendlyName = "SelfSigned-" + $dnsName
    "Using freindly name " + $friendlyName | Write-Host
    $pfx.FriendlyName = $friendlyName    
    $store =  new-object System.Security.Cryptography.X509Certificates.X509Store(
        [System.Security.Cryptography.X509Certificates.StoreName]::Root,
        "localmachine"
    )
    $store.open("MaxAllowed") 
    $store.add($pfx) 
    $store.close()
    Write-Host "Certificate added to the Personal and Root stores succesfully"
}

