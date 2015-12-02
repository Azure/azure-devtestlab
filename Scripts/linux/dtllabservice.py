# Copyright (c) Microsoft Corporation
# All rights reserved.
#
#
# MIT License
#
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from datetime import datetime
import azurerest
import json
import re
import time


class LabService:
    """Provides lab-related services to the CLI

    Serves as the 'client' for the Azure DevTest Labs service proxying
    calls to/from the RESTful endpoint supported by the service.

    Attributes:
        [Private]
        _settings: The collection of settings including the log level (verbose), and the current access token (accessToken)

        [Public]
        None
    """

    def __init__(self, settings, printService):
        """Initializes LabService with common settings including the logging verbosity level and the access token"""
        self._settings = settings
        self._printService = printService

    def getLabs(self):
        """Retrieves all labs in the specified subscription from the lab service

        Args:
            None
        Returns:
            A collection of lab object references containing information about a lab including its ID.  For example:
            [
                {
                    "properties": {
                        "vaultName": "/subscriptions/<subscription ID>/resourceGroups/<resource group name>/providers/Microsoft.KeyVault/vaults/<vault name>",
                        "storageAccounts": [
                            "/subscriptions/<subscription ID>/resourceGroups/<resource group name>/providers/Microsoft.Storage/storageAccounts/<storage acct>"
                        ],
                        "defaultStorageAccount": "/subscriptions/<subscription ID/resourceGroups/resource group name/providers/Microsoft.Storage/storageAccounts/<storage acct>",
                        "provisioningState": "Succeeded"
                    },
                    "location": "West US",
                    "type": "Microsoft.DevTestLab/labs",
                    "id": "/subscriptions/<subscription ID>/resourceGroups/<resource group name>/providers/Microsoft.DevTestLab/labs/<lab name>",
                    "name": "<lab name>"
                }
            ]
        """

        # Get all labs, then filter
        url = self._getLabsBaseUrl.format(self._settings.subscription, self._apiVersion)

        self._printService.info('Getting all labs')

        api = azurerest.AzureRestHelper(self._settings, self._settings.accessToken, self._host)

        labs = api.get(url, self._apiVersion)["value"]

        return labs

    def getLabByName(self, labName):
        """Retrieves a lab corresponding to the specified labName from the lab service

        Args:
            labName (string) - The string name of the lab in which to retrieve.
        Returns:
            A lab object reference containing information about a lab including its ID.  For example:

            {
                "properties": {
                    "vaultName": "/subscriptions/<subscription ID>/resourceGroups/<resource group name>/providers/Microsoft.KeyVault/vaults/<vault name>",
                    "storageAccounts": [
                        "/subscriptions/<subscription ID>/resourceGroups/<resource group name>/providers/Microsoft.Storage/storageAccounts/<storage acct>"
                    ],
                    "defaultStorageAccount": "/subscriptions/<subscription ID/resourceGroups/resource group name/providers/Microsoft.Storage/storageAccounts/<storage acct>",
                    "provisioningState": "Succeeded"
                },
                "location": "West US",
                "type": "Microsoft.DevTestLab/labs",
                "id": "/subscriptions/<subscription ID>/resourceGroups/<resource group name>/providers/Microsoft.DevTestLab/labs/<lab name>",
                "name": "<lab name>"
            }
        """

        labs = self.getLabs()

        self._printService.info('Finding lab {0}'.format(labName))

        for lab in labs:
            if lab['name'] == labName:
                return lab

        return

    def createVm(self, subscriptionId, vmTemplateFileName, labName, vmName, templateName, size, vmUserName, vmPassword,
                 vmSshKey):
        """Creates a lab virtual machine based on the specified subscription, template, and other misc parameters.

        Args:
            subscriptionId (string) - The subscription ID used to create the virtual machine.
            vmTemplateFileName (string) - The path to an Azure RM template representing the configuration of the new virtual machine.
            labName (string) - The name of the lab used to create the virtual machine.
            templateName (string) - The name of the virtual machine template to use as a base.
            size (string) - The Azure size value denoting the size of the new virtual machine.
            vmUserName (string) - The user name, if provided, of the administrative user account created on the virtual machine.
            vmPassword (string) - The password, if provided, of the administrative user account created on the virtual machine.
            vmSshKey (string) - The SSH public key for use when connecting to the virtual machine.

        Returns:
            0 if successful, 1 otherwise.
        """

        lab = self.getLabByName(labName)

        if lab is None:
            self._printService.error('Lab {0} does not exist or is not accessible.'.format(labName))
            return 1

        rgName = self.__getResourceGroupFromLab(lab["id"])

        with open(vmTemplateFileName) as data_file:
            template = json.load(data_file)

        paramData = self.__getTemplateParams(labName, vmName, templateName, size, vmUserName, vmPassword, vmSshKey)

        fullTemplate = {
            'properties': {
                'mode': 'Incremental',
                'template': template,
                'parameters': paramData
            }
        }

        self._printService.info(
            'Creating a new virtual machine based on the following: lab = {0}, name = {1}, template = {2}, size = {3}, vmusername = {4}'.format(
                labName,
                vmName,
                templateName,
                size,
                vmUserName
            ))

        result, output = self.__deployArmTemplate(subscriptionId, rgName, fullTemplate)

        if result == 0:
            self._printService.dumps(self.getVirtualMachine(subscriptionId, output['vmId']['value']))

        return result

    def createVmTemplate(self, labName, subscriptionId, vmId, newTemplateName, newTemplateDesc, armTemplateFilePath):
        """Creates a lab virtual machine template based on the specified subscription, template, and other misc parameters.

        Args:
            subscriptionId (string) - The subscription ID used to create the virtual machine.
            vmId (string) - The ID of the virtual machine to capture.
            newTemplateName (string) - The name of the new virtual machine template.
            newTemplateDesc (string) - The description of the new virtual machine template.

        Returns:
            0 if successful, 1 otherwise.

        """

        vms = self.getVirtualMachinesForLab(subscriptionId, labName)

        if len(vms) <= 0:
            self._printService.error(
                'No virtual machines found in lab {0} and subscription {1}'.format(labName, subscriptionId))
            return 1

        for vm in vms:
            if vm['id'] == vmId:
                self._printService.info(
                    'Creating a new virtual machine template based on the following: vmId = {0}, templateName = {1}, description = {2}, ARM template = {3}'.format(
                        vmId,
                        newTemplateName,
                        newTemplateDesc,
                        armTemplateFilePath
                    ))

                lab = self.getLabByName(labName)

                if lab is None:
                    self._printService.error('Lab {0} does not exist or is not accessible.'.format(labName))
                    return 1

                labId = lab["id"]
                rgName = self.__getResourceGroupFromLab(labId)

                with open(armTemplateFilePath) as data_file:
                    template = json.load(data_file)

                paramData = self.__getNewVmTemplateParams(labName, vmId, newTemplateName, newTemplateDesc)

                fullTemplate = {
                    'properties': {
                        'mode': 'Incremental',
                        'template': template,
                        'parameters': paramData
                    }
                }

                result = self.__deployArmTemplate(subscriptionId, rgName, fullTemplate)

                return 0

        self._printService.error('Cannot find virtual machine with id {0}'.format(vmId))
        return 1

    def getVirtualMachinesForLab(self, subscriptionId, labName):
        """Retrieves the list of virtual machines in environments within the specified lab for the specified subscription.

        Args:
            subscriptionId (string) - The subscription ID to a corresponding subscription containing the specified lab.
            labName (string) - The name used to identify the lab in which to filter the results.
        Returns:
            A list of virtual machine objects representing the virtual machines included in the specified lab.

        Result format examples:
        [
            {
                "userName": "<someuser>",
                "artifactDeploymentStatus": {
                    "artifactsApplied": 0,
                    "totalArtifacts": 0
                },
                "name": "<somevmname>",
                "fqdn": "<somevmname>.westus.cloudapp.azure.com",
                "builtInUserName": "<someuser>",
                "vmTemplateName": "Ubuntu Server 14_04 LTS",
                "size": "Standard_A0"
            }
        ]
        """
        lab = self.getLabByName(labName)

        if lab is None:
            self._printService.error('Lab {0} does not exist or is not accessible.'.format(labName))
            return []

        labId = lab["id"]
        rgName = self.__getResourceGroupFromLab(labId)
        envs = self.__getEnvironmentsForLab(subscriptionId, rgName, labName)

        allVms = []

        for env in envs['value']:
            vms = env['properties']['vms']

            for vm in vms:
                # Fetching and setting the resource ID may be removed once the GET environments API returns the ID in
                # the payload.
                resourceId = self.__getVirtualMachineResourceId(env['id'], self._computeResourceName)

                if resourceId is not None:
                    vm['id'] = resourceId
                    allVms.append(vm)

        return allVms

    def getVirtualMachine(self, subscriptionId, vmId):

        url = '/subscriptions/{0}/providers/microsoft.devtestlab/environments/?$filter=tolower(Id)%20eq%20tolower(%27{1}%27)&api-version={2}'.format(
            subscriptionId,
            vmId,
            self._apiVersion
        )

        api = azurerest.AzureRestHelper(self._settings, self._settings.accessToken, self._host)
        return api.get(url, self._apiVersion)


    def __getResourceGroupFromLab(self, labId):
        """Retrieves the resource group name from the lab service based on the lab with the specified labName.

        Args:
           labId (string) - The URI that uniquely identifies the lab
        Returns:
            A string value containing the name of the resource group which contains the lab with the specified labName.
            For example:

            "myresourcegroup"
        """
        p = re.compile(self._rgRegex)
        m = p.match(labId)

        if m is None:
            self._printService.error("The lab URI as returned by the lab is invalid.")
            return None

        return m.group(1)

    def __getVirtualMachineResourceId(self, environmentId, computeResourceType):

        p = re.compile(self._envRegex)

        vmId = p.sub(computeResourceType, environmentId)

        return vmId

    def __getEnvironmentsForLab(self, subscriptionId, resourceGroupName, labName):

        url = '/subscriptions/{0}/providers/microsoft.devtestlab/environments/?$filter=tolower(Properties/LabId)%20eq%20tolower(%27/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.DevTestLab/labs/{2}%27)&api-version={3}'.format(
            subscriptionId,
            resourceGroupName,
            labName,
            self._apiVersion
        )

        api = azurerest.AzureRestHelper(self._settings, self._settings.accessToken, self._host)
        return api.get(url, self._apiVersion)

    def __deployArmTemplate(self, subscriptionId, resourceGroupName, armTemplate):

        deplName = resourceGroupName + '_' + datetime.utcnow().strftime('%m%d%Y_%H%M%S%f')

        url = '/subscriptions/{0}/resourceGroups/{1}/providers/microsoft.resources/deployments/{2}?api-version={3}'.format(
            subscriptionId,
            resourceGroupName,
            deplName,
            self._crpApiVersion
        )

        api = azurerest.AzureRestHelper(self._settings, self._settings.accessToken, self._host)

        self._printService.info('Creating Azure deployment...')

        if api.put(url, json.dumps(armTemplate), self._crpApiVersion) is None:
            self._printService.error('Azure deployment could not be created')
            return 1

        self._printService.info(
            'Azure deployment {0} created, waiting for completion (Job status == Succeeded)'.format(deplName))

        # Poll the service for completion of our deployment
        opUrl = '/subscriptions/{0}/resourceGroups/{1}/providers/microsoft.resources/deployments/{2}?api-version={3}'.format(
            subscriptionId,
            resourceGroupName,
            deplName,
            self._crpApiVersion)

        output = {}

        while True:
            statusPayload = api.get(opUrl, self._crpApiVersion)

            if statusPayload is not None:
                statusCode = statusPayload["properties"]["provisioningState"]

                self._printService.info('Job status: {0}'.format(statusCode))

                if statusCode == "Conflict" or statusCode == "Failed":
                    self._printService.error("Deployment failed!")

                    opUrl = '/subscriptions/{0}/resourceGroups/{1}/providers/microsoft.resources/deployments/{2}/operations?api-version={3}'.format(
                        subscriptionId,
                        resourceGroupName,
                        deplName,
                        self._crpApiVersion)

                    op = api.get(opUrl, self._crpApiVersion)

                    if op is not None and len(op['value']) > 0:
                        currentOp = op['value'][0]
                        self._printService.dumps(currentOp["properties"]["statusMessage"])

                    return 1

                if statusCode == 'Succeeded':
                    if statusPayload["properties"]["outputs"] is not None:
                        output = statusPayload["properties"]["outputs"]
                        self._printService.dumpp(output)
                    break

            self._printService.verbose('Sleeping for {0} second(s)...'.format(self._sleepTime))
            time.sleep(self._sleepTime)

        return 0, output

    def __getTemplateParams(self, labName, vmName, templateName, size, userName, password, sshPublicKey):
        data = {
            'newVMName': {
                'value': '{0}'.format(vmName)
            },
            'existingLabName': {
                'value': '{0}'.format(labName),
            },
            'existingVMTemplateName': {
                'value': '{0}'.format(templateName),
            },
            'newVMSize': {
                'value': '{0}'.format(size)
            }
        }

        if userName is not None:
            data['userName'] = {
                'value': userName
            }

        if password is not None:
            data['password'] = {
                'value': password
            }

        if sshPublicKey is not None:
            data['sshKey'] = {
                'value': sshPublicKey
            }

        return data

    def __getNewVmTemplateParams(self, labName, vmId, newTemplateName, newTemplateDesc):
        data = {
            'existingLabName': {
                'value': '{0}'.format(labName)
            },
            'existingVMResourceId': {
                'value': '{0}'.format(vmId),
            },
            'TemplateName': {
                'value': '{0}'.format(newTemplateName),
            },
            'TemplateDescription': {
                'value': '{0}'.format(newTemplateDesc)
            }
        }

        return data

    # Consts
    _crpApiVersion = '2015-11-01'
    _crpVirtualMachineApiVersion = '2015-05-01-preview'
    _apiVersion = '2015-05-21-preview'
    _computeResourceName = 'Microsoft.Compute/virtualMachines'
    _host = 'management.azure.com'
    _getLabsBaseUrl = '/subscriptions/{0}/providers/Microsoft.DevTestLab/labs/?api-version={1}'
    _rgRegex = '\/subscriptions\/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\/resourceGroups\/([A-Za-z0-9].*)\/providers\/Microsoft.DevTestLab\/labs\/([A-Za-z0-9].*)'
    _envRegex = 'Microsoft.DevTestLab\/environments'
    _sleepTime = 60
