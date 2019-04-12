# Deploy a Selenium Grid on Azure DevTestLabs VMs.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-devtestlab%2Fmaster%2FSamples%2F201-dtl-create-lab-with-seleniumgrid%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

Creates an Azure DevTest Lab with a <a href="https://github.com/SeleniumHQ/selenium/wiki/Grid2">selenium-grid</a> setup up on its VMs.

## Features

- Java is automatically installed on the VMs using the <a href="https://github.com/Azure/azure-devtestlab/tree/master/Artifacts/windows-chocolatey">windows-chocolatey</a> artifact.
- Latest versions of Chrome and Firefox (Internet Explorer comes with the OS) are installed on the node VMs along with respective drivers using the <a href="https://github.com/Azure/azure-devtestlab/tree/master/Artifacts/windows-selenium">windows-selenium</a> artifact.
- The selenium-grid is setup on the VMs using the <a href="">selenium-hub</a> and <a href="">selenium-node</a> artifacts.
- The grid is also self-healing, that is the hub/node process is brought back up with the last provided configuration in case it crashes or the VM is restarted. This allows you to stop your VMs when not in use and start them back up when necessary.
- The url which your remote webriver has to use, to run tests against the grid, is output after the deployment successfully completes. Just click on the deployment successful notification and look for the output field.

## FAQs

Q. Can I deploy different nodes with different capabilities/configurations?<br>
A. The ARM template at present only supports homogenous configuration. You may however use the selenium-grid artifacts individually to tweak the configuration of each VM. These artifacts can be found on the Azure Portal in the artifacts blade of any DevTest Lab instance.

Q. Can I change the base OS image or the size of the VMs?<br>
A. The template only exposes inputs related to the configuration of the grid and a few other general inputs. Other Advanced parameters like OS Version (Only Windows OS supported), VM size, VNet configuration etc will have to be modified by editing the template itself.<br>

Q. What OSes are supported?<br>
A. Only Windows OS is supported as of now.

Q. How many VMs are created by the template?<br>
A. The template creates one hub VM and the specified number of node VMs.

Q. I want to run tests on my grid, how do I get the hub Url?<br>
A. You can get the hub Url from the output field after clicking on the notification for successful deployment of the template. If you missed this then you can construct the url yourself. All you have to do is get the ipaddress/fqdn of the hub VM from the DevTest Lab instance you just created and replace it in this pattern - http://{ipaddress or fqdn}:4444/wd/hub