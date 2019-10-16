# Overview
This extension provides several build / release tasks to allow you to integrate with [Azure DevTest Labs](https://azure.microsoft.com/en-us/services/devtest-lab/). 
 
1. [Create VM](#create-vm)
1. [Delete VM](#delete-vm)
1. [Create Custom Image](#create-custom-image)
1. [Delete Custom Image](#delete-custom-image)
1. [Create Environment](#create-environment)
1. [Update Environment](#update-environment)
1. [Delete Environment](#delete-environment)

You can find more details about Azure DevTest Labs [here](https://azure.microsoft.com/en-us/services/devtest-lab/).
# Details

## Create VM
The task allows you to create a lab VM using an ARM template generated from your Lab.

You can generate the ARM template by selecting all the configurations required to create a lab VM and also adding [artifacts](https://azure.microsoft.com/en-us/documentation/articles/devtest-lab-artifact-author/) which you want to apply after the VM is created.

### Required Parameters
The task requires the following inputs: 

|Parameter|Description|Notes
| --- | --- | ---
| **Azure RM Subscription** | _Azure Resource Manager subscription to configure before running._ | This is required to connect to Azure on your behalf.
| **Lab** | _Lab in which the resource will be created._ | This is a pick list generated as a result of selecting a subscription. Selecting a name from the list will extract the corresponding Lab ID. The Lab ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}`. Variables in the form `$(varName)` are allowed.
| **Virtual Machine Name** | _Name of the virtual machine to be created within the selected lab._ | This name will replace the value for the template parameter `-newVMName`. As such, it is expected to be in your ARM template.
| **Template File** | _Path to the ARM template._ | You can [generate the ARM template](https://azure.microsoft.com/en-us/documentation/articles/devtest-lab-add-vm-with-artifacts/#save-arm-template) from the **View ARM template** section when creating a Lab VM. Select the ARM template by browsing to the file that you have saved in your Azure DevOps source control. It can be either a relative path in a build output or a relative path inside an artifacts package.

### Optional Parameters

|Parameter|Description|Notes
| --- | --- | ---
| **Parameters File** | _The input parameters file._ | Use either a parameters file or the parameters overrides or both.
| **Parameter Overrides** | _ARM template parameters to use._ | You can use any system variable such as `$(Build.BuildNumber)` or `$(Release.ReleaseName)`. Similarly, you can create custom variables such as `User.Name` and `User.Password`, where the latter can be marked as a _secret_.

### Optional Parameters - Advanced Options
The following advanced options can be specified on the task to help control the behavior of deployment:

|Parameter|Description|Notes
| --- | --- | ---
| **Fail on artifact error** | _Fail the task if any artifact fails to apply successfully._
| **Retry the deployment following any failure** | _Retry the deployment when failing to create the lab VM or if any artifact fails to apply successfully._
| **Number of times to retry the deployment** | _Number of times to retry the deployment when an error occurs._ | This can be either while creating the lab VM or if any artifact fails to apply successfully.
| **Delete the failed lab VM before retrying** | _Delete the failed lab VM before retrying to create a new lab VM._ | This is used to clean up.
| **Delete the failed deployment before retrying** | _Delete the failed deployment before retrying to create the lab VM._ | This is used to clean up.
| **Append the retry iteration number to the VM name** | _Append the retry iteration number to the lab VM name before retrying (i.e. newVMName-1)._ | This may cause your lab VM name to be longer than allowed.
| **Number of minutes to wait in case the apply artifacts operation is still running** | _Number of minutes to wait for the apply artifacts operation to complete after the deployment has indicated completion._

### Output Variables
The task can produce the following outputs into corresponding variables:

|Variable|Description|Notes
| --- | --- | ---
| **labVmId** | _Variable set to the created lab VM ID._ | The variable can be referred as `$(labVmId)` in subsequent tasks. To qualify, make sure to set the task's `Reference name` under `Output Variables`. For example, using a reference name like `vm` will allow you to use the variable as `$(vm.labVmId)`.

## Delete VM
The task allows you to delete a lab VM.

### Required Parameters
The task requires the following inputs: 

|Parameter|Description|Notes
| --- | --- | ---
| **Azure RM Subscription** | _Azure Resource Manager subscription to configure before running._ | This is required to connect to Azure on your behalf.
| **Lab** | _Lab from which the resource will be deleted._ | This is a pick list generated as a result of selecting a subscription. Selecting a name from the list will extract the corresponding Lab ID. The Lab ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}`. Variables in the form `$(varName)` are allowed.
| **Virtual Machine** | _Virtual Machine that will be deleted._ | This is a pick list generated as a result of selecting a lab. Selecting a name from the list will extract the corresponding Virtual Machine ID. The Virtual Machine ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}/virtualMachines/{vmName}`. Variables in the form `$(varName)` are allowed. For example, you can use any variable such as `$(labVmId)`, the output of calling **Create Azure DevTest Labs VM**.

## Create Custom Image
The task allows you  to create a custom image in your lab based on an existing lab VM.

### Required Parameters
The task requires the following inputs: 

|Parameter|Description|Notes
| --- | --- | ---
| **Azure RM Subscription** | _Azure Resource Manager subscription to configure before running._ | This is required to connect to Azure on your behalf.
| **Lab** | _Lab in which the resource will be created._ | This is a pick list generated as a result of selecting a subscription. Selecting a name from the list will extract the corresponding Lab ID. The Lab ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}`. Variables in the form `$(varName)` are allowed.
| **Custom Image Name** | _Name of the custom image that will be created._ | You can use any variable such as `$(Build.BuildNumber)` or `$(Release.ReleaseName)` when in a build or a release, respectively. 
| **Source Lab VM** | _Source Lab VM from which the resource will be created._ | The source lab VM must be in the selected lab, as the custom image will be created using its VHD file. Selecting a name from the list will extract the corresponding Lab VM ID. The Lab VM ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}/virtualMachines/{vmName}`. Variables in the form `$(varName)` are allowed. For example, you can use any variable such as `$(labVmId)`, the output of calling **Create Azure DevTest Labs VM**.
| **OS Type** | _Type of operating system of the source lab VM._ | This is a pick list whose allowed values are _Linux_ or _Windows_.
| **Linux OS State** | _Value indicating how to prepare the source lab VM for custom image creation._ | (When **OS Type** = _Linux_) This is a pick list whose allowed values are _NonDeprovisioned_, _DeprovisionRequested_ or _DeprovisionRequested_. See [Deprovisioning](http://aka.ms/Deprovisioning) for more information.
| **Windows OS State** | _Value indicating how to prepare the the source lab VM for custom image creation._ | (When **OS Type** = _Windows_) This is a pick list whose allowed values are _NonSysprepped_, _SysprepRequested_ or _SysprepRequested_. See [Sysprep](http://aka.ms/Sysprep) for more information.

### Optional Parameters

|Parameter|Description|Notes
| --- | --- | ---
| **Description** | _Description of the custom image that will be created._ | If left blank, an auto-generated string will be used as the description.

### Output Variables
The task can produce the following outputs into corresponding variables:

|Variable|Description|Notes
| --- | --- | ---
| **customImageId** | _Variable set to the created custom image ID._ | The variable can be referred as `$(customImageId)` in subsequent tasks. To qualify, make sure to set the task's `Reference name` under `Output Variables`. For example, using a reference name like `ci` will allow you to use the variable as `$(ci.customImageId)`.

## Delete Custom Image
The task allows you to delete a custom image from the selected lab.

### Required Parameters
The task requires the following inputs: 

|Parameter|Description|Notes
| --- | --- | ---
| **Azure RM Subscription** | _Azure Resource Manager subscription to configure before running._ | This is required to connect to Azure on your behalf.
| **Lab** | _Lab from which the resource will be deleted._ | This is a pick list generated as a result of selecting a subscription. Selecting a name from the list will extract the corresponding Lab ID. The Lab ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}`. Variables in the form `$(varName)` are allowed.
| **Custom Image** | _Custom Image that will be deleted._ | This is a pick list generated as a result of selecting a lab. Selecting a name from the list will extract the corresponding Custom Image ID. The Custom Image ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}/customImages/{ciName}`. Variables in the form `$(varName)` are allowed. For example, you can use any variable such as `$(customImageId)`, which is the output of calling **Create Azure DevTest Labs Custom Image**.

## Create Environment
The task allows you to create an environment in the selected lab.

### Required Parameters
The task requires the following inputs: 

|Parameter|Description|Notes
| --- | --- | ---
| **Azure RM Subscription** | _Azure Resource Manager subscription to configure before running._ | This is required to connect to Azure on your behalf.
| **Lab** | _Lab in which the resource will be created._ | This is a pick list generated as a result of selecting a subscription. Selecting a name from the list will extract the corresponding Lab ID. The Lab ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}`. Variables in the form `$(varName)` are allowed.
| **Environment Name** | _Name of the environment to be created within the selected lab._
| **Repository** | _Repository from which to pick a template. | This is a pick list generated as a result of selecting a lab. Selecting a name from the list will extract the corresponding Repository ID. The Repository ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}/artifactSources/{repoName}`. Variables in the form `$(varName)` are allowed.
| **Template** | _Template that should be used to create an environment._ | This is a pick list generated as a result of selecting a repository. Selecting a name from the list will extract the corresponding Template ID. The Template ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}/artifactSources/{repoName}/armTemplates/{templateName}`. Variables in the form `$(varName)` are allowed.

### Optional Parameters

|Parameter|Description|Notes
| --- | --- | ---
| **Parameters File** | _The input parameters file._ | Use either a parameters file or the parameters overrides or both.
| **Parameter Overrides** | _ARM template parameters to use._ | You can use any system variable such as `$(Build.BuildNumber)` or `$(Release.ReleaseName)`. Similarly, you can create custom variables such as `User.Name` and `User.Password`, where the latter can be marked as a _secret_.
| **Create output variables based on the environment template output.** | _ Create output variables resulting from the creation of the environment._ | Any variables that are defined in the `outputs` section of the ARM template will have a corresponding variable created for use in subsequent build / release tasks.

### Output Variables
The task can produce the following outputs into corresponding variables:

|Variable|Description|Notes
| --- | --- | ---
| **environmentResourceId** | _Variable set to the created environment ID._ | The variable can be referred as `$(environmentResourceId)` in subsequent tasks. To qualify, make sure to set the task's `Reference name` under `Output Variables`. For example, using a reference name like `env` will allow you to use the variable as `$(env.environmentResourceId)`.
| **environmentResourceGroupId** | _Variable set to the resource group of the created environment._ | The variable can be referred as `$(environmentResourceGroupId)` in subsequent tasks. To qualify, make sure to set the task's `Reference name` under `Output Variables`. For example, using a reference name like `env` will allow you to use the variable as `$(env.environmentResourceGroupId)`.

## Update Environment
The task allows you to update an environment with new resources by deploying an ARM template.

### Required Parameters
The task requires the following inputs: 

|Parameter|Description|Notes
| --- | --- | ---
| **Azure RM Subscription** | _Azure Resource Manager subscription to configure before running._ | This is required to connect to Azure on your behalf.
| **Lab** | _Lab in which the resource will be updated._ | This is a pick list generated as a result of selecting a subscription. Selecting a name from the list will extract the corresponding Lab ID. The Lab ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}`. Variables in the form `$(varName)` are allowed.
| **Environment** | _Environment that will be updated._ | This is a pick list generated as a result of selecting a lab. Selecting a name from the list will extract the corresponding Environment ID. The Environment ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}/users/@me/environments/{envName}`. Variables in the form `$(varName)` are allowed.
| **Template File** | _Path to the ARM template to use to update the environment._ | The file is expected to be stored in your source control. It can contain any resources that are allowed by an environment.

### Optional Parameters

|Parameter|Description|Notes
| --- | --- | ---
| **Parameters File** | _The input parameters file._ | Use either a parameters file or the parameters overrides or both.
| **Parameter Overrides** | _ARM template parameters to use._ | You can use any system variable such as `$(Build.BuildNumber)` or `$(Release.ReleaseName)`. Similarly, you can create custom variables such as `User.Name` and `User.Password`, where the latter can be marked as a _secret_.
| **Create output variables based on the environment template output.** | _ Create output variables resulting from the creation of the environment._ | Any variables that are defined in the `outputs` section of the ARM template will have a corresponding variable created for use in subsequent build/release tasks.

### Output Variables
If enabled, the task can produce the following output variables. Note that you will need to define a Reference Name (i.e. `<refName>` such as `env`) under the Output Variables section to correctly reference the variables in the list.

## Delete Environment
The task allows you to delete an environment.

### Required Parameters
The task requires the following inputs: 

|Parameter|Description|Notes
| --- | --- | ---
| **Azure RM Subscription** | _Azure Resource Manager subscription to configure before running._ | This is required to connect to Azure on your behalf.
| **Lab** | _Lab in which the resource will be deleted._ | This is a pick list generated as a result of selecting a subscription. Selecting a name from the list will extract the corresponding Lab ID. The Lab ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}`. Variables in the form `$(varName)` are allowed.
| **Environment** | _Environment that will be deleted._ | This is a pick list generated as a result of selecting a lab. Selecting a name from the list will extract the corresponding Environment ID. The Environment ID is a value in the form `/subscriptions/{subId}/resourceGroups/{rgName}/providers/Microsoft.DevTestLab/labs/{labName}/users/@me/environments/{envName}`. Variables in the form `$(varName)` are allowed. For example, you can use any variable such as `$(environmentResourceId)`, which is the output of calling **Create Azure DevTest Labs Environment**.