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
import datetime
import json
import re
import time
import urllib
import urlparse
import util
import uuid


class RetryError(Exception):
    pass


class OAuth2Client:
    def __init__(self, print_service, call_context, authority):
        self._print_service = print_service
        self._authority = authority
        self._token_endpoint = authority.token_endpoint
        self._device_code_endpoint = authority.device_code_endpoint
        self._cancel_long_polling_request = False

        self.call_context = call_context

        return

    def get_token_with_polling(self, oauth_parameters, interval, expires_in):
        max_times_for_retry = int(expires_in / interval)

        token_url = self.__create_token_url()
        url_encoded_token_request_form = urllib.urlencode(oauth_parameters)
        post_options = self.__create_post_option(token_url, url_encoded_token_request_form)
        success = False
        response = None

        for retry in self.__retry(max_times_for_retry, interval * 1000):
            try:
                request = util.Request(self._print_service)
                success, response = request.post(post_options,
                                                 util.DefaultRequestHandler('Get Token', self._print_service))

                if success:
                    success, response = self.__handle_polling_response(response)
                    return success, response
                else:
                    time.sleep(interval)
                    retry()
            except:
                retry()

        return success, response

    def __handle_polling_response(self, body):

        token_response = self.__handle_request_error_response(body)

        if len(token_response) == 0:
            token_response = self.__validate_token_response(body)

        return True, token_response

    def __handle_request_error_response(self, body):

        token_response = {}

        try:
            wire_response = json.loads(body)
        except:
            raise StandardError('The token response returned from the server is unparsable as JSON')

        if const.OAuth2.ResponseParameters.ERROR in wire_response:
            self.__map_fields(wire_response, token_response, self.TOKEN_RESPONSE_MAP)

        return token_response

    @staticmethod
    def __retry(retry_attempts, timeout):
        start_time = time.time()
        success = set()

        for i in range(retry_attempts):
            success.add(True)
            yield success.clear
            if success:
                return
            if time.time() > start_time + timeout:
                break
        raise RetryError

    def get_user_code_info(self, oauth_parameters):
        device_code_url = self.__create_device_code_url()
        url_encoded_device_code_request_form = urllib.urlencode(oauth_parameters)
        post_options = self.__create_post_option(device_code_url, url_encoded_device_code_request_form)

        request = util.Request(self._print_service)

        result, response = request.post(post_options,
                                        util.DefaultRequestHandler('Get Device Code', self._print_service))

        if result:
            result, response = self.__handle_get_device_code_response(response)

        return result, response

    def __create_device_code_url(self):
        return self.__get_versioned_api_url(self._device_code_endpoint)

    def __create_token_url(self):
        return self.__get_versioned_api_url((self._token_endpoint))

    def __get_versioned_api_url(self, url):
        parsed = urlparse.urlsplit(url)
        parsed_qs = urlparse.parse_qs(parsed.query)
        parsed_qs[const.OAuth2.Parameters.AAD_API_VERSION] = '1.0'

        new_qs = urllib.urlencode(parsed_qs, doseq=True)
        return urlparse.urlunsplit((parsed.scheme, parsed.netloc, parsed.path, new_qs, parsed.fragment))

    def __create_post_option(self, post_url, url_encoded_request_form):
        options_data = {
            'url': post_url,
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
            return False, None

        return True, device_code_response

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

    def __validate_token_response(self, body):

        wire_response = None
        token_response = {}

        try:
            wire_response = json.loads(body)
        except:
            raise StandardError('The token response returned from the server is unparseable as JSON')

        int_keys = [const.OAuth2.ResponseParameters.EXPIRES_ON,
                    const.OAuth2.ResponseParameters.EXPIRES_IN,
                    const.OAuth2.ResponseParameters.CREATED_ON]

        self.__parse_optional_ints(wire_response, int_keys)

        if const.OAuth2.ResponseParameters.EXPIRES_IN in wire_response:
            expires_in = wire_response[const.OAuth2.ResponseParameters.EXPIRES_IN]
            now = datetime.datetime.now()

            expires_on = now + datetime.timedelta(0, expires_in)
            wire_response[const.OAuth2.ResponseParameters.EXPIRES_ON] = expires_on.isoformat()

        if const.OAuth2.ResponseParameters.CREATED_ON in wire_response:
            created_on = wire_response[const.OAuth2.ResponseParameters.CREATED_ON]
            temp_date = datetime.datetime.fromtimestamp(created_on / 1000)
            wire_response[const.OAuth2.ResponseParameters.CREATED_ON] = temp_date.isoformat()

        if const.OAuth2.ResponseParameters.TOKEN_TYPE not in wire_response:
            self._print_service.error('wire_response missing token_type')

        if const.OAuth2.ResponseParameters.ACCESS_TOKEN not in wire_response:
            self._print_service.error('wire_response missing access_token')

        self.__map_fields(wire_response, token_response, self.TOKEN_RESPONSE_MAP)

        if const.OAuth2.ResponseParameters.ID_TOKEN in wire_response:
            id_token = self.__parse_id_token(wire_response[const.OAuth2.ResponseParameters.ID_TOKEN])

            if id_token is not None:
                token_response['id_token'] = id_token

        return token_response

    def __parse_id_token(self, encoded_id_token):
        cracked_token = self.__crack_jwt(encoded_id_token)

        if cracked_token is None:
            return

        try:
            base64_id_token = cracked_token['JWSPayload']
            base64_decoded = util.base64_decode_string_url_safe(base64_id_token)

            if base64_decoded is None:
                self._print_service.warning('The returned id_token could not be base64 url safe decoded.')
                return

            id_token = json.loads(base64_decoded)
        except:
            raise StandardError('The returned id_token could not be decoded.')

        return self.__extract_id_token_values(id_token)

    def __extract_id_token_values(self, id_token):
        extracted_values = self.__get_user_id(id_token)
        self.__map_fields(id_token, extracted_values, const.OAuth2.IdTokenMap)

        return extracted_values

    @staticmethod
    def __get_user_id(id_token):
        user_id = ''
        is_displayable = False

        if 'upn' in id_token:
            user_id = id_token['upn']
            is_displayable = True
        elif 'email' in id_token:
            user_id = id_token['email']
            is_displayable = True
        elif 'sub' in id_token:
            user_id = id_token['sub']

        if user_id is None:
            user_id = uuid.uuid4()

        user_id_vals = {const.OAuth2.IdTokenFields.USER_ID: user_id}

        if is_displayable:
            user_id_vals[const.OAuth2.IdTokenFields.IS_USER_ID_DISPLAYABLE] = True

        return user_id_vals

    def __crack_jwt(self, jwt_token):
        regex = '^([^\.\s]*)\.([^\.\s]+)\.([^\.\s]*)$'
        match = re.match(regex, jwt_token)

        if match is None or len(match.groups(0)) < 3:
            self._print_service.warning('The returned id_token is not parseable.')
            return

        cracked_token = {
            'header': match.groups(0)[0],
            'JWSPayload': match.groups(0)[1],
            'JWSSig': match.groups(0)[2]
        }

        return cracked_token

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

    TOKEN_RESPONSE_MAP = {
        const.OAuth2.ResponseParameters.TOKEN_TYPE: const.OAuth2.TokenResponseFields.TOKEN_TYPE,
        const.OAuth2.ResponseParameters.ACCESS_TOKEN: const.OAuth2.TokenResponseFields.ACCESS_TOKEN,
        const.OAuth2.ResponseParameters.REFRESH_TOKEN: const.OAuth2.TokenResponseFields.REFRESH_TOKEN,
        const.OAuth2.ResponseParameters.CREATED_ON: const.OAuth2.TokenResponseFields.CREATED_ON,
        const.OAuth2.ResponseParameters.EXPIRES_ON: const.OAuth2.TokenResponseFields.EXPIRES_ON,
        const.OAuth2.ResponseParameters.EXPIRES_IN: const.OAuth2.TokenResponseFields.EXPIRES_IN,
        const.OAuth2.ResponseParameters.RESOURCE: const.OAuth2.TokenResponseFields.RESOURCE,
        const.OAuth2.ResponseParameters.ERROR: const.OAuth2.TokenResponseFields.ERROR,
        const.OAuth2.ResponseParameters.ERROR_DESCRIPTION: const.OAuth2.TokenResponseFields.ERROR_DESCRIPTION}

    DEVICE_CODE_RESPONSE_MAP = {
        const.OAuth2.DeviceCodeResponseParameters.DEVICE_CODE: const.OAuth2.UserCodeResponseFields.DEVICE_CODE,
        const.OAuth2.DeviceCodeResponseParameters.USER_CODE: const.OAuth2.UserCodeResponseFields.USER_CODE,
        const.OAuth2.DeviceCodeResponseParameters.VERIFICATION_URL: const.OAuth2.UserCodeResponseFields.VERIFICATION_URL,
        const.OAuth2.DeviceCodeResponseParameters.INTERVAL: const.OAuth2.UserCodeResponseFields.INTERVAL,
        const.OAuth2.DeviceCodeResponseParameters.EXPIRES_IN: const.OAuth2.UserCodeResponseFields.EXPIRES_IN,
        const.OAuth2.DeviceCodeResponseParameters.MESSAGE: const.OAuth2.UserCodeResponseFields.MESSAGE,
        const.OAuth2.DeviceCodeResponseParameters.ERROR: const.OAuth2.UserCodeResponseFields.ERROR,
        const.OAuth2.DeviceCodeResponseParameters.ERROR_DESCRIPTION: const.OAuth2.UserCodeResponseFields.ERROR_DESCRIPTION}
