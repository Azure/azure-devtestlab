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

import authority as auth
import auth_const
import code_request
import token_request


class AuthenticationContext:
    """Creates a new AuthenticationContext object.  By default the authority will be checked against
    a list of known Azure Active Directory authorities.  If the authority is not recognized as
    one of these well known authorities then token acquisition will fail.  This behavior can be
    turned off via the validateAuthority parameter below.

    Attributes:
        authority (string) - The authority used to represent the context.

    """

    def __init__(self, print_service, authority, validate_authority=True, cache=None):
        self._print_service = print_service
        self._oath2_client = None
        self._correlation_id = None
        self._cache = cache
        self._call_context = {
            'options': {

            }
        }
        self._token_request_with_user_code = {}
        self.authority = auth.Authority(self._print_service, authority, validate_authority)

        return

    def acquire_user_code(self, resource, client_id, language):
        """Gets the userCodeInfo which contains user_code, device_code for authenticating user on device.

        Args:

        Returns:
            result (bool) - True if successful, False otherwise
            response (dict) - The response object returned from the REST call.

        """

        success, result = self.authority.validate(self._call_context)

        if not success:
            self._print_service.error(result)
            return False, result

        request = code_request.CodeRequest(self._print_service, self._call_context, self, client_id, resource)
        success, response = request.get_user_code_info(language)

        return success, response

    def acquire_token_with_device_code(self, resource, client_id, user_code_info):
        self.__validate_user_code_info(user_code_info)
        self.authority.validate(self._call_context)

        request = token_request.TokenRequest(self._print_service, self._call_context, self, client_id, resource, None)
        self._token_request_with_user_code[
            user_code_info[auth_const.OAuth2.UserCodeResponseFields.DEVICE_CODE]] = token_request

        return request.get_token_with_device_code(user_code_info)

    @staticmethod
    def __validate_user_code_info(user_code_info):
        if user_code_info is None:
            raise StandardError('The user_code_info parameter is required')

        if auth_const.OAuth2.UserCodeResponseFields.DEVICE_CODE not in user_code_info:
            raise StandardError('Missing required value for device_code')

        if auth_const.OAuth2.UserCodeResponseFields.INTERVAL not in user_code_info:
            raise StandardError('Missing required value for interval')

        if auth_const.OAuth2.UserCodeResponseFields.EXPIRES_IN not in user_code_info:
            raise StandardError('Missing required value for expires_in')

        return

    authority = ''
