#Slack Azure DevTest Labs Artifact
##Information

This artifact installs Slack for Windows (https://slack.com/) via Chocolatey package manager.
Slack is a messaging app for teams that is on a mission to make your working life simpler, more pleasant, and more productive.

Information about the Chocolatey package and the version of the distributive available on https://www.myget.org/feed/almrangers/package/nuget/slackmsix64

##Usage
For manual installation run the following command

    > powershell.exe -ExecutionPolicy bypass -File startChocolatey.ps1 -PackageList slackmsix64 -Username {userName} -Password {password}

{userName} and {password} - This is credentials of the user for which you want to install the package. After executing this command, you must relogin. 
