Param(
  [string]$DomainName = 'contoso',
  [string]$DomainFQDN = 'contoso.com',
  [string]$SafeModePW
)

cd $($PSScriptRoot)

# Check if System is Domain-Joined
if ((gwmi win32_computersystem).partofdomain -eq $false)
{
  #Create new Domain
  Install-windowsfeature AD-domain-services
  Import-Module ADDSDeployment
  Install-ADDSForest -CreateDnsDelegation:$false `
    -DatabasePath "$($env:windir)\NTDS" `
    -DomainMode "Win2012R2" `
    -DomainName $DomainFQDN `
    -DomainNetbiosName $DomainName `
    -ForestMode "Win2012R2" `
    -InstallDns:$true `
    -LogPath "$($env:windir)\NTDS" `
    -NoRebootOnCompletion:$false `
    -SysvolPath "$($env:windir)\SYSVOL" `
    -Force:$true `
    -SafeModeAdministratorPassword (ConvertTo-SecureString $SafeModePW -AsPlainText -Force)
}
