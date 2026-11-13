import { useState, useEffect } from 'react';
import { useMsal } from '@azure/msal-react';
import { loginRequest } from './AuthConfig';
import { InteractionStatus } from '@azure/msal-browser';

const requestAuthContext = async (instance) => {
    const activeAccount = instance.getActiveAccount();

    if (!activeAccount) {
        const loginResponse = await instance.loginPopup(loginRequest);
        instance.setActiveAccount(loginResponse.account);
    }

    let response;
    try {
        response = await instance.acquireTokenSilent(loginRequest);
    } catch (ex) {
        response = await instance.acquireTokenPopup(loginRequest);
    }

    return response;
}

export const useAuthContext = () => {
    const { instance, accounts, inProgress } = useMsal();

    const [accessToken, setAccessToken] = useState(null);
    const [loggedInUser, setLoggedInUser] = useState(null);

    useEffect(() => {
        const setAuthContext = async () => {
            if (inProgress === InteractionStatus.None) {
                const authContext = await requestAuthContext(instance, accounts);
                setAccessToken(authContext.accessToken);
                setLoggedInUser(authContext.account.username);
            }
        }

        setAuthContext();
    }, [inProgress, accounts, instance]);

    return { accessToken, loggedInUser };
}
