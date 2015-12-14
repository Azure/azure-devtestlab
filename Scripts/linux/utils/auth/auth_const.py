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

    IdTokenMap = {
        'tid': 'tenantId',
        'given_name': 'givenName',
        'family_name': 'familyName',
        'idp': 'identityProvider'
    }

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

    class ResponseParameters:
        def __init__(self):
            return

        CODE = 'code'
        TOKEN_TYPE = 'token_type'
        ACCESS_TOKEN = 'access_token'
        ID_TOKEN = 'id_token'
        REFRESH_TOKEN = 'refresh_token'
        CREATED_ON = 'created_on'
        EXPIRES_ON = 'expires_on'
        EXPIRES_IN = 'expires_in'
        RESOURCE = 'resource'
        ERROR = 'error'
        ERROR_DESCRIPTION = 'error_description'

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

    class AdalIdParameters:
        def __init__(self):
            return

        SKU = 'x-client-SKU'
        VERSION = 'x-client-Ver'
        OS = 'x-client-OS'
        CPU = 'x-client-CPU'
        NODE_SKU = 'Node'

    class IdTokenFields:
        def __init__(self):
            return

        USER_ID = 'userId'
        IS_USER_ID_DISPLAYABLE = 'isUserIdDisplayable'
        TENANT_ID = 'tenantId'
        GIVE_NAME = 'givenName'
        FAMILY_NAME = 'familyName'
        IDENTITY_PROVIDER = 'identityProvider'

    class TokenResponseFields:
        def __init__(self):
            return

        TOKEN_TYPE = 'tokenType'
        ACCESS_TOKEN = 'accessToken'
        REFRESH_TOKEN = 'refreshToken'
        CREATED_ON = 'createdOn'
        EXPIRES_ON = 'expiresOn'
        EXPIRES_IN = 'expiresIn'
        RESOURCE = 'resource'
        USER_ID = 'userId'
        ERROR = 'error'
        ERROR_DESCRIPTION = 'errorDescription'

    class DeviceCodeResponseParameters:
        def __init__(self):
            return

        USER_CODE = 'user_code'
        DEVICE_CODE = 'device_code'
        VERIFICATION_URL = 'verification_url'
        EXPIRES_IN = 'expires_in'
        INTERVAL = 'interval'
        MESSAGE = 'message'
        ERROR = 'error'
        ERROR_DESCRIPTION = 'error_description'

    class AADConstants:
        def __init__(self):
            return

        WORLD_WIDE_AUTHORITY = 'login.windows.net'
        WELL_KNOWN_AUTHORITY_HOSTS = ['login.windows.net',
                                      'login.microsoftonline.com',
                                      'login.chinacloudapi.cn',
                                      'login.cloudgovapi.us']
        INSTANCE_DISCOVERY_ENDPOINT_TEMPLATE = 'https://{authorize_host}/common/discovery/instance?authorization_endpoint={authorize_endpoint}&api-version=1.0'
        AUTHORIZE_ENDPOINT_PATH = '/oauth2/authorize'
        TOKEN_ENDPOINT_PATH = '/oauth2/token'
        DEVICE_ENDPOINT_PATH = '/oauth2/devicecode'
