import * as React from 'react';
import * as ReactDOM from 'react-dom';
import { App } from './App';
import { PublicClientApplication } from '@azure/msal-browser';
import { MsalProvider } from '@azure/msal-react';
import { msalConfig } from './AuthConfig';

const msalInstance = new PublicClientApplication(msalConfig);

ReactDOM.render(
    <MsalProvider instance={msalInstance}>
        <App />
    </MsalProvider>,
    document.getElementById('root')
);