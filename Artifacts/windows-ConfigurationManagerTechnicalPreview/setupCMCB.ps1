Param(
  [string]$SiteCode = 'TST',
  [string]$SiteName = 'Test Site'
)

cd $($PSScriptRoot)

#Check if System is Domain-Joined
if((gwmi win32_computersystem).partofdomain -eq $true)
{
	#Download RZUpdate if missing...
	if((Test-Path "$($env:temp)\RZUpdate.exe") -eq $false) 
	{ 
		(New-Object System.Net.WebClient).DownloadFile("https://ruckzuck.azurewebsites.net/DL/RZUpdate.exe", "$($env:temp)\RZUpdate.exe") 
	}

 #Check if an unattend File already exists; otherwise create a new one...
 if(!(Test-Path c:\sccmsetup.ini))
	{
		$hostname = [System.Net.Dns]::GetHostByName(($env:computerName)).Hostname;
		'[Identification]' | out-file -filepath C:\sccmsetup.ini
		'Action=InstallPrimarySite' | out-file -filepath C:\sccmsetup.ini -append 
		'[Options]' | out-file -filepath C:\sccmsetup.ini -append  
		'ProductID="EVAL"' | out-file -filepath C:\sccmsetup.ini -append  
		'PrerequisiteComp=0' | out-file -filepath C:\sccmsetup.ini -append 
		'PrerequisitePath="C:\SCCMDownloads"' | out-file -filepath C:\sccmsetup.ini -append 
		"SiteCode=$($SiteCode)" | out-file -filepath C:\sccmsetup.ini -append 
		'SiteName="' + $SiteName + '"' | out-file -filepath C:\sccmsetup.ini -append 
		'SMSInstallDir="C:\Microsoft Configuration Manager"' | out-file -filepath C:\sccmsetup.ini -append  
		"SDKServer=$($hostname)" | out-file -filepath C:\sccmsetup.ini -append 
		'AdminConsole=1' | out-file -filepath C:\sccmsetup.ini -append 
		'JoinCEIP=0' | out-file -filepath C:\sccmsetup.ini -append 
		'RoleCommunicationProtocol=HTTPorHTTPS' | out-file -filepath C:\sccmsetup.ini -append 
		'ClientsUsePKICertificate=0' | out-file -filepath C:\sccmsetup.ini -append 
		'AddServerLanguages=' | out-file -filepath C:\sccmsetup.ini -append 
		'AddClientLanguages=DEU' | out-file -filepath C:\sccmsetup.ini -append 
		'MobileDeviceLanguage=0' | out-file -filepath C:\sccmsetup.ini -append 
		"ManagementPoint=$($hostname)" | out-file -filepath C:\sccmsetup.ini -append 
		'ManagementPointProtocol=HTTP' | out-file -filepath C:\sccmsetup.ini -append 
		"DistributionPoint=$($hostname)" | out-file -filepath C:\sccmsetup.ini -append 
		'DistributionPointProtocol=HTTP' | out-file -filepath C:\sccmsetup.ini -append 
		'DistributionPointInstallIIS=0' | out-file -filepath C:\sccmsetup.ini -append  
		'[SQLConfigOptions]' | out-file -filepath C:\sccmsetup.ini -append 
		"SQLServerName=$($hostname)" | out-file -filepath C:\sccmsetup.ini -append 
		'DatabaseName=CM_' + $SiteCode | out-file -filepath C:\sccmsetup.ini -append 
		'SQLSSBPort=4022' | out-file -filepath C:\sccmsetup.ini -append 
		'[HierarchyExpansionOption]' | out-file -filepath C:\sccmsetup.ini -append 
	}

    
	#Make SYSTEM a SYSADMIN in SQL : https://gallery.technet.microsoft.com/scriptcenter/Reset-SQL-SA-Password-15fb488d#content
	import-module .\Reset-SqlAdmin.psm1
	Reset-SqlAdmin -SqlServer $env:COMPUTERNAME -Login "NT AUTHORITY\SYSTEM"

    #Set SQL to run as LocalSystem
    $service = gwmi win32_service -filter "name='MSSQLSERVER'"
    if($service -eq $null) { exit 1 }
    $service.Change($null, $null, $null, $null, $null, $null, "LocalSystem", $null, $null, $null, $null)
    Stop-Service 'MSSQLSERVER' -Force
    Start-Service 'MSSQLSERVER'

	#Install ADK10
	$proc = (Start-Process -FilePath "$($env:temp)\RZUpdate.exe" -ArgumentList "ADK10" -Wait -PassThru)
	$proc.WaitForExit()

    if((test-path "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows Kits\Installed Roots") -eq $false) { exit 2 }
    
	#Cleanup Files from previous attempts..
	if(Test-Path "$($env:temp)\SMSSETUP") { Remove-Item "$($env:temp)\SMSSETUP" -Force -Recurse  }
    
	#Install Configuration Manager
	$proc = (Start-Process -FilePath "$($env:temp)\RZUpdate.exe" -ArgumentList "`"Configuration Manager (Technical-Preview)`"" -Wait -PassThru)
	$proc.WaitForExit()

    if((test-path "HKLM:\SOFTWARE\Microsoft\SMS\COMPONENTS") -eq $false) { exit 3 }
    
	#Cleanup Files..
	if(Test-Path "$($env:temp)\SMSSETUP") { Remove-Item "$($env:temp)\SMSSETUP" -Force -Recurse  }
	
    #Add Tools
	$proc = (Start-Process -FilePath "$($env:temp)\RZUpdate.exe" -ArgumentList "`"ConfigMgrTools`";`"Collection Commander`";`"SCCMCliCtr`";`"RuckZuck for Configuration Manager`";`"SCUP`";`"LogLauncher`"" -Wait -PassThru)
	$proc.WaitForExit()
	
    #Add Domain Admins as Full Admins
    #import-module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1) 
    import-module ("C:\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1")   
    new-psdrive -Name $SiteCode -PSProvider "AdminUI.PS.Provider\CMSite" -Root "localhost"
    cd ((Get-PSDrive -PSProvider CMSite).Name + ':')
    
    New-CMAdministrativeUser -Name "$($env:userdomain)\domain admins" -RoleName "Full Administrator" -SecurityScopeName "All"
 }

