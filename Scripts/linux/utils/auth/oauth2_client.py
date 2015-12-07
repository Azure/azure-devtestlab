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

import auth_const as const
import json
import urllib
import urlparse
import util


class OAuth2Client:
    def __init__(self, print_service, call_context, authority):
        self._print_service = print_service
        self._call_context = call_context
        self._authority = authority
        self._token_endpoint = authority.token_endpoint
        self._device_code_endpoint = authority.device_code_endpoint
        self._cancel_long_polling_request = False

        return

    def get_token_with_polling(self, oauth_parameters, interval, expires_in):
        raise NotImplementedError()

    def get_user_code_info(self, oauth_parameters):
        device_code_url = self.__create_device_code_url()
        url_encoded_device_code_request_form = urllib.urlencode(oauth_parameters)
        post_options = self.__create_post_option(device_code_url, url_encoded_device_code_request_form)

        request = util.Request(self._print_service)

        result, response = request.post(post_options,
                                        util.DefaultRequestHandler('Get Device Code', self._print_service))

        if result:
            self.__handle_get_device_code_response(response)

        return

    def __create_device_code_url(self):
        parsed = urlparse.urlparse(self._device_code_endpoint)

        parameters = {const.OAuth2.Parameters.AAD_API_VERSION: '1.0'}
        parsed.query = urllib.urlencode(parameters)

        return parsed

    def __create_post_option(self, post_url, url_encoded_request_form):
        options_data = {
            'url': urlparse.urlunparse(post_url),
            'body': url_encoded_request_form,
            'headers': {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            'encoding': 'utf-8'
        }

        post_options = util.create_request_options(self, options_data)
        return post_options

    def __handle_get_device_code_response(self, body):
        try:
            device_code_response = self.__validate_device_code_response(body)
        except Exception as ex:
            self._print_service.error('Error validating get user code response: ' + ex.message)
            return None

        return device_code_response

    def __validate_device_code_response(self, body):
        device_code_response = {}
        wire_response = None

        try:
            wire_response = json.loads(body)
        except:
            self._print_service.error('The device code response returned from the server is unparseable as JSON.')

        int_keys = [const.OAuth2.DeviceCodeResponseParameters.EXPIRES_IN,
                    const.OAuth2.DeviceCodeResponseParameters.INTERVAL]

        self.__parse_optional_ints(wire_response, int_keys)

        if const.OAuth2.DeviceCodeResponseParameters.EXPIRES_IN not in wire_response:
            raise StandardError('wire_response is missing expires_in')

        if const.OAuth2.DeviceCodeResponseParameters.DEVICE_CODE not in wire_response:
            raise StandardError('wire_response is missing device code')

        if const.OAuth2.DeviceCodeResponseParameters.USER_CODE not in wire_response:
            raise StandardError('wire_response is missing user code')

        self.__map_fields(wire_response, device_code_response, self.DEVICE_CODE_RESPONSE_MAP)

        return device_code_response

    @staticmethod
    def __map_fields(in_obj, out_obj, map):
        for key in in_obj:
            if key in map:
                mapped_key = map[key]
                out_obj[mapped_key] = in_obj[key]

    @staticmethod
    def __parse_optional_ints(obj, keys):
        for key in keys:
            if key in obj:
                try:
                    obj[key] = int(obj[key])
                except ValueError:
                    raise ValueError('{0} could not be parsed as an int'.format(key))

    DEVICE_CODE_RESPONSE_MAP = {
        const.OAuth2.DeviceCodeResponseParameters.DEVICE_CODE: const.OAuth2.UserCodeResponseFields.DEVICE_CODE,
        const.OAuth2.DeviceCodeResponseParameters.USER_CODE: const.OAuth2.UserCodeResponseFields.USER_CODE,
        const.OAuth2.DeviceCodeResponseParameters.VERIFICATION_URL: const.OAuth2.UserCodeResponseFields.VERIFICATION_URL,
        const.OAuth2.DeviceCodeResponseParameters.INTERVAL: const.OAuth2.UserCodeResponseFields.INTERVAL,
        const.OAuth2.DeviceCodeResponseParameters.EXPIRES_IN: const.OAuth2.UserCodeResponseFields.EXPIRES_IN,
        const.OAuth2.DeviceCodeResponseParameters.MESSAGE: const.OAuth2.UserCodeResponseFields.MESSAGE,
        const.OAuth2.DeviceCodeResponseParameters.ERROR: const.OAuth2.UserCodeResponseFields.ERROR,
        const.OAuth2.DeviceCodeResponseParameters.ERROR_DESCRIPTION: const.OAuth2.UserCodeResponseFields.ERROR_DESCRIPTION}
