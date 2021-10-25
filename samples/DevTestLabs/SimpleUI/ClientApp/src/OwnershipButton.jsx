import React from 'react';
import { Spinner, DefaultButton } from '@fluentui/react';
import { useAsyncCallback } from 'react-async-hook';
import { useAuthContext } from './Hooks';

export const VMAction = {
    Claim: 'Claim',
    Unclaim: 'Unclaim'
};

export const OwnershipButton = (props) => {
    const { accessToken } = useAuthContext();
    const { action, vmName } = props;

    const headers = React.useMemo(() => {
        return { 'Authorization': `Bearer ${accessToken}` };
    }, [accessToken]);

    const onClick = React.useCallback(async () => {
        return await fetch(`virtualmachines/${action.toLowerCase()}/${vmName}`, { method: 'POST', headers: headers });
    }, [vmName, action, headers]);

    const asyncOnClick = useAsyncCallback(onClick);

    return (
        <DefaultButton
            onClick={asyncOnClick.execute}
            disabled={asyncOnClick.loading || asyncOnClick.result}
            text={!asyncOnClick.result ? (action) : (`${action}ed!`)}
        >
            {asyncOnClick.loading && <Spinner />}
        </DefaultButton>
    );
}
