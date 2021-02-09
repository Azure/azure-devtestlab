import React, { Component } from 'react';
import * as msal from '@azure/msal-browser';
import { DetailsList, Spinner, Text, PrimaryButton, getTheme } from "@fluentui/react";


export default class App extends Component {
    publicClientApplication;

    msalConfig = {
        auth: {
            clientId: '2590931b-92b1-4e33-b354-fdec5421028c',
            authority: 'https://login.microsoftonline.com/bdfe93c9-f750-4fcc-b4f3-da5255b22a6a'
        }
    };

    constructor(props) {
        super(props);
        this.state = {
            virtualMachines: [],
            loading: true,
            loggedInUser: null,
        };

        // Intialize the MSAL application object
        this.publicClientApplication = new msal.PublicClientApplication(this.msalConfig);
    }

    async componentDidMount() {
        await this.populateVirtualMachines();
    }

    render() {
        let contents = this.state.loading
            ? <Spinner label="Loading virtual machines..." />
            : App.renderVirtualMachinesTable(this.state.virtualMachines);

        const theme = getTheme();

        return (
            <div style={{ boxShadow: theme.effects.elevation8 }}>
                <div className="header" style={{ padding: "10px" }}>
                    <Text variant="xxLarge">Lab Virtual Machines</Text>
                    <PrimaryButton style={{ float: "right" }} onClick={this.createVM.bind(this)}>Create VM</PrimaryButton>
                </div>
                {contents}
            </div>
        );
    }

    async createVM() {
        const token = await this.getAcccessToken();
        await fetch("virtualmachines",
            {
                method: "POST",
                headers: {
                    "Authorization": "Bearer " + token.accessToken
                }
            }
        );

        await this.populateVirtualMachines();
    }

    static renderVirtualMachinesTable(virtualMachines) {
        return (
            <DetailsList
                items={virtualMachines.map(vm => {
                    return {
                        "Name": vm.name,
                        "Owner": vm.ownerUserPrincipalName,
                        "Location": vm.location,
                    };
                })}
            />
        );
    }

    async populateVirtualMachines() {
        const token = await this.getAcccessToken();
        const response = await fetch("virtualmachines",
            {
                headers: {
                    "Authorization": "Bearer " + token.accessToken
                }
            });
        const data = await response.json();
        this.setState({ virtualMachines: data, loading: false });
    }

    async getAcccessToken() {
        const request = {
            scopes: ["https://management.azure.com/user_impersonation"],
            account: this.publicClientApplication.getAccountByUsername(this.state.loggedInUser)
        };

        if (this.state.loggedInUser === null) {
            const authResult = await this.publicClientApplication.loginPopup(request);
            this.setState({ loggedInUser: authResult.account.username });
            return authResult;
        }

        try {
            return await this.publicClientApplication.acquireTokenSilent(request);
        } catch (ex) {
            if (ex instanceof msal.InteractionRequiredAuthError) {
                // Fallback to pop-up if silent login fails
                return await this.publicClientApplication.acquireTokenPopup(request);
            }
            throw ex;
        }
    }
}
