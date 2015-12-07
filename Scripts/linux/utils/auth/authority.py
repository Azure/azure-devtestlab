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

import urlparse


class Authority:
    """
    Attributes:
        token_endpoint (string) - Gets the endpoint used to acquire a token
        device_code_endpoint (string) - Gets the url used by the user to complete their login
    """
    def __init__(self, authority_url, validate_authority):
        self._url = authority_url
        self._parsed_url = urlparse.urlparse(self._url)
        self.__validate_authority_url()

        self._validated = not validate_authority
        self._host = None
        self._tenant = None
        self.__parse_authority()

        self._authorization_endpoint = None

        self.token_endpoint = None
        self.device_code_endpoint = None

        return

    def __validate_authority_url(self):
        if self._parsed_url.scheme != 'https':
            raise StandardError('The authority url must be an HTTPS end-point.')

        if self._parsed_url.query:
            raise StandardError('The authority url must not contain a query string.')

        return

    def __parse_authority(self):
        self._host = self._parsed_url.hostname

        path_parts = self._parsed_url.path.split('/')
        self._tenant = path_parts[1]

        if self._tenant is None:
            raise StandardError('Could not determine tenant')

        return
