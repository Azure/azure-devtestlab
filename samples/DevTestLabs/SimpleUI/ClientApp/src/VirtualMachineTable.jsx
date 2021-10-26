import React from 'react';
import { CheckboxVisibility, DetailsList, Spinner, Text } from '@fluentui/react';
import { useAsync } from 'react-async-hook';
import { useAuthContext } from './Hooks';
import { OwnershipButton, VMAction } from './OwnershipButton';

const renderOwnershipButton = (virtualMachine, loggedInUser) => {
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

export const VirtualMachineTable = () => {
    const { accessToken, loggedInUser } = useAuthContext();

    const fetchLabVMs = React.useCallback(async () => {
        if (accessToken != null) {
            const headers = { 'Authorization': `Bearer ${accessToken}` };
            const response = await fetch('virtualmachines', { headers: headers });
            if (response.ok) {
                return response.json();
            }
            throw new Error('Unable to fetch lab VMs');
        }
    }, [accessToken]);

    const asyncFetchLabVMs = useAsync(fetchLabVMs, [accessToken]);

    const labVMs = React.useMemo(() => {
        return (asyncFetchLabVMs.result || []).map(vm => {
            return {
                Name: vm.name,
                Owner: vm.ownerUserPrincipalName,
                Location: vm.location,
                Ownership: renderOwnershipButton(vm, loggedInUser)
            };
        })
    }, [asyncFetchLabVMs.result, loggedInUser]);

    return (
        <div>
            {asyncFetchLabVMs.loading && <Spinner label='Loading virtual machines...' />}
            {asyncFetchLabVMs.error &&
                <Text>
                    An error has occurred: {asyncFetchLabVMs.error.message}
                </Text>
            }
            {asyncFetchLabVMs.result &&
                <DetailsList
                    items={labVMs}
                    checkboxVisibility={CheckboxVisibility.hidden}
                />
            }
        </div>
    );
};
