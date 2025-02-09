import React from 'react';
import { getTheme, Text } from '@fluentui/react';
import { VirtualMachineTable } from './VirtualMachineTable';

export const App = () => {
    const theme = getTheme();

    return (
        <div style={{ padding: theme.spacing.s2 }}>
            <Text variant='xxLarge'>Lab Virtual Machines</Text>
            <div style={{ boxShadow: theme.effects.elevation8 }}>
                <VirtualMachineTable />
            </div>
        </div>
    );
}
