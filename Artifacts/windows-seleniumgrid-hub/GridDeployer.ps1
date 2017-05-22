# Copyright (c) Microsoft Corporation. All rights reserved.
param(

    [Parameter(Mandatory=$false, HelpMessage="Specify the path to the json config file for the hub/node.")]
    [string] $configFile=[string]::Empty,                    #Optional json config file

    [Parameter(Mandatory=$false, HelpMessage="Enter any additional paramters needed to configure your hub/node.")]
    [string] $additionalParameters=[string]::Empty,          #Additional parameters for the node or the hub

    [Parameter(Mandatory=$true, HelpMessage="Specify the path to the selenium grid standalone server jar file.")]
    [string] $seleniumGridJarFile,                           #Selenium grid standalone jar file name

    [Parameter(Mandatory=$false, HelpMessage="Specify the IP address of the hub machine.")]
    [string] $hubMachineIP,                                  #IP address of the hub machine required to register nodes to the hub

    [Parameter(Mandatory=$false, HelpMessage="Specify whether to start a selenium hub or a node.")]
    [string] $role='hub'                                     #Defines whether to setup a selenium grid hub or a node

)

$ErrorActionPreference = "Stop"

#Remove the dummy set of charactes ('config:') that are prefixed to the config file url to ensure proper piping of the 
#parameter from the Artifact as this is an optional parameter
$configFile = $configFile.Substring(7)

Write-Host -Object "Executing script GridDeployer.ps1"
Write-Host -Object ""
Write-Host -Object "Parameters"
Write-Host -Object "----------"
Write-Host -Object "Role: $role"
Write-Host -Object "ConfigFile: $configFile"
Write-Host -Object "SeleniumGridJarFile: $seleniumGridJarFile"
if($role -ieq "node")
{
    Write-Host -Object "HubMachineAddress: $hubMachineIP"
}
Write-Host -Object ""

#Strip away the rest of the url and retain only the name of the Selenium Server Standalone jar file
$seleniumGridJarFileName = $seleniumGridJarFile.Split("/")[-1]

Write-Host -Object "SeleniumGridJarFileName: $seleniumGridJarFileName"

#Download the Selenium Selenium Server Standalone jar file
Invoke-WebRequest -Uri $seleniumGridJarFile -OutFile "$PWD\$seleniumGridJarFileName"

Write-Host -Object "Successfully downloaded the SeleniumGrid jar file from $seleniumGridJarFile." 

#Strip away the rest of the url and retain only the name of the json config file
$configFileName = $configFile.Split("/")[-1]

$isConfigFileProvided = ![string]::IsNullOrWhiteSpace($configFileName)

if($isConfigFileProvided)
{
    #Download the specified config file
    Invoke-WebRequest -Uri $configFile -OutFile "$PWD\$configFileName"
    Write-Host -Object "Successfully downloaded the config file from $configFile." 
}
else
{
    Write-Host -Object "No config file will be used to setup the $role as the input field was left blank."
}

#Adding the selenium tools folder downloaded using the selenium artifact to the Path Environment variable if deploying a node
if($role -ieq "node")
{
    $ErrorActionPreference = "SilentlyContinue"
    $WebDriverDefaultInstallPath ="$env:SystemDrive\tools\selenium"
    $Reg = "Registry::HKLM\System\CurrentControlSet\Control\Session Manager\Environment"
    $OldPath = (Get-ItemProperty -Path "$Reg" -Name PATH).Path
    if(-not ($OldPath.Contains($WebDriverDefaultInstallPath)))
    {
        $NewPath= "$OldPath;$WebDriverDefaultInstallPath"
        Set-ItemProperty -Path "$Reg" -Name PATH –Value $NewPath
    }
    $ErrorActionPreference = "Stop"
}

$SetupDirectory = "$env:SystemDrive\SeleniumGridSetup"

#Create a folder to store the log files
if(-not (Test-Path "$SetupDirectory\logs"))
{
    New-Item -ItemType directory -Path "$SetupDirectory\logs" | out-null
    Write-Host -Object "Created the folder $SetupDirectory\logs to store the logs files."
}

if($isConfigFileProvided)
{
    if(Test-Path "$SetupDirectory\$configFileName")
    {
        #Delete the config file from previous deployments
        rm "$SetupDirectory\$configFileName"
        Write-Host -Object "Deleted the config file ($SetupDirectory\$configFileName) from the previous deployment.".Replace("\","/")
        $var = Join-Path $SetupDirectory $configFileName
    }

    #Move the config file of the current deployment to the setup directory
    mv ".\$configFileName" "$SetupDirectory\$configFileName"
    Write-Host -Object "Moved the new config file to the setup directory."
}


if($role -ieq "hub")
{
    #Check if config file was provided and construct the parameter for it
    if($isConfigFileProvided)
    {
        $configFileName = "-hubConfig " + '"' + "$SetupDirectory\$configFileName" + '"'
    }

    try 
    {
        #Check if firewall exception rule already exists
        $firewallRule = Get-NetFirewallRule -DisplayName SeleniumGridHub -ErrorAction Stop
        Write-Host -Object "Firewall exception rule for the hub already exists from a previous deployment."
    }
    catch 
    {
        if(-Not $firewallRule) 
        {
            #Enable Firewall access for the hub
            New-NetFirewallRule -displayname SeleniumGridHub -direction inbound -action allow -protocol tcp -remotePort Any -localport 4444 | out-null
            New-NetFirewallRule -displayname SeleniumGridHub -direction outbound -action allow -protocol tcp -remotePort Any -localport 4444 | out-null
            Write-Host -Object "Added Firewall exception for port 4444."
        }
    }
}
else
{
    #Check if config file was provided and construct the parameter for it
    if($isConfigFileProvided)
    {
        $configFileName = "-nodeConfig " + '"' + "$SetupDirectory\$configFileName" + '"'
    }

    try 
    {
        #Check if firewall exception rule already exists
        $firewallRule = Get-NetFirewallRule -DisplayName SeleniumGridNode -ErrorAction Stop
        Write-Host -Object "Firewall exception rule for the node already exists from a previous deployment."
    }
    catch 
    {
        if(-Not $firewallRule) 
        {
            #Enable Firewall access for the node
            New-NetFirewallRule -displayname SeleniumGridNode -direction inbound -action allow -protocol tcp -remotePort Any -localport 5555 | out-null
            New-NetFirewallRule -displayname SeleniumGridNode -direction outbound -action allow -protocol tcp -remotePort Any -localport 5555 | out-null
            Write-Host -Object "Added Firewall exception for port 5555."
        }
    }

    #Construct the url that the nodes have to register at
    $hubRegisterUrl = "-hub http://$hubMachineIP`:4444/grid/register"
}

try
{
    #Start the utility script to install and start the service to setup and monitor the hub/node process
    .\GridDeployerUtility.ps1 -role $role.ToLower() -hubRegisterUrl $hubRegisterUrl -configFile $configFileName -additionalParameters $additionalParameters -seleniumGridJarFile $seleniumGridJarFileName
}
catch
{
    exit -1
}