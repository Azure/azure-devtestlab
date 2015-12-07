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

import auth_const
import oauth2_client

class CodeRequest:
    def __init__(self, print_service, call_context, authentication_context, client_id, resource):
        self._print_service = print_service
        self._call_context = call_context
        self._authentication_context = authentication_context
        self._resource = resource
        self._client_id = client_id

        return

    def get_user_code_info(self, language):
        self._print_service.info('Getting user code info.')

        oauth_parameters = self.__create_oauth_parameters()

        if language is not None:
            oauth_parameters[auth_const.OAuth2.Parameters.LANGUAGE] = language

        return self.__get_user_code_info(oauth_parameters)

    def __get_user_code_info(self, oauth_parameters):
        client = oauth2_client.OAuth2Client(self._print_service, self._call_context, self._authentication_context.authority)

        return client.get_user_code_info(oauth_parameters)

    def __create_oauth_parameters(self):
        oauth_parameters = {auth_const.OAuth2.Parameters.CLIENT_ID: self._client_id,
                            auth_const.OAuth2.Parameters.RESOURCE: self._resource}

        return oauth_parameters
