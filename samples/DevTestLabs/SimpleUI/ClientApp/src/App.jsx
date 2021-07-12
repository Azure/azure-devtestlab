import * as msal from '@azure/msal-browser';
import { CheckboxVisibility, DetailsList, getTheme, Spinner, Text } from "@fluentui/react";
import React, { Component } from 'react';
import OwnershipButton from './OwnershipButton';

export default class App extends Component {
    publicClientApplication;

    msalConfig = {
        auth: {
            clientId: process.env.REACT_APP_AAD_CLIENT_ID,
            authority: `https://login.microsoftonline.com/${process.env.REACT_APP_AAD_TENANT_ID}`
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
            : this.renderVirtualMachinesTable(this.state.virtualMachines);

        const theme = getTheme();

        return (
            <div style={{ boxShadow: theme.effects.elevation8 }}>
                <div className="header" style={{ padding: "10px" }}>
                    <Text variant="xxLarge">Lab Virtual Machines</Text>
                </div>
                {contents}
            </div>
        );
    }

    renderVirtualMachinesTable(virtualMachines) {
        return (
            <DetailsList
                items={virtualMachines.map(vm => {
                    return {
                        "Name": vm.name,
                        "Owner": vm.ownerUserPrincipalName,
                        "Location": vm.location,
                        "Change Ownership": this.renderButton(vm)
                    };
                })}
                checkboxVisibility={CheckboxVisibility.hidden}
            />
        );
    }

    renderButton(virtualMachine) {
        return (
            <OwnershipButton
                vmOwner={virtualMachine.ownerUserPrincipalName}
                loggedInUser={this.state.loggedInUser}
                unclaim={() => this.unclaimVirtualMachine(virtualMachine.name)}
                claim={() => this.claimVirtualMachine(virtualMachine.name)}
            />
        );
    }

    async claimVirtualMachine(vmName) {
        const token = await this.getAcccessToken();
        await fetch(`virtualmachines/claim/${vmName}`,
            {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${token}`
                }
            });
        await this.populateVirtualMachines();
    }

    async unclaimVirtualMachine(vmName) {
        const token = await this.getAcccessToken();
        await fetch(`virtualmachines/unclaim/${vmName}`,
            {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${token}`
                }
            });
        await this.populateVirtualMachines();
    }

    async populateVirtualMachines() {
        const token = await this.getAcccessToken();
        const response = await fetch("virtualmachines",
            {
                headers: {
                    "Authorization": `Bearer ${token}`
                }
            });
        const data = await response.json();
        this.setState({ virtualMachines: data, loading: false });
    }

    async getAcccessToken() {
        const request = {
            scopes: ["https://management.azure.com/user_impersonation"],
        };

        request.account = await this.getAccount(request);

        if (this.state.loggedInUser === null) {
            this.setState({ loggedInUser: request.account.username })
        }

        try {
            const authResult = await this.publicClientApplication.acquireTokenSilent(request);
            return authResult.accessToken;
        } catch (ex) {
            if (ex instanceof msal.InteractionRequiredAuthError) {
                // Fallback to pop-up if silent acquisition of token fails
                const authResult = await this.publicClientApplication.acquireTokenPopup(request);
                return authResult.accessToken;
            }
            throw ex;
        }
    }

    async getAccount(request) {
        const accounts = this.publicClientApplication.getAllAccounts();

        if (accounts.length === 0) {
            await this.publicClientApplication.loginPopup(request);
        }

        // For simplicity, assume user will only be using a single account to access this application
        return accounts[0];
    }
}
