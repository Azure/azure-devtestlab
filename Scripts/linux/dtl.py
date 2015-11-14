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

import sys
import argparse
import dtlcommands
import dtlprint
import dtlproviders


class DevTestLabsMain:
    """The boostrap used to instantiate the DTL CLI

    Attributes:
        _argParser [private] (ArgumentParser) - The argument parser used to present the CLI interface and parse the command-line.
        _parsedArgs [private] (dict) - The results of the parsing of command-line arguments by the parser(s).


    Examples:

        # Retrieve an access token for use when making requests to Azure resources in the lab
        python dtl.py <principal id> <my tenant ID> <my secret> <my subscription> auth

        # Get information about my lab
        python dtl.py <principal id> <my tenant ID> <my secret> <my subscription> labs -l=TestLab

        # Create a new lab virtual machine
        python dtl.py <principal id> <my tenant ID> <my secret> <my subscription> createvm -l=TestLab -n=MyNewVm -tn="Ubuntu Server 14_04 LTS" -s="Standard_A1"

    """

    def run(self):
        """Runs the CLI main entry-point, invoking the action provided by the argument parser.

        Args:
            None

        Returns:
            0 if successful, 1 otherwise.
        """
        self.__ensureAuthenticated()

        returnValue = self._parsedArgs.func(self._parsedArgs)

        if returnValue != 0:
            sys.exit(returnValue)
        else:
            self._printService.success('Action completed successfully')

        return

    def __generateSubArgsMap(self, argumentParser, actions):

        subParsers = argumentParser.add_subparsers(title='Actions')

        for action in actions:
            parser = subParsers.add_parser(action.getActionName(), help=action.getActionHelpText())
            action.buildArguments(parser)
            parser.set_defaults(func=action.invoke)

        return

    def __generateArgsMap(self, argumentParser, commands):

        for command in commands:
            command.buildArguments(argumentParser)

        return

    def __ensureAuthenticated(self):
        """Retrieves an authorization token for the principal"""
        provider = dtlproviders.AuthorizeTokenProvider()

        accessKey = provider.provide(self._parsedArgs)

        if self._parsedArgs.verbose:
            self._printService.info('Setting the authorization token')

        self._parsedArgs.accessToken = accessKey

    def __init__(self, *args, **kwargs):
        """Initializes the DevTestLabMain class

        Args:
            None

        Returns:
            None
        """
        self._argParser = argparse.ArgumentParser(usage=self._usage,
                                                  description=self._description,
                                                  version=self._version)

        #
        # Add new command definitions to the commands list below:
        #

        self._commands = [
            dtlcommands.AuthenticationCommands(),
            dtlcommands.SubscriptionCommands()
        ]

        self._actions = [
            dtlcommands.AuthorizeCommandAction(),
            dtlcommands.LabsCommandAction(),
            dtlcommands.CreateVirtualMachineAction()
        ]

        self.__generateArgsMap(self._argParser, self._commands)
        self.__generateSubArgsMap(self._argParser, self._actions)

        self._parsedArgs = self._argParser.parse_args()

        self._printService = dtlprint.PrintService(self._parsedArgs.quiet, self._parsedArgs.verbose)

        self._printService.verbose('Parsed argument(s):')
        self._printService.verbose(self._parsedArgs)

        return

    # Private consts
    _usage = 'dtl.py <principal> <tenant ID> <secret> <subscription ID> action'
    _description = 'Provides command-line access to Azure DevTest Labs'
    _version = '0.1.0'


main = DevTestLabsMain()
main.run()
