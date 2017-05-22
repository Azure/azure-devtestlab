# Copyright (c) Microsoft Corporation. All rights reserved.
param(

    [Parameter(Mandatory=$false, HelpMessage="Specify whether to start a selenium hub or a node.")]
    [string] $role='hub',                                    #Defines whether to setup a selenium grid hub or a node

    [Parameter(Mandatory=$false, HelpMessage="Specify the url the node will use to register itself with a hub.")]
    [string] $hubRegisterUrl=[string]::Empty,                #Only valid for nodes

    [Parameter(Mandatory=$false, HelpMessage="Specify the path to the json config file for the hub/node.")]
    [string] $configFile=[string]::Empty,                    #Optional json config file

    [Parameter(Mandatory=$false, HelpMessage="Enter any additional paramters needed to configure your hub/node.")]
    [string] $additionalParameters=[string]::Empty,          #Additional parameters for the node or the hub

    [Parameter(Mandatory=$true, HelpMessage="Specify the path to the selenium grid standalone server jar file.")]
    [string] $seleniumGridJarFile                            #Selenium grid standalone jar file name

)

$ErrorActionPreference = "Stop"

Write-Host -Object "\n"
Write-Host -Object "Executing script GridDeployerUtility.ps1"
Write-Host -Object ""
Write-Host -Object "Parameters"
Write-Host -Object "----------"
Write-Host -Object "Role: $role"
Write-Host -Object "ConfigFile: $configFile".Replace("\","/")
if($role -ieq "node")
{
    Write-Host -Object "hubRegisterUrl: $hubRegisterUrl"
}
Write-Host -Object "SeleniumGridJarFile: $seleniumGridJarFile"
Write-Host -Object ""

#Uninstall the Selenium Grid Setup Service if it already exists
Start-Process (Join-Path($([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())) InstallUtil.exe) -ArgumentList "/u SeleniumGridSetupService.exe" -Wait

if(Test-Path "$SetupDirectory\SeleniumGridSetupService.exe")
{
    #Delete the service exe from previous deployments
    rm "$SetupDirectory\SeleniumGridSetupService.exe"
    Write-Host -Object "Successfully deleted the service exe of the previous deployment."
}

#Move the service exe of the current deployment to the setup directory
mv ".\SeleniumGridSetupService.exe" "$SetupDirectory\SeleniumGridSetupService.exe"
Write-Host -Object "Moved the new service exe to the setup directory."

if(Test-Path "$SetupDirectory\$seleniumGridJarFile")
{
    #Delete the Selenium Grid jar file from previous deployments
    rm "$SetupDirectory\$seleniumGridJarFile"
    Write-Host -Object "Successfully deleted the jar file used in the previous deployment."
}

#Move the Selenium Grid jar file of the current deployment to the setup directory
mv ".\$seleniumGridJarFile" "$SetupDirectory\$seleniumGridJarFile"
Write-Host -Object "Moved the new jar file to the setup directory."

#Install the Selenium Grid Setup Service 
Start-Process (Join-Path($([System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory())) InstallUtil.exe) -ArgumentList "$SetupDirectory\SeleniumGridSetupService.exe" -Wait
Write-Host -Object "Successfully installed the Selenium Grid Setup Service on the System."

#TODO: Expose this to the user on the artifact
#Format the additional parameters provided by the user
$additionalParameters = $additionalParameters -replace '"' , "\`""

if($role -ieq "hub")
{
    #Start the service to setup a Selenium Grid Hub
    net start SeleniumGridSetupService /"$seleniumGridJarFile" /"$role" /"$hubRegisterUrl"  /"$configFile" /"$additionalParameters"
}
else
{
    #Start the service to setup a Selenium Grid Node
    net start SeleniumGridSetupService /"$seleniumGridJarFile" /"$role" /"$hubRegisterUrl" /"$configFile" /"$additionalParameters"
}

#Assume a setup timeout of 60 seconds
$timeout = 60

while( $timeout-- )
{
    #Poll the status file every second to check the status of the grid hub/node
    if(Test-Path "$SetupDirectory\logs\SetupStatus.txt")
    {
        $Status = Get-Content "$SetupDirectory\logs\SetupStatus.txt"
    }

    if($Status -eq "Success")
    {
        Write-Host -NoNewline -Object "Successfully setup the Selenium Grid $role." -ForegroundColor Green
        $timeout = 0
    }
    elseif($Status -eq "Failure" -or $timeout -eq 0)
    {
        $timeout = 0
        Write-Host -Object "Failed to setup the Selenium Grid $role. Please refer to the setup logs for further details.\n"
        Write-Host -Object ([io.file]::ReadAlltext("$SetupDirectory\logs\SetupLogs.txt"))
        throw
    }
    Sleep(1)
}
