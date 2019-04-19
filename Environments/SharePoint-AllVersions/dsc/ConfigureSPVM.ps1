configuration ConfigureSPVM
{
    param
    (
        [Parameter(Mandatory)] [String]$DNSServer,
        [Parameter(Mandatory)] [String]$DomainFQDN,
        [Parameter(Mandatory)] [String]$DCName,
        [Parameter(Mandatory)] [String]$SQLName,
        [Parameter(Mandatory)] [String]$SQLAlias,
        [Parameter(Mandatory)] [String]$SharePointVersion,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$DomainAdminCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPSetupCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPFarmCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPAppPoolCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPPassphraseCreds
    )

    Import-DscResource -ModuleName ComputerManagementDsc, StorageDsc, NetworkingDsc, xActiveDirectory, xCredSSP, xWebAdministration, SharePointDsc, xPSDesiredStateConfiguration, xDnsServer, CertificateDsc, SqlServerDsc, xPendingReboot

    [String] $DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN)
    $Interface = Get-NetAdapter| Where-Object Name -Like "Ethernet*"| Select-Object -First 1
    $InterfaceAlias = $($Interface.Name)
    [System.Management.Automation.PSCredential] $DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)
    [System.Management.Automation.PSCredential] $SPSetupCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)
    [System.Management.Automation.PSCredential] $SPFarmCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPFarmCreds.UserName)", $SPFarmCreds.Password)
    [System.Management.Automation.PSCredential] $SPAppPoolCredsQualified = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPAppPoolCreds.UserName)", $SPAppPoolCreds.Password)
    [String] $SPDBPrefix = "SP$($SharePointVersion)_"
    [String] $SPTrustedSitesName = "SPSites$SharePointVersion"
    [Int] $RetryCount = 30
    [Int] $RetryIntervalSec = 30
    [String] $ComputerName = Get-Content env:computername
    #[String] $ServiceAppPoolName = "SharePoint Service Applications"
    [String] $SetupPath = "C:\Setup"
    [String] $DCSetupPath = "\\$DCName\C$\Setup"

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        #**********************************************************
        # Initialization of VM
        #**********************************************************
        WindowsFeature ADTools  { Name = "RSAT-AD-Tools";      Ensure = "Present"; }
        WindowsFeature ADPS     { Name = "RSAT-AD-PowerShell"; Ensure = "Present"; }
        WindowsFeature DnsTools { Name = "RSAT-DNS-Server";    Ensure = "Present"; }
        DnsServerAddress DnsServerAddress { Address = $DNSServer; InterfaceAlias = $InterfaceAlias; AddressFamily  = 'IPv4'; DependsOn ="[WindowsFeature]ADPS" }
        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server"; DependsOn = "[DnsServerAddress]DnsServerAddress" }
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = "*.$DomainFQDN", "localhost"; DependsOn = "[xCredSSP]CredSSPServer" }

        # Properly enable TLS 1.2 as documented in https://docs.microsoft.com/en-us/azure/active-directory/manage-apps/application-proxy-add-on-premises-application
        # It's a best practice, and mandatory with Windows 2012 R2 (SharePoint 2013) to allow xRemoteFile to download releases from GitHub: https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/405           
        Registry EnableTLS12RegKey1
        {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
            ValueName = 'DisabledByDefault'
            ValueType = 'Dword'
            ValueData =  '0'
            Ensure    = 'Present'
        }

        Registry EnableTLS12RegKey2
        {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
            ValueName = 'Enabled'
            ValueType = 'Dword'
            ValueData =  '1'
            Ensure    = 'Present'
        }

        Registry EnableTLS12RegKey3
        {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'DisabledByDefault'
            ValueType = 'Dword'
            ValueData =  '0'
            Ensure    = 'Present'
        }

        Registry EnableTLS12RegKey4
        {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
            ValueName = 'Enabled'
            ValueType = 'Dword'
            ValueData =  '1'
            Ensure    = 'Present'
        }

        Registry SchUseStrongCrypto
        {
            Key       = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
            ValueName = 'SchUseStrongCrypto'
            ValueType = 'Dword'
            ValueData =  '1'
            Ensure    = 'Present'
        }

        <#Registry SchUseStrongCrypto64
        {
            Key                         = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
            ValueName                   = 'SchUseStrongCrypto'
            ValueType                   = 'Dword'
            ValueData                   =  '1'
            Ensure                      = 'Present'
        }#>

        #**********************************************************
        # Join AD forest
        #**********************************************************
        xWaitForADDomain DscForestWait
        {
            DomainName           = $DomainFQDN
            RetryCount           = $RetryCount
            RetryIntervalSec     = $RetryIntervalSec
            DomainUserCredential = $DomainAdminCredsQualified
            DependsOn            = "[xCredSSP]CredSSPClient"
        }

        Computer DomainJoin
        {
            Name       = $ComputerName
            DomainName = $DomainFQDN
            Credential = $DomainAdminCredsQualified
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        xScript CreateWSManSPNsIfNeeded
        {
            SetScript =
            {
                # A few times, deployment failed because of this error:
                # "The WinRM client cannot process the request. A computer policy does not allow the delegation of the user credentials to the target computer because the computer is not trusted."
                # The root cause was that SPNs WSMAN/SP and WSMAN/sp.contoso.local were missing in computer account contoso\SP
                # Those SPNs are created by WSMan when it (re)starts
                # Restarting service causes an error, so creates SPNs manually instead
                # Restart-Service winrm

                # Create SPNs WSMAN/SP and WSMAN/sp.contoso.local
                $domainFQDN = $using:DomainFQDN
                $computerName = $using:ComputerName
                Write-Verbose -Message "Adding SPNs 'WSMAN/$computerName' and 'WSMAN/$computerName.$domainFQDN' to computer '$computerName'"
                setspn.exe -S "WSMAN/$computerName" "$computerName"
                setspn.exe -S "WSMAN/$computerName.$domainFQDN" "$computerName"
            }
            GetScript = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript = 
            {
                $computerName = $using:ComputerName
                $samAccountName = "$computerName$"
                if ((Get-ADComputer -Filter {(SamAccountName -eq $samAccountName)} -Property serviceprincipalname | Select-Object serviceprincipalname | Where-Object {$_.ServicePrincipalName -like "WSMAN/$computerName"}) -ne $null) {
                    # SPN is present
                    return $true
                }
                else {
                    # SPN is missing and must be created
                    return $false
                }
            }
            DependsOn = "[Computer]DomainJoin"
        }

        #**********************************************************
        # Do some cleanup and preparation for SharePoint
        #**********************************************************
        Registry DisableLoopBackCheck
        {
            Key       = "HKLM:\System\CurrentControlSet\Control\Lsa"
            ValueName = "DisableLoopbackCheck"
            ValueData = "1"
            ValueType = "Dword"
            Ensure    = "Present"
            DependsOn ="[Computer]DomainJoin"
        }

        xDnsRecord AddTrustedSiteDNS
        {
            Name                 = $SPTrustedSitesName
            Zone                 = $DomainFQDN
            DnsServer            = $DCName
            Target               = "$ComputerName.$DomainFQDN"
            Type                 = "CName"
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[Computer]DomainJoin"
        }

        xWebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent"; DependsOn = "[Computer]DomainJoin"}
        xWebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent"; DependsOn = "[Computer]DomainJoin"}
        xWebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; DependsOn = "[Computer]DomainJoin"}
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; DependsOn = "[Computer]DomainJoin"}
        xWebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent"; DependsOn = "[Computer]DomainJoin"}
        xWebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent"; DependsOn = "[Computer]DomainJoin"}
        xWebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; DependsOn = "[Computer]DomainJoin"}

        #**********************************************************
        # Provision required accounts for SharePoint
        #**********************************************************
        xADUser CreateSPSetupAccount
        {
            DomainName                    = $DomainFQDN
            UserName                      = $SPSetupCreds.UserName
            Password                      = $SPSetupCreds
            PasswordNeverExpires          = $true
            Ensure                        = "Present"
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DependsOn                     = "[Computer]DomainJoin"
        }        

        xADUser CreateSParmAccount
        {
            DomainName                    = $DomainFQDN
            UserName                      = $SPFarmCreds.UserName
            Password                      = $SPFarmCreds
            PasswordNeverExpires          = $true
            Ensure                        = "Present"
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DependsOn                     = "[Computer]DomainJoin"
        }

        Group AddSPSetupAccountToAdminGroup
        {
            GroupName            = "Administrators"
            Ensure               = "Present"
            MembersToInclude     = @("$($SPSetupCredsQualified.UserName)")
            Credential           = $DomainAdminCredsQualified
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[xADUser]CreateSPSetupAccount", "[xADUser]CreateSParmAccount"
        }

        xADUser CreateSPAppPoolAccount
        {
            DomainName                    = $DomainFQDN
            UserName                      = $SPAppPoolCreds.UserName
            Password                      = $SPAppPoolCreds
            PasswordNeverExpires          = $true
            Ensure                        = "Present"
            DomainAdministratorCredential = $DomainAdminCredsQualified
            DependsOn                     = "[Computer]DomainJoin"
        }

        File AccountsProvisioned
        {
            DestinationPath      = "C:\Logs\DSC1.txt"
            Contents             = "AccountsProvisioned"
            Type                 = 'File'
            Force                = $true
            PsDscRunAsCredential = $SPSetupCredential
            DependsOn            = "[Group]AddSPSetupAccountToAdminGroup", "[xADUser]CreateSParmAccount", "[xADUser]CreateSPAppPoolAccount"
        }

        #****************************************************************
        # Copy solutions and certificates that will be used in SharePoint
        #****************************************************************
        File CopyCertificatesFromDC
        {
            Ensure          = "Present"
            Type            = "Directory"
            Recurse         = $true
            SourcePath      = "$DCSetupPath"
            DestinationPath = "$SetupPath\Certificates"
            Credential      = $DomainAdminCredsQualified
            DependsOn       = "[File]AccountsProvisioned"
        }

        SqlAlias AddSqlAlias
        {
            Ensure               = "Present"
            Name                 = $SQLAlias
            ServerName           = $SQLName
            Protocol             = "TCP"
            TcpPort              = 1433
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[File]AccountsProvisioned"
        }

        xScript WaitForSQL
        {
            SetScript =
            {
                $retrySleep = $using:RetryIntervalSec
                $server = $using:SQLAlias
                $db="master"
                $retry = $true
                while ($retry) {
                    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection "Data Source=$server;Initial Catalog=$db;Integrated Security=True;Enlist=False;Connect Timeout=3"
                    try {
                        $sqlConnection.Open()
                        Write-Verbose "Connection to SQL Server $server succeeded"
                        $sqlConnection.Close()
                        $retry = $false
                    }
                    catch {
                        Write-Verbose "SQL connection to $server failed, retry in $retrySleep secs..."
                        Start-Sleep -s $retrySleep
                    }
                }
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[SqlAlias]AddSqlAlias"
        }

        #**********************************************************
        # Create SharePoint farm
        #**********************************************************
        SPFarm CreateSPFarm
        {
            DatabaseServer            = $SQLAlias
            FarmConfigDatabaseName    = $SPDBPrefix + "Config"
            Passphrase                = $SPPassphraseCreds
            FarmAccount               = $SPFarmCredsQualified
            PsDscRunAsCredential      = $SPSetupCredsQualified
            AdminContentDatabaseName  = $SPDBPrefix + "AdminContent"
            CentralAdministrationPort = 5000
            # If RunCentralAdmin is false and configdb does not exist, SPFarm checks during 30 mins if configdb got created and joins the farm
            RunCentralAdmin           = $true
            IsSingleInstance          = "Yes"
            Ensure                    = "Present"
            DependsOn                 = "[xScript]WaitForSQL"
        }

        SPManagedAccount CreateSPAppPoolManagedAccount
        {
            AccountName          = $SPAppPoolCredsQualified.UserName
            Account              = $SPAppPoolCredsQualified
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        # SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
        # {
        #     LogPath              = "C:\ULS"
        #     LogSpaceInGB         = 20
        #     IsSingleInstance     = "Yes"
        #     PsDscRunAsCredential = $SPSetupCredsQualified
        #     DependsOn            = "[SPFarm]CreateSPFarm"
        # }

        SPTrustedIdentityTokenIssuer CreateSPTrust
        {
            Name                         = $DomainFQDN
            Description                  = "Federation with $DomainFQDN"
            Realm                        = "urn:federation:sharepoint"
            SignInUrl                    = "https://adfs.$DomainFQDN/adfs/ls/"
            IdentifierClaim              = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
            ClaimsMappings               = @(
                MSFT_SPClaimTypeMapping{
                    Name = "Email"
                    IncomingClaimType = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
                }
                MSFT_SPClaimTypeMapping{
                    Name = "Role"
                    IncomingClaimType = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
                }
            )
            SigningCertificateFilePath   = "$SetupPath\Certificates\ADFS Signing.cer"
            ClaimProviderName            = ""
            #ProviderSignOutUri          = "https://adfs.$DomainFQDN/adfs/ls/"
            UseWReplyParameter           = $true
            Ensure                       = "Present"
            DependsOn                    = "[SPFarm]CreateSPFarm"
            PsDscRunAsCredential         = $SPSetupCredsQualified
        }

        SPWebApplication MainWebApp
        {
            Name                   = "SharePoint - 80"
            ApplicationPool        = "SharePoint - 80"
            ApplicationPoolAccount = $SPAppPoolCredsQualified.UserName
            AllowAnonymous         = $false
            DatabaseName           = $SPDBPrefix + "Content_80"
            WebAppUrl              = "http://$SPTrustedSitesName/"
            Port                   = 80
            Ensure                 = "Present"
            PsDscRunAsCredential   = $SPSetupCredsQualified
            DependsOn              = "[SPFarm]CreateSPFarm"
        }

        # Update GPO to ensure the root certificate of the CA is present in "cert:\LocalMachine\Root\" before issuing a certificate request, otherwise request would fail
        xScript UpdateGPOToTrustRootCACert
        {
            SetScript =
            {
                gpupdate.exe /force
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false }
            DependsOn            = "[Computer]DomainJoin"
            PsDscRunAsCredential = $DomainAdminCredsQualified
        }

        CertReq SPSSiteCert
        {
            CARootName             = "$DomainNetbiosName-$DCName-CA"
            CAServerFQDN           = "$DCName.$DomainFQDN"
            Subject                = "$SPTrustedSitesName.$DomainFQDN"
            SubjectAltName         = "dns=*.$DomainFQDN"
            KeyLength              = '2048'
            Exportable             = $true
            ProviderName           = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                    = '1.3.6.1.5.5.7.3.1'
            KeyUsage               = '0xa0'
            CertificateTemplate    = 'WebServer'
            AutoRenew              = $true
            Credential             = $DomainAdminCredsQualified
            DependsOn              = '[xScript]UpdateGPOToTrustRootCACert'
        }

        SPWebApplicationExtension ExtendWebApp
        {
            WebAppUrl              = "http://$SPTrustedSitesName/"
            Name                   = "SharePoint - 443"
            AllowAnonymous         = $false
            Url                    = "https://$SPTrustedSitesName.$DomainFQDN"
            Zone                   = "Intranet"
            UseSSL                 = $true
            Port                   = 443
            Ensure                 = "Present"
            PsDscRunAsCredential   = $SPSetupCredsQualified
            DependsOn              = '[CertReq]SPSSiteCert'
        }

        SPWebAppAuthentication ConfigureWebAppAuthentication
        {
            WebAppUrl = "http://$SPTrustedSitesName/"
            Default = @(
                MSFT_SPWebAppAuthenticationMode {
                    AuthenticationMethod = "NTLM"
                }
            )
            Intranet = @(
                MSFT_SPWebAppAuthenticationMode {
                    AuthenticationMethod = "Federated"
                    AuthenticationProvider = $DomainFQDN
                }
            )
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPWebApplicationExtension]ExtendWebApp"
        }

        # Cannot use resource xWebsite in xWebAdministration because CertificateThumbprint is not known yet
        xScript SetHTTPSCertificate
        {
            SetScript =
            {
                $siteCert = Get-ChildItem -Path "cert:\LocalMachine\My\" -DnsName "*.$using:DomainFQDN"

                $website = Get-WebConfiguration -Filter '/system.applicationHost/sites/site' |
                    Where-Object -FilterScript {$_.Name -eq "SharePoint - 443"}

                $properties = @{
                    protocol = "https"
                    bindingInformation = ":443:"
                    certificateStoreName = "MY"
                    certificateHash = $siteCert.Thumbprint
                }

                Clear-WebConfiguration -Filter "$($website.ItemXPath)/bindings" -Force -ErrorAction Stop
                Add-WebConfiguration -Filter "$($website.ItemXPath)/bindings" -Value @{
                    protocol = $properties.protocol
                    bindingInformation = $properties.bindingInformation
                    certificateStoreName = $properties.certificateStoreName
                    certificateHash = $properties.certificateHash
                } -Force -ErrorAction Stop

                if (!(Get-Item IIS:\SslBindings\*!443)) {
                    New-Item IIS:\SslBindings\*!443 -value $siteCert
                }

                <# To implement only when the TestScript will be implemented and will determine that current config must be overwritten
                # Otherwise, assume the right certificate is already used and binding doesn't need to be recreated
                if ((Get-Item IIS:\SslBindings\*!443)) {
                    Remove-Item IIS:\SslBindings\*!443 -Confirm:$false
                }
                New-Item IIS:\SslBindings\*!443 -value $siteCert
                #>
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[SPWebAppAuthentication]ConfigureWebAppAuthentication"
        }

        # Creating site collection in SharePoint 2019 fail: https://github.com/PowerShell/SharePointDsc/issues/990
        # The workaround is to force a reboot before creating it
        if ($SharePointVersion -eq "2019") {
            xScript SetRebootIfFirstTime
            {
                # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
                TestScript = {
                    return (Test-Path HKLM:\SOFTWARE\SPDSCConfigForceRebootKey\RebootRequested)
                }
                SetScript = {
                    New-Item -Path HKLM:\SOFTWARE\SPDSCConfigForceRebootKey\RebootRequested -Force
                    $global:DSCMachineStatus = 1
                }
                GetScript = { }
                PsDscRunAsCredential = $SPSetupCredsQualified
                DependsOn = "[SPWebApplication]MainWebApp"
            }

            xPendingReboot RebootBeforeCreatingSPSite
            {
                Name             = "BeforeCreatingSPTrust"
                SkipCcmClientSDK = $true
                DependsOn        = "[xScript]SetRebootIfFirstTime"
            }
        }

        SPSite RootTeamSite
        {
            Url                  = "http://$SPTrustedSitesName/"
            OwnerAlias           = "i:0#.w|$DomainNetbiosName\$($DomainAdminCreds.UserName)"
            SecondaryOwnerAlias  = "i:05.t|$DomainFQDN|$($DomainAdminCreds.UserName)@$DomainFQDN"
            Name                 = "Blank site"
            Template             = "STS#1"
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPWebApplication]MainWebApp"
        }
    }
}

