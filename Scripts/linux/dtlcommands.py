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

import dtllabservice
import dtlprint
import os


class AuthenticationCommands:
    """Adds authorization arguments to the argument set.

    Attributes:
        None
    """

    def buildArguments(self, argParser):
        """Constructs the command-line arguments used to support this command.

        Args:
            argParser (ArgumentParser) - the arguments parser used to parse the command-line.

        Returns:
            None
        """
        argParser.add_argument_group('Authentication')
        argParser.add_argument('-c',
                               dest='clientID',
                               required=False,
                               help='Your Azure Application/Client ID')
        argParser.add_argument('-S',
                               dest='secret',
                               help='Your Client secret.',
                               required=False)
        argParser.add_argument('-t',
                               dest='tenant',
                               help='Your tenant ID. See https://msdn.microsoft.com/en-us/library/azure/dn790557.aspx for more information.',
                               required=False)
        return


class SubscriptionCommands:
    """ Adds subscription ID to the argument set.

    Attributes:
        None
    """

    def buildArguments(self, argParser):
        """Constructs the command-line arguments used to support this command.

        Args:
            argParser (ArgumentParser) - the arguments parser used to parse the command-line.

        Returns:
            None
        """

        argParser.add_argument('-s', dest='subscription', help='Your Azure subscription ID')


class ActionsCommands:
    """Authenticates the clientID based on provided evidence

    Attributes:
        None
    """

    def buildArguments(self, argParser):
        """Constructs the command-line arguments used to support this command.

        Args:
            argParser (ArgumentParser) - the arguments parser used to parse the command-line.

        Returns:
            None
        """
        actions = [
            AuthorizeCommandAction(),
            LabsCommandAction()
        ]

        self._actions = {}
        choices = []

        for action in actions:
            actionName = action.getActionName()
            choices.append(actionName)
            self._actions[actionName] = action

        argParser.add_argument_group('Actions')
        argParser.add_argument('action',
                               help='Performs the specified action.',
                               choices=choices)

        for action in actions:
            action.buildArguments(argParser)

        return

    def getActionByName(self, name):
        """Gets an action in the cache based on the specified name.

        Args:
            name (string) - The name of the argument in which to search.

        Returns:
            (CommandAction) a command action corresponding to the specified name, or None if one does not exist.
        """
        return self._actions[name]


class AuthorizeCommandAction:
    """ Requests an authorization token from the authorization service on the provided clientIDs' behalf.

    Attributes:
        None
    """

    def getActionName(self):
        """Gets the name of the action as it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """
        return 'auth'

    def getActionHelpText(self):
        """Gets the textual help of the action when it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """
        return 'Authorizes access to Azure resources'

    def invoke(self, settings):
        """ Returns the authorization token for the current clientID.

        Args:
            settings (dict) - A collection of system-level settings, including the parsed command-line.

        Returns:
            A base-64 encoded authorization token for use in subsequent requests.
        """

        # The access token is acquired prior to any action being executed, so just
        # print it out here.

        printService = dtlprint.PrintService(settings.quiet, settings.verbose)
        printService.info(settings.accessToken)

        return 0

    def buildArguments(self, argParser):
        """Constructs the command-line arguments used to support this command.

        Args:
            argParser (ArgumentParser) - the arguments parser used to parse the command-line.

        Returns:
            None
        """

        argParser.add_argument('-vb', '--verbose',
                               dest='verbose',
                               action='store_true',
                               help='Log verbose output to stdout')
        argParser.add_argument('-q', '--quiet',
                               dest='quiet',
                               action='store_true',
                               help='When set, suppresses tool messages from printing')

        return


class LabsCommandAction:
    def getActionName(self):
        """Gets the name of the action as it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """

        return 'labs'

    def getActionHelpText(self):
        """Gets the textual help of the action when it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """

        return 'Provides access to individual labs'

    def invoke(self, settings):
        """ Returns the labs that correspond to the lab name provided in the specified settings.

        Args:
            settings (dict) - A collection of system-level settings, including the parsed command-line.

        Returns:
            A lab object formatted as JSON corresponding to the lab name provided in the specified settings, or None of one does not exist.
        """

        labSvc = dtllabservice.LabService(settings, dtlprint.PrintService(settings.quiet, settings.verbose))
        printService = dtlprint.PrintService(settings.quiet, settings.verbose)

        printService.verbose('Getting lab {0}'.format(settings.labname))

        if settings.labname is not None:
            lab = labSvc.getLabByName(settings.labname)

            if lab is not None:
                printService.dumps(lab)
            else:
                printService.info('Lab {0} not found.'.format(settings.labname))
                return 1
        else:
            labs = labSvc.getLabs()

            if labs is not None:
                printService.dumps(labs)
            else:
                printService.error('Cannot retrieve labs from the lab service.')
                return 1

        return 0

    def buildArguments(self, argParser):
        """Constructs the command-line arguments used to support this command.

        Args:
            argParser (ArgumentParser) - the arguments parser used to parse the command-line.

        Returns:
            None
        """

        argParser.add_argument('-l', '--labname',
                               help='The name of the lab',
                               required=False)
        argParser.add_argument('-vb', '--verbose',
                               dest='verbose',
                               action='store_true',
                               help='Log verbose output to stdout')
        argParser.add_argument('-q', '--quiet',
                               dest='quiet',
                               action='store_true',
                               help='When set, suppresses tool messages from printing')

        return


