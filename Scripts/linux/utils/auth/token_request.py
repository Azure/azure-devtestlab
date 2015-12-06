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


class TokenRequest:
    """Provides a client for requesting an access token from the configured Authority.

    Attributes:
        None
    Examples:
        None
    """

    def __init__(self, print_service, call_context, authentication_context, client_id, resource, redirect_uri):
        """Constructs a new TokenRequest object.

        Arguments:
            print_service (PrintService) - The print service used to write to stdout and stderr.

        """
        self._print_service = print_service
        self._call_context = call_context
        self._authentication_context = authentication_context
        self._client_id = client_id
        self._resource = resource
        self._redirect_uri = redirect_uri
        self._polling_client = {}

        return

    def get_token_with_device_code(self, user_code_info):
        """Acquires an authorization token based on the specified configuration.

        Args:
            user_code_info (UserCodeInfo) - The configuration used to acquire the token.
        Returns:
            A TokenResponse object containing the token response.

        Example inputs:

        """
        self._print_service.info('Getting a token via device code')

        oauth_parameters = self.__create_oauth_parameters(auth_const.GrantType.DEVICE_CODE)
        oauth_parameters[auth_const.OAuth2.Parameters.CODE] = user_code_info[
            auth_const.OAuth2.UserCodeResponseFields.DEVICE_CODE]

        interval = user_code_info[auth_const.OAuth2.UserCodeResponseFields.INTERVAL]
        expires_in = user_code_info[auth_const.OAuth2.UserCodeResponseFields.EXPIRES_IN]

        if interval <= 0:
            raise StandardError('invalid refresh interval')

        try:
            token_response = self.__oauth_get_token_by_polling(oauth_parameters, interval, expires_in)
        except Exception as ex:
            self._print_service.verbose('Token polling request returned with err.')
            raise StandardError(ex)

        self.__add_token_into_cache(token_response)
        return

    def __create_oauth_parameters(self, grant_type):
        def __add_parameter_if_available(parameters, key, value):
            if value:
                parameters[key] = value

        oauth_parameters = {auth_const.GrantType: grant_type}

        if (auth_const.GrantType.AUTHORIZATION_CODE != grant_type and
                auth_const.GrantType.CLIENT_CREDENTIALS != grant_type and
                auth_const.GrantType.REFRESH_TOKEN != grant_type and
                auth_const.GrantType.DEVICE_CODE != grant_type):
            oauth_parameters[auth_const.OAuth2.Parameters.SCOPE] = auth_const.OAuth2.Scope.OPENID

        __add_parameter_if_available(oauth_parameters, auth_const.OAuth2.Parameters.CLIENT_ID, self._client_id)
        __add_parameter_if_available(oauth_parameters, auth_const.OAuth2.Parameters.RESOURCE, self._resource)
        __add_parameter_if_available(oauth_parameters, auth_const.OAuth2.Parameters.REDIRECT_URI, self._redirect_uri)

        return oauth_parameters

    def __oauth_get_token_by_polling(self, oauth_parameters, interval, expires_in):
        client = oauth2_client.OAuth2Client(
            self._print_service,
            self._call_context,
            self._authentication_context.authority)

        client.get_token_with_polling(oauth_parameters, interval, expires_in)
        self._polling_client = client

        return self._polling_client

    def __add_token_into_cache(self, token_response):
        return
