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
import sys
import urllib


class AuthorizeTokenProvider:
    """Provides authorization services to the DTL CLI.

    Attributes:
        None

    """

    def provide(self, settings):
        """Retrieves an authorization token for the client ID and evidence provided from the command-line.

        Args:
            settings (dict) - A collection of system-level settings, including the parsed command-line.

        Returns:
            A base-64 encoded string containing a valid authorization token, None if one was not granted.
        """

        api = azurerest.AzureRestHelper(settings,
                                        host=self._host,
                                        headers={
                                            'Content-Type': 'application/x-www-form-urlencoded'
                                        })

        payload = {
            'resource': 'https://management.core.windows.net/',
            'client_id': settings.clientID,
            'client_secret': settings.secret,
            'grant_type': 'client_credentials'
        }

        tokenData = api.post(self._baseUrl.format(settings.tenant),
                             urllib.urlencode(payload),
                             self._apiVersion)

        if tokenData is None:
            print 'Cannot fetch authorization access token'
            sys.exit(1)

        if settings.verbose:
            print 'Authorization data:'
            print json.dumps(tokenData, indent=4)

        return tokenData['access_token']

    _apiVersion = '2015-01-01'
    _host = 'login.windows.net'
    _baseUrl = '/{0}/oauth2/token'