class CreateVirtualMachineAction:
    """ Creates a lab virtual machine using arguments provided from the command-line.

    Attributes:
        None
    """

    def getActionName(self):
        """Gets the name of the action as it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """

        return 'newvm'

    def getActionHelpText(self):
        """Gets the textual help of the action when it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """

        return 'Creates a lab virtual machine based on additional parameters'

    def invoke(self, settings):
        """ Creates a virtual machine using the LabService class based on the specified virtual machine creation data.

        Args:
            settings (dict) - A collection of system-level settings, including the parsed command-line.

        Returns:
           0 if successful, 1 otherwise.
        """

        templateFilePath = self.__getTemplatePath(settings)
        printService = dtlprint.PrintService(settings.quiet, settings.verbose)

        printService.info('Using ARM template: {0}'.format(templateFilePath))

        settings.vmTemplateFileName = templateFilePath
        labSvc = dtllabservice.LabService(settings, printService)

        return labSvc.createVm(settings.subscription,
                               templateFilePath,
                               settings.labname,
                               settings.name,
                               settings.templatename,
                               settings.size,
                               settings.vmusername,
                               settings.vmpassword,
                               settings.vmsshkey)

    def buildArguments(self, argParser):
        """Constructs the command-line arguments used to support this command.

        Args:
            argParser (ArgumentParser) - the arguments parser used to parse the command-line.

        Returns:
            None
        """

        argParser.add_argument('-l', '--labname',
                               help='The name of the lab',
                               required=True)
        argParser.add_argument('-n', '--name',
                               help='The name of the new virtual machine',
                               required=True)
        argParser.add_argument('-tn', '--templatename',
                               help='The name of the base image template to use',
                               required=True)
        argParser.add_argument('-sz', '--size',
                               help='The size of the new virtual machine',
                               required=True,
                               default='Standard_A1')
        argParser.add_argument('-vu', '--vmusername',
                               help='The user name of the new virtual machine',
                               required=False)
        argParser.add_argument('-vp', '--vmpassword',
                               help='The password of the new virtual machine',
                               required=False)
        argParser.add_argument('-ssh', '--vmsshkey',
                               help='The SSH key of the new virtual machine',
                               required=False)
        argParser.add_argument('-vb', '--verbose',
                               dest='verbose',
                               action='store_true',
                               help='Log verbose output to stdout')
        argParser.add_argument('-q', '--quiet',
                               dest='quiet',
                               action='store_true',
                               help='When set, suppresses tool messages from printing')

        return

    def __getTemplatePath(self, settings):

        hasUserName = False
        hasPassword = False
        hasSshKey = False

        if settings.vmusername is not None:
            hasUserName = True

        if settings.vmpassword is not None:
            hasPassword = True

        if settings.vmsshkey is not None:
            hasSshKey = True

        if hasUserName or hasPassword or hasSshKey:
            if hasPassword:
                templatePath = '101-dtl-create-vm-username-pwd'
            else:
                templatePath = '101-dtl-create-vm-username-ssh'
        else:
            templatePath = '101-dtl-create-vm-builtin-user'

        return os.path.dirname(os.path.realpath(__file__)) + '/templates/{0}/azuredeploy.json'.format(templatePath)

    # Consts
    _host = 'management.azure.com'


class CreateVirutalMachineTemplateAction:
    """Creates a lab virtual machine template using the arguments provided from the command-line

    Attributes:
        None

    """

    def getActionName(self):
        """Gets the name of the action as it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """
        return 'newvmtemplate'

    def getActionHelpText(self):
        """Gets the textual help of the action when it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """

        return 'Creates a new virtual machine template from an existing virtual machine in the lab.'

    def buildArguments(self, argParser):
        """Constructs the command-line arguments used to support this command.

        Args:
            argParser (ArgumentParser) - the arguments parser used to parse the command-line.

        Returns:
            None
        """

        argParser.add_argument('-l', '--labname',
                               help='The name of the lab',
                               required=True)
        argParser.add_argument('-vid', '--vmid',
                               help='The id of the new virtual machine',
                               required=True)
        argParser.add_argument('-tn', '--templatename',
                               help='The name of the template to create',
                               required=True)
        argParser.add_argument('-d', '--desc',
                               help='The description of the new virtual machine template')
        argParser.add_argument('-vb', '--verbose',
                               dest='verbose',
                               action='store_true',
                               help='Log verbose output to stdout')
        argParser.add_argument('-q', '--quiet',
                               dest='quiet',
                               action='store_true',
                               help='When set, suppresses tool messages from printing')

        return

    def invoke(self, settings):
        """ Creates a virtual machine template from an existing virtual machine using the LabService.

        Args:
            settings (dict) - A collection of system-level settings, including the parsed command-line.

        Returns:
           0 if successful, 1 otherwise.
        """

        printService = dtlprint.PrintService(settings.quiet, settings.verbose)
        templateNameMaxLen = 27

        if len(settings.templatename) > templateNameMaxLen:
            printService.error(
                'Template name must be a valid string with a maximum length of {0}'.format(templateNameMaxLen))
            return 1

        labSvc = dtllabservice.LabService(settings, printService)
        templateFilePath = os.path.dirname(
            os.path.realpath(__file__)) + '/templates/201-dtl-create-vmtemplate/azuredeploy.json'

        return labSvc.createVmTemplate(settings.labname,
                                       settings.subscription,
                                       settings.vmid,
                                       settings.templatename,
                                       settings.desc,
                                       templateFilePath)


