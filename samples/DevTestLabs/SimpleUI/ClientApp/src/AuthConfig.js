export const msalConfig = {
    auth: {
        clientId: process.env.REACT_APP_AAD_CLIENT_ID,
        authority: `https://login.microsoftonline.com/${process.env.REACT_APP_AAD_TENANT_ID}`
    }
};

export const loginRequest = {
    scopes: ["https://management.azure.com/user_impersonation"],
};