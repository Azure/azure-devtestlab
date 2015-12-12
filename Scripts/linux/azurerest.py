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

import httplib
import json


class AzureRestHelper:
    """Provides a basic web client implementation based on the core module 'httplib'

    The DTL CLI is designed to run on any *nix distro (including OSX) without any
    additional dependencies.  To support this, AzureRestHelper adds basic REST support
    to the httplib module to provide a more intelligent web client for use in the DTL
    CLI.

    Attributes:
        None

    """

    def __init__(self, settings, accessToken=None, host=None, headers=None):
        """Initializes the AzureRestHelper class with the specified settings, access token, host, and header(s)

        Args:
            settings (dict) - A collection of system-level settings, including any parsed arguments.
            accessToken (string) - A base-64 encoded string containing the authorization token used for making secure web requests to the service.
            host (string) - The name of the host used to form the fully-qualified-URL of the web request.
            headers (dict) - A collection of optional headers to include in the web request.
        Returns:
            None
        """
        self._settings = settings
        self._accessToken = accessToken

        if host is not None:
            self._host = host
        else:
            self._host = 'management.azure.com'

        self._userHeaders = headers

    def get(self, url, apiVersion):
        """Performs an HTTP GET operation

        Args:
            url (string) - the URL of the resource to retrieve.
            apiVersion (string) - the API version of the resource provider used to retrieve the resource.

        Returns:
            The body formatted as JSON for the resource returned from the specified URL.
        """
        verb = 'GET'
        headers = self.__getHeaders(apiVersion)

        result, response, bodyStr = self.__webrequest(verb, url, headers, apiVersion)
        return self.__deserializeBody(bodyStr)

    def delete(self, url, apiVersion):
        """Performs an HTTP DELETE operation

        Args:
            url (string) - the URL of the resource to delete.
            apiVersion (string) - the API version of the resource provider used to delete the resource.

        Returns:
            A boolean value indicating whether the request was successful.
            A response object containing the response from the DELETE request.
        """
        verb = 'DELETE'
        headers = self.__getHeaders(apiVersion)

        result, response, bodyStr = self.__webrequest(verb, url, headers, apiVersion)

        return result, response, self.__deserializeBody(bodyStr)

    def post(self, url, body, apiVersion):
        """Performs an HTTP POST operation

        Args:
            url (string) - the URL of the resource to retrieve.
            body (string) - The string value containing the body of the request.  This is typically a JSON object converted to a string via json.dumps().
            apiVersion (string) - the API version of the resource provider used to retrieve the resource.

        Returns:
            The response body formatted as JSON for the resource returned from the specified URL.
        """
        verb = 'POST'
        headers = self.__getHeaders(apiVersion)

        return self.__webrequest(verb, url, headers, apiVersion, body)

    def put(self, url, body, apiVersion):
        """Performs an HTTP PUT operation

        Args:
            url (string) - the URL of the resource to retrieve.
            body (string) - The string value containing the body of the request.  This is typically a JSON object converted to a string via json.dumps().
            apiVersion (string) - the API version of the resource provider used to retrieve the resource.

        Returns:
            The body formatted as JSON for the resource returned from the specified URL.
        """

        verb = 'PUT'
        headers = self.__getHeaders(apiVersion)

        result, response, bodyStr = self.__webrequest(verb, url, headers, apiVersion, body)
        return self.__deserializeBody(bodyStr)

    def __deserializeBody(self, bodyStr):
        body = None

        try:
            if self._settings.verbose:
                print 'Response Body:'
                print bodyStr

            if bodyStr is not None:
                body = json.loads(bodyStr)
        except:
            pass

        return body

    def __getHeaders(self, apiVersion):
        coreHeaders = {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'x-ms-version': apiVersion
        }

        if self._accessToken:
            coreHeaders['Authorization'] = 'Bearer {0}'.format(self._accessToken)

        if self._userHeaders is not None:
            for key in self._userHeaders:
                coreHeaders[key] = self._userHeaders[key]

        return coreHeaders

    def __webrequest(self, verb, url, headers, apiVersion, body=None):
        if self._settings.verbose:
            print 'Performing a {0} on host {1}, url {2}, and API version {3}'.format(
                verb,
                self._host,
                url,
                apiVersion)

            print 'Headers'
            print json.dumps(headers, indent=4)
            print 'Request Body:'
            print body

        conn = httplib.HTTPSConnection(self._host, 443)

        try:
            conn.request(verb, url, body, headers=headers)

            response = conn.getresponse()
            bodyStr = response.read()

            if response.status < 200 or response.status >= 300:
                print '{0} request failed: {1}'.format(verb, response.status)
                return False, response, bodyStr

            return True, response, bodyStr

        except httplib.HTTPException as e:
            print 'Error during {0}:{1}'.format(verb, url)
            print e.code, '-', e.reason
            print e.message
            return None
        finally:
            conn.close()
