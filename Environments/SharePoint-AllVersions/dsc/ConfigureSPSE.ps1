configuration ConfigureSPVM
{
    param
    (
        [Parameter(Mandatory)] [String]$DNSServerIP,
        [Parameter(Mandatory)] [String]$DomainFQDN,
        [Parameter(Mandatory)] [String]$DCServerName,
        [Parameter(Mandatory)] [String]$SQLServerName,
        [Parameter(Mandatory)] [String]$SQLAlias,
        [Parameter(Mandatory)] [String]$SharePointVersion,
        [Parameter(Mandatory)] [String]$SharePointSitesAuthority,
        [Parameter(Mandatory)] [String]$SharePointCentralAdminPort,
        [Parameter(Mandatory)] [Boolean]$EnableAnalysis,
        [Parameter(Mandatory)] [System.Object[]] $SharePointBits,
        [Parameter(Mandatory)] [Boolean]$ConfigureADFS,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$DomainAdminCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPSetupCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPFarmCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPAppPoolCreds,
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential]$SPPassphraseCreds
    )

    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 9.1.0 # Custom
    Import-DscResource -ModuleName NetworkingDsc -ModuleVersion 9.0.0
    Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion 6.4.0
    Import-DscResource -ModuleName xCredSSP -ModuleVersion 1.4.0
    Import-DscResource -ModuleName WebAdministrationDsc -ModuleVersion 4.1.0
    Import-DscResource -ModuleName SharePointDsc -ModuleVersion 5.5.0
    Import-DscResource -ModuleName DnsServerDsc -ModuleVersion 3.0.0
    Import-DscResource -ModuleName CertificateDsc -ModuleVersion 5.1.0
    Import-DscResource -ModuleName SqlServerDsc -ModuleVersion 16.5.0
    Import-DscResource -ModuleName cChoco -ModuleVersion 2.6.0.0    # With custom changes to implement retry on package downloads
    Import-DscResource -ModuleName StorageDsc -ModuleVersion 5.1.0
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.1.0
    
    # Init
    [String] $InterfaceAlias = (Get-NetAdapter | Where-Object Name -Like "Ethernet*" | Select-Object -First 1).Name
    [String] $ComputerName = Get-Content env:computername
    [String] $DomainNetbiosName = (Get-NetBIOSName -DomainFQDN $DomainFQDN)

    # Format credentials to be qualified by domain name: "domain\username"
    [System.Management.Automation.PSCredential] $DomainAdminCredsQualified = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$($DomainAdminCreds.UserName)", $DomainAdminCreds.Password)
    [System.Management.Automation.PSCredential] $SPSetupCredsQualified = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$($SPSetupCreds.UserName)", $SPSetupCreds.Password)
    [System.Management.Automation.PSCredential] $SPFarmCredsQualified = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$($SPFarmCreds.UserName)", $SPFarmCreds.Password)
    [System.Management.Automation.PSCredential] $SPAppPoolCredsQualified = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\$($SPAppPoolCreds.UserName)", $SPAppPoolCreds.Password)
    
    # Setup settings
    [String] $SetupPath = "C:\DSC Data"
    [String] $DCSetupPath = "\\$DCServerName\C$\DSC Data"
    [String] $DscStatusFilePath = "$SetupPath\dsc-status-$ComputerName.log"
    [String] $SharePointBuildLabel = $SharePointVersion.Split("-")[1]
    [String] $SharePointBitsPath = Join-Path -Path $SetupPath -ChildPath "Binaries" #[environment]::GetEnvironmentVariable("temp","machine")
    [String] $SharePointIsoFullPath = Join-Path -Path $SharePointBitsPath -ChildPath "OfficeServer.iso"
    [String] $SharePointIsoDriveLetter = "S"
    [String] $AdfsDnsEntryName = "adfs"

    # SharePoint settings
    [String] $SPDBPrefix = "SPSE_"
    [String] $TrustedIdChar = "e"
    [String] $SPTeamSiteTemplate = "STS#3"
    [String] $AdfsOidcIdentifier = "fae5bd07-be63-4a64-a28c-7931a4ebf62b"
    
    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        Script DscStatus_Start
        {
            SetScript =
            {
                $destinationFolder = $using:SetupPath
                if (!(Test-Path $destinationFolder -PathType Container)) {
                    New-Item -ItemType Directory -Force -Path $destinationFolder
                }
                "$(Get-Date -Format u)`t$($using:ComputerName)`tDSC Configuration starting..." | Out-File -FilePath $using:DscStatusFilePath -Append
            }
            GetScript            = { } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
        }

        #**********************************************************
        # Initialization of VM - Do as much work as possible before waiting on AD domain to be available
        #**********************************************************
        WindowsFeature AddADTools             { Name = "RSAT-AD-Tools";      Ensure = "Present"; }
        WindowsFeature AddADPowerShell        { Name = "RSAT-AD-PowerShell"; Ensure = "Present"; }
        WindowsFeature AddDnsTools            { Name = "RSAT-DNS-Server";    Ensure = "Present"; }
        DnsServerAddress SetDNS { Address = $DNSServerIP; InterfaceAlias = $InterfaceAlias; AddressFamily  = 'IPv4' }

        # xCredSSP is required forSharePointDsc resources SPUserProfileServiceApp and SPDistributedCacheService
        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server"; DependsOn = "[DnsServerAddress]SetDNS" }
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = "*.$DomainFQDN", "localhost"; DependsOn = "[xCredSSP]CredSSPServer" }

        # Allow NTLM on HTTPS sites when site host name is different than the machine name - https://docs.microsoft.com/en-US/troubleshoot/windows-server/networking/accessing-server-locally-with-fqdn-cname-alias-denied
        Registry DisableLoopBackCheck { Key = "HKLM:\System\CurrentControlSet\Control\Lsa"; ValueName = "DisableLoopbackCheck"; ValueData = "1"; ValueType = "Dword"; Ensure = "Present" }

        # Enable TLS 1.2 - https://learn.microsoft.com/en-us/azure/active-directory/app-proxy/application-proxy-add-on-premises-application#tls-requirements
        # This allows xRemoteFile to download releases from GitHub: https://github.com/PowerShell/xPSDesiredStateConfiguration/issues/405
        Registry EnableTLS12RegKey1 { Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'; ValueName = 'DisabledByDefault'; ValueType = 'Dword'; ValueData = '0'; Ensure = 'Present' }
        Registry EnableTLS12RegKey2 { Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'; ValueName = 'Enabled';           ValueType = 'Dword'; ValueData = '1'; Ensure = 'Present' }
        Registry EnableTLS12RegKey3 { Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'; ValueName = 'DisabledByDefault'; ValueType = 'Dword'; ValueData = '0'; Ensure = 'Present' }
        Registry EnableTLS12RegKey4 { Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'; ValueName = 'Enabled';           ValueType = 'Dword'; ValueData = '1'; Ensure = 'Present' }

        # Enable strong crypto by default for .NET Framework 4 applications - https://docs.microsoft.com/en-us/dotnet/framework/network-programming/tls#configuring-security-via-the-windows-registry
        Registry SchUseStrongCrypto         { Key = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319';             ValueName = 'SchUseStrongCrypto';       ValueType = 'Dword'; ValueData = '1'; Ensure = 'Present' }
        Registry SchUseStrongCrypto32       { Key = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'; ValueName = 'SchUseStrongCrypto';       ValueType = 'Dword'; ValueData = '1'; Ensure = 'Present' }
        Registry SystemDefaultTlsVersions   { Key = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319';             ValueName = 'SystemDefaultTlsVersions'; ValueType = 'Dword'; ValueData = '1'; Ensure = 'Present' }
        Registry SystemDefaultTlsVersions32 { Key = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'; ValueName = 'SystemDefaultTlsVersions'; ValueType = 'Dword'; ValueData = '1'; Ensure = 'Present' }

        Registry DisableIESecurityRegKey1 { Key = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}'; ValueName = 'IsInstalled'; ValueType = 'Dword'; ValueData = '0'; Force = $true ; Ensure = 'Present' }
        Registry DisableIESecurityRegKey2 { Key = 'HKLM:\Software\Policies\Microsoft\Internet Explorer\Main'; ValueName = 'DisableFirstRunCustomize'; ValueType = 'Dword'; ValueData = '1'; Force = $true ; Ensure = 'Present' }
        Registry DisableIESecurityRegKey3 { Key = 'HKLM:\Software\Policies\Microsoft\Internet Explorer\TabbedBrowsing'; ValueName = 'NewTabPageShow'; ValueType = 'Dword'; ValueData = '0'; Force = $true ; Ensure = 'Present' }

        # From https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=powershell :
        # Starting in Windows 10, version 1607, MAX_PATH limitations have been removed from common Win32 file and directory functions. However, you must opt-in to the new behavior.
        Registry SetLongPathsEnabled { Key = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; ValueName = "LongPathsEnabled"; ValueType = "DWORD"; ValueData = "1"; Force = $true; Ensure = "Present" }
        
        Registry ShowWindowsExplorerRibbon { Key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; ValueName = "ExplorerRibbonStartsMinimized"; ValueType = "DWORD"; ValueData = "4"; Force = $true; Ensure = "Present" }

        SqlAlias AddSqlAlias { Ensure = "Present"; Name = $SQLAlias; ServerName = $SQLServerName; Protocol = "TCP"; TcpPort= 1433 }
        
        Script EnableFileSharing
        {
            GetScript = { }
            TestScript = { return $null -ne (Get-NetFirewallRule -DisplayGroup "File And Printer Sharing" -Enabled True -ErrorAction SilentlyContinue | Where-Object{$_.Profile -eq "Domain"}) }
            SetScript = { Set-NetFirewallRule -DisplayGroup "File And Printer Sharing" -Enabled True -Profile Domain -Confirm:$false }
        }

        # Create the rules in the firewall required for the distributed cache - https://learn.microsoft.com/en-us/sharepoint/administration/plan-for-feeds-and-the-distributed-cache-service#firewall
        Script CreateFirewallRulesForDistributedCache
        {
            TestScript = {
                # Test if firewall rules already exist
                $icmpRuleName = "File and Printer Sharing (Echo Request - ICMPv4-In)"
                $icmpFirewallRule = Get-NetFirewallRule -DisplayName $icmpRuleName -ErrorAction SilentlyContinue
                $spRuleName = "SharePoint Distributed Cache"
                $firewallRule = Get-NetFirewallRule -DisplayName $spRuleName -ErrorAction SilentlyContinue
                if ($null -eq $icmpFirewallRule -or $null -eq $firewallRule) {
                    return $false   # Run SetScript
                } else {
                    return $true    # Rules already set
                }
            }
            SetScript = {
                $icmpRuleName = "File and Printer Sharing (Echo Request - ICMPv4-In)"
                $icmpFirewallRule = Get-NetFirewallRule -DisplayName $icmpRuleName -ErrorAction SilentlyContinue
                if ($null -eq $icmpFirewallRule) {
                    New-NetFirewallRule -Name Allow_Ping -DisplayName $icmpRuleName `
                        -Description "Allow ICMPv4 ping" `
                        -Protocol ICMPv4 `
                        -IcmpType 8 `
                        -Enabled True `
                        -Profile Any `
                        -Action Allow
                }
                Enable-NetFirewallRule -DisplayName $icmpRuleName

                $spRuleName = "SharePoint Distributed Cache"
                $firewallRule = Get-NetFirewallRule -DisplayName $spRuleName -ErrorAction SilentlyContinue
                if ($null -eq $firewallRule) {
                    New-NetFirewallRule -Name "SPDistCache" `
                        -DisplayName $spRuleName `
                        -Protocol TCP `
                        -LocalPort 22233-22236 `
                        -Group "SharePoint"
                }                
                Enable-NetFirewallRule -DisplayName $spRuleName
            }
            GetScript = { }
        }

        #**********************************************************
        # Install applications using Chocolatey
        #**********************************************************
        Script DscStatus_InstallApps
        {
            SetScript =
            {
                "$(Get-Date -Format u)`t$($using:ComputerName)`tInstall applications..." | Out-File -FilePath $using:DscStatusFilePath -Append
            }
            GetScript            = { } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
        }

        cChocoInstaller InstallChoco
        {
            InstallDir = "C:\Chocolatey"
        }

        cChocoPackageInstaller InstallNotepadpp
        {
            Name                 = "notepadplusplus.install"
            Ensure               = "Present"
            DependsOn            = "[cChocoInstaller]InstallChoco"
        }

        cChocoPackageInstaller Install7zip
        {
            Name                 = "7zip.install"
            Ensure               = "Present"
            DependsOn            = "[cChocoInstaller]InstallChoco"
        }

        cChocoPackageInstaller InstallVscode
        {   # Install takes about 30 secs
            Name                 = "vscode"
            Ensure               = "Present"
            DependsOn            = "[cChocoInstaller]InstallChoco"
        }

        cChocoPackageInstaller InstallAzureDataStudio
        {   # Install takes about 40 secs
            Name                 = "azure-data-studio"
            Ensure               = "Present"
            DependsOn            = "[cChocoInstaller]InstallChoco"
        }

        # if ($EnableAnalysis) {
        #     # This resource is only for analyzing dsc logs using a custom Python script
        #     cChocoPackageInstaller InstallPython
        #     {
        #         Name                 = "python"
        #         Ensure               = "Present"
        #         DependsOn            = "[cChocoInstaller]InstallChoco"
        #     }
        # }

        #**********************************************************
        # Download and install for SharePoint
        #**********************************************************
        Script DscStatus_DownloadSharePoint
        {
            SetScript =
            {
                "$(Get-Date -Format u)`t$($using:ComputerName)`tDownload SharePoint bits and install it..." | Out-File -FilePath $using:DscStatusFilePath -Append
            }
            GetScript            = { } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
        }

        xRemoteFile DownloadSharePoint
        {
            DestinationPath = $SharePointIsoFullPath
            Uri             = ($SharePointBits | Where-Object {$_.Label -eq "RTM"}).Packages[0].DownloadUrl
            ChecksumType    = ($SharePointBits | Where-Object {$_.Label -eq "RTM"}).Packages[0].ChecksumType
            Checksum        = ($SharePointBits | Where-Object {$_.Label -eq "RTM"}).Packages[0].Checksum
            MatchSource     = $false
        }
        
        MountImage MountSharePointImage
        {
            ImagePath   = $SharePointIsoFullPath
            DriveLetter = $SharePointIsoDriveLetter
            DependsOn   = "[xRemoteFile]DownloadSharePoint"
        }
          
        WaitForVolume WaitForSharePointImage
        {
            DriveLetter      = $SharePointIsoDriveLetter
            RetryIntervalSec = 5
            RetryCount       = 10
            DependsOn        = "[MountImage]MountSharePointImage"
        }

        SPInstallPrereqs InstallPrerequisites
        {
            IsSingleInstance  = "Yes"
            InstallerPath     = "$($SharePointIsoDriveLetter):\Prerequisiteinstaller.exe"
            OnlineMode        = $true
            DependsOn         = "[WaitForVolume]WaitForSharePointImage"
        }

        SPInstall InstallBinaries
        {
            IsSingleInstance = "Yes"
            BinaryDir        = "$($SharePointIsoDriveLetter):\"
            ProductKey       = "VW2FM-FN9FT-H22J4-WV9GT-H8VKF"
            DependsOn        = "[SPInstallPrereqs]InstallPrerequisites"
        }

        if ($SharePointBuildLabel -ne "RTM") {
            foreach ($package in ($SharePointBits | Where-Object {$_.Label -eq $SharePointBuildLabel}).Packages) {
                $packageUrl = [uri] $package.DownloadUrl
                $packageFilename = $packageUrl.Segments[$packageUrl.Segments.Count - 1]
                $packageFilePath = Join-Path -Path $SharePointBitsPath -ChildPath $packageFilename
                
                xRemoteFile "DownloadSharePointUpdate_$($SharePointBuildLabel)_$packageFilename"
                {
                    DestinationPath = $packageFilePath
                    Uri             = $packageUrl
                    ChecksumType    = if ($null -ne $package.ChecksumType) { $package.ChecksumType } else { "None" }
                    Checksum        = if ($null -ne $package.Checksum) { $package.Checksum } else { $null }
                    MatchSource     = $false
                }

                Script "InstallSharePointUpdate_$($SharePointBuildLabel)_$packageFilename"
                {
                    SetScript = {
                        $SharePointBuildLabel = $using:SharePointBuildLabel
                        $packageFilePath = $using:packageFilePath
                        $packageFile = Get-ChildItem -Path $packageFilePath
                        
                        $exitRebootCodes = @(3010, 17022)
                        $needReboot = $false
                        Write-Host "Starting installation of SharePoint update '$SharePointBuildLabel', file '$($packageFile.Name)'..."
                        Unblock-File -Path $packageFile -Confirm:$false
                        $process = Start-Process $packageFile.FullName -ArgumentList '/passive /quiet /norestart' -PassThru -Wait
                        if ($exitRebootCodes.Contains($process.ExitCode)) {
                            $needReboot = $true
                        }
                        Write-Host "Finished installation of SharePoint update '$($packageFile.Name)'. Exit code: $($process.ExitCode); needReboot: $needReboot"
                        New-Item -Path "HKLM:\SOFTWARE\DscScriptExecution\flag_spupdate_$($SharePointBuildLabel)_$($packageFile.Name)" -Force
                        Write-Host "Finished installation of SharePoint build '$SharePointBuildLabel'. needReboot: $needReboot"

                        if ($true -eq $needReboot) {
                            $global:DSCMachineStatus = 1
                        }
                    }
                    TestScript = {
                        $SharePointBuildLabel = $using:SharePointBuildLabel
                        $packageFilePath = $using:packageFilePath
                        $packageFile = Get-ChildItem -Path $packageFilePath
                        return (Test-Path "HKLM:\SOFTWARE\DscScriptExecution\flag_spupdate_$($SharePointBuildLabel)_$($packageFile.Name)")
                    }
                    GetScript = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
                    DependsOn        = "[SPInstall]InstallBinaries"
                }

                # SPProductUpdate "InstallSharePointUpdate_$($SharePointBuildLabel)_$packageFilename"
                # {
                #     SetupFile            = $packageFilePath
                #     Ensure               = "Present"
                #     DependsOn            = "[SPInstall]InstallBinaries"
                #     # PsDscRunAsCredential = $SetupAccount
                # }

                PendingReboot "RebootOnSignalFromInstallSharePointUpdate_$($SharePointBuildLabel)_$packageFilename"
                {
                    Name             = "RebootOnSignalFromInstallSharePointUpdate_$($SharePointBuildLabel)_$packageFilename"
                    SkipCcmClientSDK = $true
                    DependsOn        = "[Script]InstallSharePointUpdate_$($SharePointBuildLabel)_$packageFilename"
                }
            }
        }

        # IIS cleanup cannot be executed earlier in SharePoint SE: It uses a base image of Windows Server without IIS (installed by SPInstallPrereqs)
        WebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent"; }
        WebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent"; }
        WebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; }
        WebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; }
        WebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent"; }
        WebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent"; }
        WebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; }

        #**********************************************************
        # Join AD forest
        #**********************************************************
        
        Script DscStatus_WaitForDCReady
        {
            SetScript =
            {
                "$(Get-Date -Format u)`t$($using:ComputerName)`tWait for AD DC to be ready..." | Out-File -FilePath $using:DscStatusFilePath -Append
            }
            GetScript            = { } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
        }
        
        # DNS record for ADFS is created only after the ADFS farm was created and DC restarted (required by ADFS setup)
        # This turns out to be a very reliable way to ensure that VM joins AD only when the DC is guaranteed to be ready
        # This totally eliminates the random errors that occured in WaitForADDomain with the previous logic (and no more need of WaitForADDomain)
        Script WaitForADFSFarmReady
        {
            SetScript =
            {
                $dnsRecordFQDN = "$($using:AdfsDnsEntryName).$($using:DomainFQDN)"
                $dnsRecordFound = $false
                $sleepTime = 15
                do {
                    try {
                        [Net.DNS]::GetHostEntry($dnsRecordFQDN)
                        $dnsRecordFound = $true
                    }
                    catch [System.Net.Sockets.SocketException] {
                        # GetHostEntry() throws SocketException "No such host is known" if DNS entry is not found
                        Write-Host "DNS record '$dnsRecordFQDN' not found yet: $_"
                        Start-Sleep -Seconds $sleepTime
                    }
                } while ($false -eq $dnsRecordFound)
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { try { [Net.DNS]::GetHostEntry("$($using:AdfsDnsEntryName).$($using:DomainFQDN)"); return $true } catch { return $false } }
            DependsOn            = "[DnsServerAddress]SetDNS"
        }

        # # If WaitForADDomain does not find the domain whtin "WaitTimeout" secs, it will signal a restart to DSC engine "RestartCount" times
        # WaitForADDomain WaitForDCReady
        # {
        #     DomainName              = $DomainFQDN
        #     WaitTimeout             = 1800
        #     RestartCount            = 2
        #     WaitForValidCredentials = $True
        #     Credential              = $DomainAdminCredsQualified
        #     DependsOn               = "[Script]WaitForADFSFarmReady"
        # }

        # # WaitForADDomain sets reboot signal only if WaitForADDomain did not find domain within "WaitTimeout" secs
        # PendingReboot RebootOnSignalFromWaitForDCReady
        # {
        #     Name             = "RebootOnSignalFromWaitForDCReady"
        #     SkipCcmClientSDK = $true
        #     DependsOn        = "[WaitForADDomain]WaitForDCReady"
        # }

        Computer JoinDomain
        {
            Name       = $ComputerName
            DomainName = $DomainFQDN
            Credential = $DomainAdminCredsQualified
            DependsOn  = "[Script]WaitForADFSFarmReady"
        }

        PendingReboot RebootOnSignalFromJoinDomain
        {
            Name             = "RebootOnSignalFromJoinDomain"
            SkipCcmClientSDK = $true
            DependsOn        = "[Computer]JoinDomain"
        }

        Registry ShowFileExtensions { Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; ValueName = "HideFileExt"; ValueType = "DWORD"; ValueData = "0"; Force = $true; Ensure = "Present"; PsDscRunAsCredential = $DomainAdminCredsQualified }

        # This script is still needed
        Script CreateWSManSPNsIfNeeded
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
                Write-Host "Adding SPNs 'WSMAN/$computerName' and 'WSMAN/$computerName.$domainFQDN' to computer '$computerName'"
                setspn.exe -S "WSMAN/$computerName" "$computerName"
                setspn.exe -S "WSMAN/$computerName.$domainFQDN" "$computerName"
            }
            GetScript = { }
            # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
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
            DependsOn = "[PendingReboot]RebootOnSignalFromJoinDomain"
        }

        #**********************************************************
        # Do SharePoint pre-reqs that require membership in AD domain
        #**********************************************************
        # Create DNS entries used by SharePoint
        DnsRecordCname AddTrustedSiteDNS
        {
            Name                 = $SharePointSitesAuthority
            ZoneName             = $DomainFQDN
            DnsServer            = $DCServerName
            HostNameAlias        = "$ComputerName.$DomainFQDN"
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[PendingReboot]RebootOnSignalFromJoinDomain"
        }

        #**********************************************************
        # Provision required accounts for SharePoint
        #**********************************************************
        ADUser CreateSPSetupAccount
        {   # Both SQL and SharePoint DSCs run this SPSetupAccount AD account creation
            DomainName           = $DomainFQDN
            UserName             = $SPSetupCreds.UserName
            UserPrincipalName    = "$($SPSetupCreds.UserName)@$DomainFQDN"
            Password             = $SPSetupCreds
            PasswordNeverExpires = $true
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[PendingReboot]RebootOnSignalFromJoinDomain"
        }

        ADUser CreateSParmAccount
        {
            DomainName                    = $DomainFQDN
            UserName                      = $SPFarmCreds.UserName
            UserPrincipalName             = "$($SPFarmCreds.UserName)@$DomainFQDN"
            Password                      = $SPFarmCreds
            PasswordNeverExpires          = $true
            Ensure                        = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn                     = "[PendingReboot]RebootOnSignalFromJoinDomain"
        }

        Group AddSPSetupAccountToAdminGroup
        {
            GroupName            = "Administrators"
            Ensure               = "Present"
            MembersToInclude     = @("$($SPSetupCredsQualified.UserName)")
            Credential           = $DomainAdminCredsQualified
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[ADUser]CreateSPSetupAccount"
        }

        ADUser CreateSPAppPoolAccount
        {
            DomainName                    = $DomainFQDN
            UserName                      = $SPAppPoolCreds.UserName
            UserPrincipalName             = "$($SPAppPoolCreds.UserName)@$DomainFQDN"
            Password                      = $SPAppPoolCreds
            PasswordNeverExpires          = $true
            Ensure                        = "Present"
            PsDscRunAsCredential          = $DomainAdminCredsQualified
            DependsOn                     = "[PendingReboot]RebootOnSignalFromJoinDomain"
        }

        # Since this DSC may run on multiple SP servers, each with a diferent SPN (spsites201x), SPN cannot be set in ADUser.ServicePrincipalNames because each config removes the SPNs of the previous one
        ADServicePrincipalName SetSPAppPoolSPN1
        {
            ServicePrincipalName = "HTTP/$SharePointSitesAuthority.$DomainFQDN"
            Account              = $SPAppPoolCreds.UserName
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[ADUser]CreateSPAppPoolAccount"
        }

        ADServicePrincipalName SetSPAppPoolSPN2
        {
            ServicePrincipalName = "HTTP/$SharePointSitesAuthority"
            Account              = $SPAppPoolCreds.UserName
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[ADUser]CreateSPAppPoolAccount"
        }

        # Fiddler must be installed as $DomainAdminCredsQualified because it's a per-user installation
        cChocoPackageInstaller InstallFiddler
        {
            Name                 = "fiddler"
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[cChocoInstaller]InstallChoco", "[PendingReboot]RebootOnSignalFromJoinDomain"
        }

        # Install ULSViewer as $DomainAdminCredsQualified to ensure that the shortcut is visible on the desktop
        cChocoPackageInstaller InstallUlsViewer
        {
            Name                 = "ulsviewer"
            Ensure               = "Present"
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[cChocoInstaller]InstallChoco"
        }

        Script DscStatus_WaitForSQL
        {
            SetScript =
            {
                "$(Get-Date -Format u)`t$($using:ComputerName)`tWait for SQL Server to be ready..." | Out-File -FilePath $using:DscStatusFilePath -Append
            }
            GetScript            = { } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
        }

        Script WaitForSQL
        {
            SetScript =
            {
                $retrySleep = 30
                $server = $using:SQLAlias
                $db = "master"
                $retry = $true
                while ($retry) {
                    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection "Data Source=$server;Initial Catalog=$db;Integrated Security=True;Enlist=False;Connect Timeout=3"
                    try {
                        $sqlConnection.Open()
                        Write-Host "Connection to SQL Server $server succeeded"
                        $sqlConnection.Close()
                        $retry = $false
                    }
                    catch {
                        Write-Host "SQL connection to $server failed, retry in $retrySleep secs..."
                        Start-Sleep -s $retrySleep
                    }
                }
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[SqlAlias]AddSqlAlias", "[Group]AddSPSetupAccountToAdminGroup", "[ADUser]CreateSParmAccount", "[ADUser]CreateSPAppPoolAccount", "[Script]CreateWSManSPNsIfNeeded"
        }

        #**********************************************************
        # Create SharePoint farm
        #**********************************************************
        Script DscStatus_CreateSPFarm
        {
            SetScript =
            {
                "$(Get-Date -Format u)`t$($using:ComputerName)`tCreate SharePoint farm..." | Out-File -FilePath $using:DscStatusFilePath -Append
            }
            GetScript            = { } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
        }

        SPFarm CreateSPFarm
        {
            DatabaseServer            = $SQLAlias
            FarmConfigDatabaseName    = $SPDBPrefix + "Config"
            Passphrase                = $SPPassphraseCreds
            FarmAccount               = $SPFarmCredsQualified
            PsDscRunAsCredential      = $SPSetupCredsQualified
            AdminContentDatabaseName  = $SPDBPrefix + "AdminContent"
            CentralAdministrationPort = $SharePointCentralAdminPort
            # If RunCentralAdmin is false and configdb does not exist, SPFarm checks during 30 mins if configdb got created and joins the farm
            RunCentralAdmin           = $true
            IsSingleInstance          = "Yes"
            SkipRegisterAsDistributedCacheHost = $false
            Ensure                    = "Present"
            DependsOn                 = "[Script]WaitForSQL"
        }

        # Distributed Cache is now enabled directly by the SPFarm resource
        # SPDistributedCacheService EnableDistributedCache
        # {
        #     Name                 = "AppFabricCachingService"
        #     CacheSizeInMB        = 1000 # Default size is 819MB on a server with 16GB of RAM (5%)
        #     CreateFirewallRules  = $true
        #     ServiceAccount       = $SPFarmCredsQualified.UserName
        #     PsDscRunAsCredential       = $SPSetupCredsQualified
        #     Ensure               = "Present"
        #     DependsOn            = "[SPFarm]CreateSPFarm"
        # }

        SPManagedAccount CreateSPAppPoolManagedAccount
        {
            AccountName          = $SPAppPoolCredsQualified.UserName
            Account              = $SPAppPoolCredsQualified
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPWebApplication CreateMainWebApp
        {
            Name                   = "SharePoint - 80"
            ApplicationPool        = "SharePoint - 80"
            ApplicationPoolAccount = $SPAppPoolCredsQualified.UserName
            AllowAnonymous         = $false
            DatabaseName           = $SPDBPrefix + "Content_80"
            WebAppUrl              = "http://$SharePointSitesAuthority/"
            Port                   = 80
            Ensure                 = "Present"
            PsDscRunAsCredential   = $SPSetupCredsQualified
            DependsOn              = "[SPFarm]CreateSPFarm"
        }

        SPShellAdmins AddShellAdmins
        {
            IsSingleInstance = "Yes"
            Members          = @($DomainAdminCredsQualified.UserName)
            Databases        = @(
                @(MSFT_SPDatabasePermissions {
                    Name    = $SPDBPrefix + "Content_80"
                    Members = @($DomainAdminCredsQualified.UserName)
                })
            )
            PsDscRunAsCredential = $SPSetupCredsQualified
            DependsOn            = "[SPWebApplication]CreateMainWebApp"
        }

        Script FixMissingDatabasesPermissions
        {
            SetScript =
            {
                # Fix for slipstream installs with 2022-10 CU or newer: Fix the SharePoint configuration wizard failing at step 9/10, when executed after installing a CU
                # Do this after all databases were created, and just before a new server may join the SharePoint farm
                foreach ($db in Get-SPDatabase) {
                    $db.GrantOwnerAccessToDatabaseAccount()
                }
            }
            GetScript            = { }
            TestScript           = { return $false } # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        if ($ConfigureADFS -eq $true) {
            # Delay this operation significantly, so that DC has time to generate and copy the certificates
            File CopyCertificatesFromDC
            {
                Ensure          = "Present"
                Type            = "Directory"
                Recurse         = $true
                SourcePath      = "$DCSetupPath"
                DestinationPath = "$SetupPath\Certificates"
                Credential      = $DomainAdminCredsQualified
                DependsOn       = "[PendingReboot]RebootOnSignalFromJoinDomain"
            }

            SPTrustedRootAuthority TrustRootCA
            {
                Name                 = "$DomainFQDN root CA"
                CertificateFilePath  = "$SetupPath\Certificates\ADFS Signing issuer.cer"
                Ensure               = "Present"
                PsDscRunAsCredential = $SPSetupCredsQualified
                DependsOn            = "[SPFarm]CreateSPFarm"
            }


            $apppoolUserName = $SPAppPoolCredsQualified.UserName
            $domainAdminUserName = $DomainAdminCredsQualified.UserName
            Script SetFarmPropertiesForOIDC
            {
                SetScript = 
                {
                    $apppoolUserName = $using:apppoolUserName
                    $domainAdminUserName = $using:domainAdminUserName
                    $setupPath = Join-Path -Path $using:SetupPath -ChildPath "Certificates"
                    if (!(Test-Path $setupPath -PathType Container)) {
                        New-Item -ItemType Directory -Force -Path $setupPath
                    }
                    $DCSetupPath = Join-Path -Path $using:DCSetupPath -ChildPath "Certificates"
                    if (!(Test-Path $DCSetupPath -PathType Container)) {
                        New-Item -ItemType Directory -Force -Path $DCSetupPath
                    }
                    
                    # Setup farm properties to work with OIDC
                    # Create a self-signed certificate in 1st SharePoint Server of the farm
                    $cookieCertificateName = "SharePoint OIDC nonce cert"
                    $cookieCertificateFilePath = Join-Path -Path $setupPath -ChildPath "$cookieCertificateName"
                    $cert = New-SelfSignedCertificate -KeyUsage None -KeyUsageProperty None -CertStoreLocation Cert:\LocalMachine\My -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' -Subject "CN=$cookieCertificateName"
                    Export-Certificate -Cert $cert -FilePath "$cookieCertificateFilePath.cer"
                    Export-PfxCertificate -Cert $cert -FilePath "$cookieCertificateFilePath.pfx" -ProtectTo "$domainAdminUserName"
                    Export-PfxCertificate -Cert $cert -FilePath "$DCSetupPath\$cookieCertificateName.pfx" -ProtectTo "$domainAdminUserName"

                    # Grant access to the certificate private key.
                    $rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
                    $fileName = $rsaCert.key.UniqueName
                    $path = "$env:ALLUSERSPROFILE\Microsoft\Crypto\RSA\MachineKeys\$fileName"
                    $permissions = Get-Acl -Path $path
                    $access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule($apppoolUserName, 'Read', 'None', 'None', 'Allow')
                    $permissions.AddAccessRule($access_rule)
                    Set-Acl -Path $path -AclObject $permissions

                    # Set farm properties
                    $f = Get-SPFarm
                    $f.Farm.Properties['SP-NonceCookieCertificateThumbprint'] = $cert.Thumbprint
                    $f.Farm.Properties['SP-NonceCookieHMACSecretKey'] = "randomString$domainAdminUserName"
                    $f.Farm.Update()
                }
                GetScript =  
                {
                    # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
                    return @{ "Result" = "false" }
                }
                TestScript = 
                {
                    # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
                    # Import-Module SharePointServer | Out-Null
                    # $f = Get-SPFarm
                    # if ($f.Farm.Properties.ContainsKey('SP-NonceCookieCertificateThumbprint') -eq $false) {
                    if ((Get-ChildItem -Path "cert:\LocalMachine\My\"| Where-Object{$_.Subject -eq "CN=SharePoint Cookie Cert"}) -eq $null) {
                        return $false
                    }
                    else {
                        return $true
                    }
                }
                DependsOn            = "[SPFarm]CreateSPFarm"
                PsDscRunAsCredential = $DomainAdminCredsQualified
            }

            SPTrustedIdentityTokenIssuer CreateSPTrust
            {
                Name                         = $DomainFQDN
                Description                  = "Federation with $DomainFQDN"
                RegisteredIssuerName         = "https://adfs.$DomainFQDN/adfs"
                AuthorizationEndPointUri     = "https://adfs.$DomainFQDN/adfs/oauth2/authorize"
                SignOutUrl                   = "https://adfs.$DomainFQDN/adfs/oauth2/logout"
                DefaultClientIdentifier      = $AdfsOidcIdentifier
                IdentifierClaim              = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"
                ClaimsMappings               = @(
                    MSFT_SPClaimTypeMapping{
                        Name = "upn"
                        IncomingClaimType = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"
                    }
                    MSFT_SPClaimTypeMapping{
                        Name = "role"
                        IncomingClaimType = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role"
                    }
                )
                SigningCertificateFilePath   = "$SetupPath\Certificates\ADFS Signing.cer"
                UseWReplyParameter           = $true
                Ensure                       = "Present" 
                DependsOn                    = "[Script]SetFarmPropertiesForOIDC"
                PsDscRunAsCredential         = $SPSetupCredsQualified
            }

            # Update GPO to ensure the root certificate of the CA is present in "cert:\LocalMachine\Root\", otherwise certificate request will fail
            Script UpdateGPOToTrustRootCACert
            {
                SetScript =
                {
                    gpupdate.exe /force
                }
                GetScript            = { }
                TestScript           = 
                {
                    $domainNetbiosName = $using:DomainNetbiosName
                    $dcName = $using:DCServerName
                    $rootCAName = "$domainNetbiosName-$dcName-CA"
                    $cert = Get-ChildItem -Path "cert:\LocalMachine\Root\" -DnsName "$rootCAName"
                    
                    if ($null -eq $cert) {
                        return $false   # Run SetScript
                    } else {
                        return $true    # Root CA already present
                    }
                }
                DependsOn            = "[PendingReboot]RebootOnSignalFromJoinDomain"
                PsDscRunAsCredential = $DomainAdminCredsQualified
            }

            SPWebApplicationExtension ExtendMainWebApp
            {
                WebAppUrl              = "http://$SharePointSitesAuthority/"
                Name                   = "SharePoint - 443"
                AllowAnonymous         = $false
                Url                    = "https://$SharePointSitesAuthority.$DomainFQDN"
                Zone                   = "Intranet"
                Port                   = 443
                Ensure                 = "Present"
                PsDscRunAsCredential   = $SPSetupCredsQualified
                DependsOn              = "[SPWebApplication]CreateMainWebApp"
            }

            SPWebAppAuthentication ConfigureMainWebAppAuthentication
            {
                WebAppUrl = "http://$SharePointSitesAuthority/"
                Default = @(
                    MSFT_SPWebAppAuthenticationMode {
                        AuthenticationMethod = "WindowsAuthentication"
                        WindowsAuthMethod    = "NTLM"
                    }
                )
                Intranet = @(
                    MSFT_SPWebAppAuthenticationMode {
                        AuthenticationMethod = "Federated"
                        AuthenticationProvider = $DomainFQDN
                    }
                )
                PsDscRunAsCredential = $SPSetupCredsQualified
                DependsOn            = "[SPWebApplicationExtension]ExtendMainWebApp"
            }

            # Use SharePoint SE to generate the CSR and give the private key so it can manage it
            Script GenerateMainWebAppCertificate
            {
                SetScript =
                {
                    $dcName = $using:DCServerName
                    $domainFQDN = $using:DomainFQDN
                    $domainNetbiosName = $using:DomainNetbiosName
                    $sharePointSitesAuthority = $using:SharePointSitesAuthority
                    $setupPath = Join-Path -Path $using:SetupPath -ChildPath "Certificates"                
                    if (!(Test-Path $setupPath -PathType Container)) {
                        New-Item -ItemType Directory -Force -Path $setupPath
                    }

                    Write-Host "Creating certificate request for CN=$sharePointSitesAuthority.$domainFQDN..."
                    # Generate CSR
                    New-SPCertificate -FriendlyName "$sharePointSitesAuthority Certificate" -KeySize 2048 -CommonName "$sharePointSitesAuthority.$domainFQDN" -AlternativeNames @("*.$domainFQDN") -Organization "$domainNetbiosName" -Exportable -HashAlgorithm SHA256 -Path "$setupPath\$sharePointSitesAuthority.csr"

                    # Submit CSR to CA
                    & certreq.exe -submit -config "$dcName.$domainFQDN\$domainNetbiosName-$dcName-CA" -attrib "CertificateTemplate:Webserver" "$setupPath\$sharePointSitesAuthority.csr" "$setupPath\$sharePointSitesAuthority.cer" "$setupPath\$sharePointSitesAuthority.p7b" "$setupPath\$sharePointSitesAuthority.rsp"

                    # Install certificate with its private key to certificate store
                    # certreq -accept –machine "$setupPath\$sharePointSitesAuthority.cer"

                    # Find the certificate
                    # Get-ChildItem -Path cert:\localMachine\my | Where-Object{ $_.Subject -eq "CN=$sharePointSitesAuthority.$domainFQDN, O=$domainNetbiosName" } | Select-Object Thumbprint

                    # # Export private key of the certificate
                    # certutil -f -p "superpasse" -exportpfx A74D118AABD5B42F23BCD9083D3F6A3EF3BFD904 "$setupPath\$sharePointSitesAuthority.pfx"

                    # # Import private key of the certificate into SharePoint
                    # $password = ConvertTo-SecureString -AsPlainText -Force "<superpasse>"
                    # Import-SPCertificate -Path "$setupPath\$sharePointSitesAuthority.pfx" -Password $password -Exportable
                    Write-Host "Adding certificate 'CN=$sharePointSitesAuthority.$domainFQDN' to SharePoint store EndEntity..."
                    $spCert = Import-SPCertificate -Path "$setupPath\$sharePointSitesAuthority.cer" -Exportable -Store EndEntity

                    Write-Host "Extending web application to HTTPS zone using certificate 'CN=$sharePointSitesAuthority.$domainFQDN'..."
                    Set-SPWebApplication -Identity "http://$sharePointSitesAuthority" -Zone Intranet -Port 443 -Certificate $spCert `
                        -SecureSocketsLayer:$true -AllowLegacyEncryption:$false -Url "https://$sharePointSitesAuthority.$domainFQDN"
                    
                    Write-Host "Finished."
                }
                GetScript            = { }
                TestScript           = 
                {
                    $domainFQDN = $using:DomainFQDN
                    $domainNetbiosName = $using:DomainNetbiosName
                    $sharePointSitesAuthority = $using:SharePointSitesAuthority
                    
                    # $cert = Get-ChildItem -Path cert:\localMachine\my | Where-Object{ $_.Subject -eq "CN=$sharePointSitesAuthority.$domainFQDN, O=$domainNetbiosName" }
                    $cert = Get-SPCertificate -Identity "$sharePointSitesAuthority Certificate" -ErrorAction SilentlyContinue
                    if ($null -eq $cert) {
                        return $false   # Run SetScript
                    } else {
                        return $true    # Certificate is already created
                    }
                }
                DependsOn            = "[Script]UpdateGPOToTrustRootCACert", "[SPWebAppAuthentication]ConfigureMainWebAppAuthentication"
                PsDscRunAsCredential = $DomainAdminCredsQualified
            }

            SPSite CreateRootSite
            {
                Url                  = "http://$SharePointSitesAuthority/"
                OwnerAlias           = "i:0#.w|$DomainNetbiosName\$($DomainAdminCreds.UserName)"
                SecondaryOwnerAlias  = "i:0$TrustedIdChar.t|$DomainFQDN|$($DomainAdminCreds.UserName)@$DomainFQDN"
                Name                 = "Team site"
                Template             = $SPTeamSiteTemplate
                CreateDefaultGroups  = $true
                PsDscRunAsCredential = $SPSetupCredsQualified
                DependsOn            = "[SPWebAppAuthentication]ConfigureMainWebAppAuthentication"
            }
        }
        else {
            SPWebAppAuthentication ConfigureMainWebAppAuthentication
            {
                WebAppUrl = "http://$SharePointSitesAuthority/"
                Default = @(
                    MSFT_SPWebAppAuthenticationMode {
                        AuthenticationMethod = "WindowsAuthentication"
                        WindowsAuthMethod    = "NTLM"
                    }
                )
                PsDscRunAsCredential = $SPSetupCredsQualified
                DependsOn            = "[SPWebApplication]CreateMainWebApp"
            }

            SPSite CreateRootSite
            {
                Url                  = "http://$SharePointSitesAuthority/"
                OwnerAlias           = "i:0#.w|$DomainNetbiosName\$($DomainAdminCreds.UserName)"
                Name                 = "Team site"
                Template             = $SPTeamSiteTemplate
                CreateDefaultGroups  = $true
                PsDscRunAsCredential = $SPSetupCredsQualified
                DependsOn            = "[SPWebAppAuthentication]ConfigureMainWebAppAuthentication"
            }
        }

        Script WarmupSites
        {
            SetScript =
            {
                $warmupJobBlock = {
                    $uri = $args[0]
                    try {
                        Write-Verbose "Connecting to $uri..."
                        # -UseDefaultCredentials: Does NTLM authN
                        # -UseBasicParsing: Avoid exception because IE was not first launched yet
                        # Expected traffic is HTTP 401/302/200, and $Response.StatusCode is 200
                        $Response = Invoke-WebRequest -Uri $uri -UseDefaultCredentials -TimeoutSec 40 -UseBasicParsing -ErrorAction SilentlyContinue
                        Write-Verbose "Connected successfully to $uri"
                    }
                    catch {
                    }
                }
                $spsite = "http://$($using:ComputerName):5000/"
                Write-Verbose "Warming up '$spsite'..."
                $job1 = Start-Job -ScriptBlock $warmupJobBlock -ArgumentList @($spsite)
                $spsite = "http://$($using:SharePointSitesAuthority)/"
                Write-Verbose "Warming up '$spsite'..."
                $job2 = Start-Job -ScriptBlock $warmupJobBlock -ArgumentList @($spsite)
                
                # Must wait for the jobs to complete, otherwise they do not actually run
                Receive-Job -Job $job1 -AutoRemoveJob -Wait
                Receive-Job -Job $job2 -AutoRemoveJob -Wait
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
            PsDscRunAsCredential = $DomainAdminCredsQualified
            DependsOn            = "[SPSite]CreateRootSite"
        }

        Script CreateShortcuts
        {
            SetScript =
            {
                $WshShell = New-Object -comObject WScript.Shell
                # Shortcut to the setup folder
                $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\Setup data.lnk")
                $Shortcut.TargetPath = $using:SetupPath
                $Shortcut.Save()

                # Shortcut for SharePoint Central Administration
                $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\SharePoint Central Administration.lnk")
                $Shortcut.TargetPath = "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\16\BIN\psconfigui.exe"
                $Shortcut.Arguments = "-cmd showcentraladmin"
                $Shortcut.Save()

                # Shortcut for SharePoint Products Configuration Wizard
                $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\SharePoint Products Configuration Wizard.lnk")
                $Shortcut.TargetPath = "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\16\BIN\psconfigui.exe"
                $Shortcut.Save()

                # Shortcut for SharePoint Management Shell
                $Shortcut = $WshShell.CreateShortcut("$Home\Desktop\SharePoint Management Shell.lnk")
                $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe"
                $Shortcut.Arguments = " -NoExit -Command ""& 'C:\Program Files\WindowsPowerShell\Modules\SharePointServer\SharePoint.ps1'"
                $Shortcut.Save()
            }
            GetScript            = { return @{ "Result" = "false" } } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If it returns $false, the SetScript block will run. If it returns $true, the SetScript block will not run.
            PsDscRunAsCredential = $DomainAdminCredsQualified
        }

        # if ($EnableAnalysis) {
        #     # This resource is for analysis of dsc logs only and totally optionnal
        #     Script parseDscLogs
        #     {
        #         TestScript = { return $false }
        #         SetScript = {
        #             $setupPath = $using:SetupPath
        #             $localScriptPath = "$setupPath\parse-dsc-logs.py"
        #             New-Item -ItemType Directory -Force -Path $setupPath
        
        #             $url = "https://gist.githubusercontent.com/Yvand/777a2e97c5d07198b926d7bb4f12ab04/raw/parse-dsc-logs.py"
        #             $downloader = New-Object -TypeName System.Net.WebClient
        #             $downloader.DownloadFile($url, $localScriptPath)
        
        #             $dscExtensionPath = "C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC"
        #             $folderWithMaxVersionNumber = Get-ChildItem -Directory -Path $dscExtensionPath | Where-Object { $_.Name -match "^[\d\.]+$"} | Sort-Object -Descending -Property Name | Select-Object -First 1
        #             $fullPathToDscLogs = [System.IO.Path]::Combine($dscExtensionPath, $folderWithMaxVersionNumber)
                    
        #             # Start python script
        #             Write-Verbose -Message "Run python `"$localScriptPath`" `"$fullPathToDscLogs`"..."
        #             #Start-Process -FilePath "powershell" -ArgumentList "python `"$localScriptPath`" `"$fullPathToDscLogs`""
        #             #invoke-expression "cmd /c start powershell -Command { $localScriptPath $fullPathToDscLogs }"
        #             python "$localScriptPath" "$fullPathToDscLogs"
        #         }
        #         GetScript = { }
        #         DependsOn            = "[cChocoPackageInstaller]InstallPython"
        #         PsDscRunAsCredential = $DomainAdminCredsQualified
        #     }
        # }

        Script DscStatus_Finished
        {
            SetScript =
            {
                "$(Get-Date -Format u)`t$($using:ComputerName)`tDSC Configuration on finished." | Out-File -FilePath $using:DscStatusFilePath -Append
            }
            GetScript            = { } # This block must return a hashtable. The hashtable must only contain one key Result and the value must be of type String.
            TestScript           = { return $false } # If the TestScript returns $false, DSC executes the SetScript to bring the node back to the desired state
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
help ConfigureSPVM

$password = ConvertTo-SecureString -String "mytopsecurepassword" -AsPlainText -Force
$DomainAdminCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "yvand", $password
$SPSetupCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "spsetup", $password
$SPFarmCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "spfarm", $password
$SPAppPoolCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "spapppool", $password
$SPPassphraseCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "Passphrase", $password
$DNSServerIP = "10.1.1.4"
$DomainFQDN = "contoso.local"
$DCServerName = "DC"
$SQLServerName = "SQL"
$SQLAlias = "SQLAlias"
$SharePointVersion = "Subscription-22H2"
$SharePointSitesAuthority = "spsitesse"
$SharePointCentralAdminPort = "5000"
$ConfigureADFS = $true
$EnableAnalysis = $true
$SharePointBits = @(
    @{
        Label = "RTM"; 
        Packages = @(
            @{ DownloadUrl = "https://go.microsoft.com/fwlink/?linkid=2171943"; ChecksumType = "SHA256"; Checksum = "C576B847C573234B68FC602A0318F5794D7A61D8149EB6AE537AF04470B7FC05" }
        )
    },
    @{
        Label = "22H2"; 
        Packages = @(
            @{ DownloadUrl = "https://download.microsoft.com/download/8/d/f/8dfcb515-6e49-42e5-b20f-5ebdfd19d8e7/wssloc-subscription-kb5002270-fullfile-x64-glb.exe"; ChecksumType = "SHA256"; Checksum = "7E496530EB873146650A9E0653DE835CB2CAD9AF8D154CBD7387BB0F2297C9FC" },
            @{ DownloadUrl = "https://download.microsoft.com/download/3/f/5/3f5b1ee0-3336-45d7-b2f4-1e6af977d574/sts-subscription-kb5002271-fullfile-x64-glb.exe"; ChecksumType = "SHA256"; Checksum = "247011443AC573D4F03B1622065A7350B8B3DAE04D6A5A6DC64C8270A3BE7636" }
        )
    }
)

$outputPath = "C:\Packages\Plugins\Microsoft.Powershell.DSC\2.83.5\DSCWork\ConfigureSPSE.0\ConfigureSPVM"
ConfigureSPVM -DomainAdminCreds $DomainAdminCreds -SPSetupCreds $SPSetupCreds -SPFarmCreds $SPFarmCreds -SPAppPoolCreds $SPAppPoolCreds -SPPassphraseCreds $SPPassphraseCreds -DNSServerIP $DNSServerIP -DomainFQDN $DomainFQDN -DCServerName $DCServerName -SQLServerName $SQLServerName -SQLAlias $SQLAlias -SharePointVersion $SharePointVersion -SharePointSitesAuthority $SharePointSitesAuthority -SharePointCentralAdminPort $SharePointCentralAdminPort -ConfigureADFS $ConfigureADFS -EnableAnalysis $EnableAnalysis -SharePointBits $SharePointBits -ConfigurationData @{AllNodes=@(@{ NodeName="localhost"; PSDscAllowPlainTextPassword=$true })} -OutputPath $outputPath
Set-DscLocalConfigurationManager -Path $outputPath
Start-DscConfiguration -Path $outputPath -Wait -Verbose -Force

C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\2.83.5
#>