class VirtualMachinesAction:
    """Lists a filtered set of virtual machines from your lab.

    Attributes:
        None

    """

    def getActionName(self):
        """Gets the name of the action as it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """
        return 'vms'

    def getActionHelpText(self):
        """Gets the textual help of the action when it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """

        return 'Provides access to virtual machines in your lab.'

    def buildArguments(self, argParser):
        """Constructs the command-line arguments used to support this command.

        Args:
            argParser (ArgumentParser) - the arguments parser used to parse the command-line.

        Returns:
            None
        """

        argParser.add_argument('-l', '--labname',
                               help='The name of the lab',
                               required=True)
        argParser.add_argument('-n', '--name',
                               help='The name of the virtual machine to retrieve.',
                               required=False)
        argParser.add_argument('-vid',
                               dest='vmid',
                               help='The id of the virtual machine to retrieve.',
                               required=False)
        argParser.add_argument('--d', '--delete',
                               dest='deletevm',
                               action='store_true',
                               help='Deletes the virtual machine resource from the lab.',
                               required=False)
        argParser.add_argument('-vb', '--verbose',
                               dest='verbose',
                               action='store_true',
                               help='Log verbose output to stdout')
        argParser.add_argument('-q', '--quiet',
                               dest='quiet',
                               action='store_true',
                               help='When set, suppresses tool messages from printing')

        return

    def invoke(self, settings):
        """ Creates a virtual machine template from an existing virtual machine using the LabService.

        Args:
            settings (dict) - A collection of system-level settings, including the parsed command-line.

        Returns:
           0 if successful, 1 otherwise.
        """

        printService = dtlprint.PrintService(settings.quiet, settings.verbose)
        labSvc = dtllabservice.LabService(settings, printService)

        if settings.deletevm and (
                        settings.name is not None or settings.vmid is not None) and settings.labname is not None:
            return labSvc.deleteVirtualMachine(settings.subscription, settings.labname, settings.name, settings.vmid)
        else:
            if settings.name is not None:
                vms = labSvc.getVirtualMachine(settings.subscription, name=settings.name)
            elif settings.vmid is not None:
                vms = labSvc.getVirtualMachine(settings.subscription, vmId=settings.vmid)
            else:
                vms = labSvc.getVirtualMachinesForLab(settings.subscription, settings.labname)

            # Coalesce the two different results into a list of virtual machines.
            if 'value' in vms:
                vms = vms['value']

            if len(vms) > 0:
                printService.info('Virtual machine(s):')
                printService.dumps(vms)
            else:
                printService.error('No virtual machines found.')
                return 1

            return 0


class VirtualMachineTemplatesAction:
    """Lists a filtered set of virtual machine templates from your lab.

    Attributes:
        None

    """

    def getActionName(self):
        """Gets the name of the action as it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """
        return 'vmtemplate'

    def getActionHelpText(self):
        """Gets the textual help of the action when it is displayed in the command-line help.

        Args:
            None

        Returns:
            None
        """

        return 'Lists a filtered set of virtual machine templates created in your lab.'

    def buildArguments(self, argParser):
        """Constructs the command-line arguments used to support this command.

        Args:
            argParser (ArgumentParser) - the arguments parser used to parse the command-line.

        Returns:
            None
        """

        argParser.add_argument('-l', '--labname',
                               help='The name of the lab',
                               required=True)
        argParser.add_argument('-n', '--name',
                               help='The name of the virtual machine template to retrieve.',
                               required=False)
        argParser.add_argument('-vb', '--verbose',
                               dest='verbose',
                               action='store_true',
                               help='Log verbose output to stdout')
        argParser.add_argument('-q', '--quiet',
                               dest='quiet',
                               action='store_true',
                               help='When set, suppresses tool messages from printing')

        return

    def invoke(self, settings):
        """ Lists virtual machine templates using the LabService.

        Args:
            settings (dict) - A collection of system-level settings, including the parsed command-line.

        Returns:
           0 if successful, 1 otherwise.
        """

        printService = dtlprint.PrintService(settings.quiet, settings.verbose)
        labSvc = dtllabservice.LabService(settings, printService)

        templates = labSvc.getVirtualMachineTemplates(settings.subscription, settings.labname, settings.name)

        if templates is not None and len(templates) > 0:
            printService.info('Virtual machine template(s):')
            printService.dumps(templates)
        else:
            printService.error('No virtual machine templates found.')
            return 1

        return 0
