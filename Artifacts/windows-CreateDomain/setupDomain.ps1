Param(
  [string]$DomainName = 'contoso',
  [string]$DoaminFQDN = 'contoso.com',
  [string]$SafeModePW = 'P@ssw0rd'
)

cd $($PSScriptRoot)

#Check if System is Domain-Joined
if((gwmi win32_computersystem).partofdomain -eq $false)
{
    #Create new Domain
    Install-windowsfeature AD-domain-services
    Import-Module ADDSDeployment
    Install-ADDSForest -CreateDnsDelegation:$false `
 -DatabasePath "C:\Windows\NTDS" `
 -DomainMode "Win2012R2" `
 -DomainName $DoaminFQDN `
 -DomainNetbiosName $DomainName `
 -ForestMode "Win2012R2" `
 -InstallDns:$true `
 -LogPath "C:\Windows\NTDS" `
 -NoRebootOnCompletion:$false `
 -SysvolPath "C:\Windows\SYSVOL" `
 -Force:$true `
 -SafeModeAdministratorPassword (ConvertTo-SecureString $SafeModePW –AsPlainText –Force)
 } 