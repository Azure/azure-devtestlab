import React from 'react';
import { CheckboxVisibility, DetailsList, Spinner, Text } from '@fluentui/react';
import { useAsync } from 'react-async-hook';
import { useAuthContext } from './Hooks';
import { OwnershipButton } from './OwnershipButton';

export const VirtualMachineTable = () => {
    const { accessToken } = useAuthContext();

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
                Ownership: <OwnershipButton vmOwner={vm.ownerUserPrincipalName} vmName={vm.name} />
            };
        })
    }, [asyncFetchLabVMs.result]);

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
