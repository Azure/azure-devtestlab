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

    def createVm(self, subscriptionId, vmTemplateFileName, labName, vmName, templateName, size, vmUserName, vmPassword,
                 vmSshKey):
        """Creates a lab virtual machine based on the specified subscription, template, and other misc parameters.

        Args:
            subscriptionId (string) - The subscription ID used to create the virtual machine.
            vmTemplateFileName (string) - The path to an Azure RM template representing the configuration of the new virtual machine.
            labName (string) - The name of the lab used to create the virtual machine.
            vmUserName (string) - The user name, if provided, of the administrative user account created on the virtual machine.
            vmPassword (string) - The password, if provided, of the administrative user account created on the virtual machine.
            vmSshKey (string) - The SSH public key for use when connecting to the virtual machine.

        Returns:
            0 if successful, 1 othwerise.
        """

        lab = self.getLabByName(labName)

        if lab is None:
            self._printService.error('Lab {0} does not exist or is not accessible.'.format(labName))
            return 1

        deplName = vmName + '_depl'
        rgName = self.__getResourceGroupFromLab(lab["id"])

        url = '/subscriptions/{0}/resourceGroups/{1}/providers/microsoft.resources/deployments/{2}?api-version={3}'.format(
            subscriptionId,
            rgName,
            deplName,
            self._crpApiVersion
        )

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

        api = azurerest.AzureRestHelper(self._settings, self._settings.accessToken, self._host)

        self._printService.info('Creating Azure deployment...')

        if api.put(url, json.dumps(fullTemplate), self._crpApiVersion) is None:
            self._printService.error('Azure deployment could not be created')
            return 1

        self._printService.info('Azure deployment {0} created, waiting for completion'.format(deplName))

        # Poll the service for completion of our deployment
        opUrl = '/subscriptions/{0}/resourceGroups/{1}/providers/microsoft.resources/deployments/{2}?api-version={3}'.format(
            subscriptionId,
            rgName,
            deplName,
            self._crpApiVersion)

        while True:
            statusPayload = api.get(opUrl, self._crpApiVersion)

            if statusPayload is not None:
                statusCode = statusPayload["properties"]["provisioningState"]

                self._printService.info('Job status: {0}'.format(statusCode))

                if statusCode == "Conflict" or statusCode == "Failed":
                    self._printService.error("Deployment failed!")

                    opUrl = '/subscriptions/{0}/resourceGroups/{1}/providers/microsoft.resources/deployments/{2}/operations?api-version={3}'.format(
                        subscriptionId,
                        rgName,
                        deplName,
                        self._crpApiVersion)

                    op = api.get(opUrl, self._crpApiVersion)

                    if op is not None:
                        self._printService.info(json.dumps(op["properties"]["statusMessage"], indent=4))

                    return 1

                if statusCode == 'Succeeded':
                    if statusPayload["properties"]["outputs"] is not None:
                        self._printService.dumpp(statusPayload["properties"]["outputs"])
                    break

            self._printService.verbose('Sleeping for {0} second(s)...'.format(self._sleepTime))
            time.sleep(self._sleepTime)

        return 0

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

    # Consts
    _crpApiVersion = '2015-01-01'
    _apiVersion = '2015-05-21-preview'
    _host = 'management.azure.com'
    _getLabsBaseUrl = '/subscriptions/{0}/providers/Microsoft.DevTestLab/labs/?api-version={1}'
    _rgRegex = '\/subscriptions\/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\/resourceGroups\/([A-Za-z0-9].*)\/providers\/Microsoft.DevTestLab\/labs\/([A-Za-z0-9].*)'
    _sleepTime = 60
