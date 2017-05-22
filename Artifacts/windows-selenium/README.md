# Welcome to vsar Selenium artifacts!


## Solution
The Selenium Artifact allow you within the DevTest Lab environment to install all necessary drivers and browser to work with Selenium test automation.
Via chocolatey it will automaticatically install what is needed to run selenium and you can use the sample application to test the installation. 

## Azure VM 

The artifact was tested over DevTestLab Virtual Machine with Visual Studio Enterprise 2015 with Azure SDK 2.9 on Windows Server 2012 R2
Standard A2 (3.5GB of Memory). After applying the artifact you can use the sample application below that allows you to test selenium automation
by opening Chrome, Firefox and IE browser and open the page http://azure.microsoft.com.

You can find the sample application at:

[Sample Test Application ](https://almrangers.visualstudio.com/DefaultCollection/ALM/_git/vsarAzureDevTest?path=%2FArtifacts%2Fwindows-selenium%2FDemo%20Sample%20Solution&version=GBmaster&_a=contents)

## Remarks

At development time there were no direct feedback on the installation of the artifact so it was needed to test the artifact 
before it was uploaded to be avaiable within the repository, the artifact uses a json file that runs the powershell command

"powershell.exe -ExecutionPolicy bypass -File startChocolatey.ps1"

If you are developing a new artifact and use the template make sure you run the command within the powershell session in the VM to verify that all packages are correctly install with Chocolaty, 
please note that the Packagelist if need more that one package to be install requires "," to delimit the names and cannot have spaces between them.

## Contact information
### Dev Lead: [Oscar Garcia Colon](mailto://oscar.garcia.colon@outlook.com)
*Backups*:
- [Derek Keeler](mailto://dekeeler@microsoft.com)

### PM: [Willy-Peter Schaub](mailto://willys@microsoft.com)


| |[Team Windows](https://almrangers.visualstudio.com/DefaultCollection/ALM/vsarAzureDevTest/_workitems#_a=edit&id=11668&fullScreen=true)|[Team Linux](https://almrangers.visualstudio.com/DefaultCollection/ALM/vsarAzureDevTest/_workitems#_a=edit&id=11669&fullScreen=true)|
|--|--|--|
|*Investigative Lead*|[Oscar Garcia Colon](mailto://oscar.garcia.colon@outlook.com)|[Derek Keeler](mailto://derek.keeler@outlook.com)|
|Members|Rui Melo|Darren Rich|
||Tommy Sundling|Mike Douglas|
||Esteban Garcia|@|  
||David Pitcher|@|  
-------------------------------------------------------------------------------

