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


class GrantType:
    def __init__(self):
        return

    AUTHORIZATION_CODE = 'authorization_code',
    REFRESH_TOKEN = 'refresh_token',
    CLIENT_CREDENTIALS = 'client_credentials',
    JWT_BEARER = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
    PASSWORD = 'password',
    SAML1 = 'urn:ietf:params:oauth:grant-type:saml1_1-bearer',
    SAML2 = 'urn:ietf:params:oauth:grant-type:saml2-bearer',
    DEVICE_CODE = 'device_code'


class OAuth2:
    def __init__(self):
        return

    class Parameters:
        def __init__(self):
            return

        GRANT_TYPE = 'grant_type'
        CLIENT_ASSERTION = 'client_assertion'
        CLIENT_ASSERTION_TYPE = 'client_assertion_type'
        CLIENT_ID = 'client_id'
        CLIENT_SECRET = 'client_secret'
        REDIRECT_URI = 'redirect_uri'
        RESOURCE = 'resource'
        CODE = 'code'
        SCOPE = 'scope'
        ASSERTION = 'assertion'
        AAD_API_VERSION = 'api-version'
        USERNAME = 'username'
        PASSWORD = 'password'
        REFRESH_TOKEN = 'refresh_token'
        LANGUAGE = 'mkt'
        DEVICE_CODE = 'device_code'

    class UserCodeResponseFields:
        def __init__(self):
            return

        USER_CODE = 'userCode'
        DEVICE_CODE = 'deviceCode'
        VERIFICATION_URL = 'verificationUrl'
        EXPIRES_IN = 'expiresIn'
        INTERVAL = 'interval'
        MESSAGE = 'message'
        ERROR = 'error'
        ERROR_DESCRIPTION = 'errorDescription'

    class Scope:
        def __init__(self):
            return

        OPENID = 'openid'
