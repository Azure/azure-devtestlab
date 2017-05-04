import * as React from 'react';

const clientId = '<<<Clieint ID/Application ID for Azure Application created>>>';
const authority = 'https://login.microsoftonline.com/common/oauth2/authorize';
const redirectUri = 'http://localhost:3000/';

const oauthHandshake = () => {
        const oauthUrl = `${authority}?`
            + '&client_id=' + encodeURIComponent(clientId)
            + '&nonce=' + encodeURIComponent('TODO')
            + '&redirect_uri=' + encodeURIComponent(redirectUri)
            + '&resource=' + encodeURIComponent('https://management.azure.com/')
            + '&response_mode=' + encodeURIComponent('fragment')
            + '&prompt=' + encodeURIComponent('consent')
            + '&response_type=' + encodeURIComponent('token');

        window.location.assign(oauthUrl);
};

const LogIn = () => (
    <div>
        {oauthHandshake()}
    </div>
);

export default LogIn;