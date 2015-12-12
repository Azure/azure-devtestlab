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
import httplib
import json
import platform
import urllib
import urlparse

ADAL_VERSION = '0.1.0'


def create_request_options(context_provider, options):
    default_options = {}
    merged_options = default_options

    if options is not None:
        merged_options.update(options)

    if 'options' not in context_provider.call_context and 'http' not in context_provider.call_context['options']:
        merged_options.update(context_provider.options.http)

    add_default_request_headers(context_provider, merged_options)

    return merged_options


def add_default_request_headers(context_provider, options):
    if 'headers' not in options:
        options['headers'] = {}

    headers = options['headers']

    if 'Accept-Charset' not in headers:
        headers['Accept-Charset'] = 'utf-8'

    # headers['client-request-id'] = context_provider.call_context.correlation_id
    headers['return-client-request-id'] = 'true'

    # ADAL Id headers
    headers[auth_const.OAuth2.AdalIdParameters.SKU] = auth_const.OAuth2.AdalIdParameters.NODE_SKU
    headers[auth_const.OAuth2.AdalIdParameters.VERSION] = ADAL_VERSION
    headers[auth_const.OAuth2.AdalIdParameters.OS] = platform.platform()
    headers[auth_const.OAuth2.AdalIdParameters.CPU] = platform.architecture()[0]

    return


class DefaultRequestHandler:
    def __init__(self, operation_message, print_service):
        self._operation_message = operation_message
        self._print_service = print_service
        return

    def __call__(self, response):
        self.__log_return_correlation_id(response)

        body_str = response.read()
        body = None

        if body_str is not None:
            try:
                body = json.loads(body_str)
            except:
                pass

        if not self.__is_http_success(response.status):
            msg = '{0} request returned http error: {1}'.format(self._operation_message, response.status)

            if body is not None:
                msg += ' and server response: ' + body_str

            return False, body

        return True, body_str

    def __log_return_correlation_id(self, response):
        if response is not None and 'client-request-id' in response.msg.headers:
            self._print_service.info('{1}: Server returned this correlation ID: {1}'.format(
                    self._operation_message,
                    response.headers['client-request-id']
            ))
        return

    @staticmethod
    def __is_http_success(status_code):
        return 200 <= status_code < 300


class Request:
    def __init__(self, print_service):
        self._print_service = print_service
        return

    def get(self, url, get_options, callback):
        return self.__web_request('GET', get_options, callback, url=url)

    def post(self, post_options, callback):
        return self.__web_request('POST', post_options, callback)

    def __web_request(self, verb, options, callback, url=None):

        parsed = urlparse.urlparse(options['url'])
        conn = httplib.HTTPSConnection(parsed.hostname, 443)

        if url is not None:
            request_url = url
        else:
            request_url = options['url']

        try:
            self._print_service.verbose('{0} {1}'.format(verb, request_url), no_new_line=True)
            conn.request(verb, request_url, options['body'], headers=options['headers'])

            response = conn.getresponse()

            self._print_service.verbose(' >>> {0} {1}'.format(response.status, response.reason))
            return callback(response)
        except:
            return False, None
        finally:
            conn.close()
