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
import json
import urllib
import urlparse
import util


class Authority:
    """
    Attributes:
        token_endpoint (string) - Gets the endpoint used to acquire a token
        device_code_endpoint (string) - Gets the url used by the user to complete their login
    """

    def __init__(self, print_service, authority_url, validate_authority):
        self._print_service = print_service
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

    def validate(self, call_context):
        """Validates the authority, creating a valid token endpoint.

        Args:
            call_context: The caller context.
        Returns:
            None
        Raises:
            StandardError() when the authority is invalid.
        """

        if not self._validated:
            self._print_service.verbose('Performing instance discovery: {0}'.format(self._url))

            success, result = self.__validate_via_instance_discovery()

            if not success:
                return False, result

            self._validated = True
            self.__get_oauth_endpoints(result)
        else:
            self._print_service.verbose(
                    'Instance discovery/validation has either already been completed or is turned off: {0}'.format(
                            self._url))

            self.__get_oauth_endpoints()

        return True, None

    def __get_oauth_endpoints(self, tenant_discovery_endpoint=None):

        if self.token_endpoint is not None and self.device_code_endpoint is not None:
            return

        if self.token_endpoint is None:
            self.token_endpoint = self._url + auth_const.OAuth2.AADConstants.TOKEN_ENDPOINT_PATH

        if self.device_code_endpoint is None:
            self.device_code_endpoint = self._url + auth_const.OAuth2.AADConstants.DEVICE_ENDPOINT_PATH

        return

    def __validate_via_instance_discovery(self):
        if not self.__perform_static_instance_discovery():
            return self.__perform_dynamic_instance_discovery()

        return True, None

    def __perform_static_instance_discovery(self):
        self._print_service.verbose('Performing static instance discovery')

        all_hosts = auth_const.OAuth2.AADConstants.WELL_KNOWN_AUTHORITY_HOSTS
        index = all_hosts.index(self._parsed_url.hostname)
        found = index >= 0

        if found:
            self._print_service.verbose('Authority validated via static instance discovery.')

        return found

    def __perform_dynamic_instance_discovery(self):

        try:
            discovery_endpoint = self.__create_instance_discovery_endpoint_from_template(
                    auth_const.OAuth2.AADConstants.WORLD_WIDE_AUTHORITY)

            get_options = util.create_request_options(self, {})

            self._print_service.verbose('Attempting instance discover at: ' + discovery_endpoint)

            request = util.Request(self._print_service)
            result, body = request.get(discovery_endpoint, get_options,
                                       util.DefaultRequestHandler('Instance Discovery', self._print_service))

            if result:
                parsed_body = json.loads(body)

                if 'tenant_discovery_endpoint' in parsed_body:
                    return True, parsed_body['tenant_discovery_endpoint']
                else:
                    return False, 'Failed to parse instance discovery response'

        except:
            return False

        return True

    def __create_instance_discovery_endpoint_from_template(self, authority_host):
        authority_url = 'https://{0}/{1}'.format(
                self._url.host,
                self._tenant + auth_const.OAuth2.AADConstants.AUTHORIZE_ENDPOINT_PATH
        )

        discovery_endpoint = auth_const.OAuth2.AADConstants.INSTANCE_DISCOVERY_ENDPOINT_TEMPLATE

        discovery_endpoint = discovery_endpoint.replace('{authorize_host}', authority_host)
        discovery_endpoint = discovery_endpoint.replace('{authorize_endpoint}', urllib.quote(authority_url))

        return urlparse.urlparse(discovery_endpoint)

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