function Get-NetBIOSName
{
    [OutputType([string])]
    param(
        [string]$DomainFQDN
    )

    if ($DomainFQDN.Contains('.')) {
        $length=$DomainFQDN.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainFQDN.Substring(0,$length)
    }
    else {
        if ($DomainFQDN.Length -gt 15) {
            return $DomainFQDN.Substring(0,15)
        }
        else {
            return $DomainFQDN
        }
    }
}

<#
# Azure DSC extension logging: C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\2.21.0.0
# Azure DSC extension configuration: C:\Packages\Plugins\Microsoft.Powershell.DSC\2.21.0.0\DSCWork

Install-Module -Name xPendingReboot
help ConfigureSPVM

$DomainAdminCreds = Get-Credential -Credential "yvand"
$SPSetupCreds = Get-Credential -Credential "spsetup"
$SPFarmCreds = Get-Credential -Credential "spfarm"
$SPAppPoolCreds = Get-Credential -Credential "spapppool"
$SPPassphraseCreds = Get-Credential -Credential "Passphrase"
$DNSServer = "10.0.1.4"
$DomainFQDN = "contoso.local"
$DCName = "DC"
$SQLName = "SQL"
$SQLAlias = "SQLAlias"

$mofPath = "C:\Packages\Plugins\Microsoft.Powershell.DSC\2.77.0.0\DSCWork\ConfigureSPVM.0\ConfigureSPVM"
ConfigureSPVM -DomainAdminCreds $DomainAdminCreds -SPSetupCreds $SPSetupCreds -SPFarmCreds $SPFarmCreds -SPAppPoolCreds $SPAppPoolCreds -SPPassphraseCreds $SPPassphraseCreds -DNSServer $DNSServer -DomainFQDN $DomainFQDN -DCName $DCName -SQLName $SQLName -SQLAlias $SQLAlias -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath $mofPath
Set-DscLocalConfigurationManager -Path $mofPath
Start-DscConfiguration -Path $mofPath -Wait -Verbose -Force

#>
