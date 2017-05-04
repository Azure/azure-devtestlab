import * as React from 'react';
import LogIn from './LogIn';

const jwtKey = 'access_token';
const expiresin = 'expires_in';

interface AuthenticatedComponentState {
    authenticated: boolean;
}

interface AuthenticatedComponentProps {
    location?: {
        hash: string;
    };
    body?: React.ReactElement<{}>;
}

export default (InnerComponent: React.ComponentClass<AuthenticatedComponentProps>) =>
    class AuthenticatedComponent extends React.Component<AuthenticatedComponentProps, AuthenticatedComponentState> {
        constructor(props: AuthenticatedComponentProps) {
            super();
            const expiry = parseInt(window.sessionStorage.getItem(expiresin), 10);
            if (Date.now() > expiry) {
                window.sessionStorage.removeItem(jwtKey);
            }
            const token = window.sessionStorage.getItem(jwtKey);       
            if (token) {
                this.state = { authenticated: true };
            } else if (props.location.hash !== '') {
                // receiving an oauth response; retrieve and store the jwt
                let fragments = {};
                let hashSegments = props.location.hash.substr(1).split('&');
                for (const fragment of hashSegments) {
                    const item = fragment.split('=');
                    fragments[item[0]] = item[1];
                }
      
                window.sessionStorage.setItem(jwtKey, fragments[jwtKey]);
                // Setting the Window timeout 5 seconds before the access token expires. 
                const tokenDuration =  (parseInt(fragments[expiresin], 10) - 5) * 1000;
                const expiresinmsec = Date.now() + tokenDuration;
                window.sessionStorage.setItem(expiresin, expiresinmsec.toString());
                // forcing the component to relogin
                window.setTimeout(() => {alert('Session Expired. Refresh Browser'); }, tokenDuration);
                this.state = { authenticated: true };
            } else {
                this.state = { authenticated: false };
            }
        }

        componentWillReceiveProps(nextProps: AuthenticatedComponentProps) {
            const expiry = parseInt(window.sessionStorage.getItem(expiresin), 10);
            if (Date.now() > expiry) {
                window.sessionStorage.removeItem(jwtKey);
                this.setState({authenticated: false});
            }
        }
        
        public render() {
            return this.state.authenticated
                ? <InnerComponent {...this.props} />
                : <LogIn />;
        }
    };
