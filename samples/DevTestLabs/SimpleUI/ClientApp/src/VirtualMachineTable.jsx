import React from 'react';
import { CheckboxVisibility, DetailsList, Spinner } from '@fluentui/react';
import { useAsync } from 'react-async-hook';
import { useAuthContext } from './Hooks';
import { OwnershipButton, VMAction } from './OwnershipButton';

export const VirtualMachineTable = () => {
    const { accessToken, loggedInUser } = useAuthContext();

    const fetchLabVMs = async (token) => {
        if (token != null) {
            const headers = { 'Authorization': `Bearer ${token}` };
            return (await fetch('virtualmachines', { headers: headers })).json();
        }
    }

    const renderOwnershipButton = (virtualMachine) => {
        let action;
        if (!virtualMachine.ownerUserPrincipalName) {
            action = VMAction.Claim;
        } else if (virtualMachine.ownerUserPrincipalName === loggedInUser) {
            action = VMAction.Unclaim;
        } else {
            return <></>;
        }

        return (
            <OwnershipButton
                action={action}
                vmName={virtualMachine.name}
            />
        );
    }

    const asyncFetchLabVMs = useAsync(fetchLabVMs, [accessToken]);

    return (
        <div>
            {asyncFetchLabVMs.loading && <Spinner label='Loading virtual machines...' />}
            {asyncFetchLabVMs.error && <div>Error: {asyncFetchLabVMs.error.message}</div>}
            {asyncFetchLabVMs.result && (
                <DetailsList
                    items={asyncFetchLabVMs.result.map(vm => {
                        return {
                            'Name': vm.name,
                            'Owner': vm.ownerUserPrincipalName,
                            'Location': vm.location,
                            'Ownership': renderOwnershipButton(vm)
                        };
                    })}
                    checkboxVisibility={CheckboxVisibility.hidden}
                />
            )}
        </div>
    );
};