import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { PublicClientApplication } from '@azure/msal-browser';
import { MsalProvider } from '@azure/msal-react';
import { App } from './App';
import { msalConfig } from './AuthConfig';

const msalInstance = new PublicClientApplication(msalConfig);

ReactDOM.render(
    <MsalProvider instance={msalInstance}>
        <App />
    </MsalProvider>,
    document.getElementById('root')
);
