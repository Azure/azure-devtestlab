import React from 'react';
import { Spinner, DefaultButton } from '@fluentui/react';
import { useAsyncCallback } from 'react-async-hook';
import { useAuthContext } from './Hooks';

export const OwnershipButton = (props) => {
    const { accessToken, loggedInUser } = useAuthContext();
    const { vmOwner, vmName } = props;

    let action;
    if (!vmOwner) {
        action = 'Claim';
    } else if (vmOwner === loggedInUser) {
        action = 'Unclaim';
    }

    const headers = React.useMemo(() => {
        return { 'Authorization': `Bearer ${accessToken}` };
    }, [accessToken]);

    const onClick = React.useCallback(async () => {
        return await fetch(`virtualmachines/${action.toLowerCase()}/${vmName}`, { method: 'POST', headers: headers });
    }, [vmName, action, headers]);

    const asyncOnClick = useAsyncCallback(onClick);

    const button =
        <DefaultButton
            onClick={asyncOnClick.execute}
            disabled={asyncOnClick.loading || asyncOnClick.result}
            text={!asyncOnClick.result ? (action) : (`${action}ed!`)}
        >
            {asyncOnClick.loading && <Spinner />}
        </DefaultButton>;

    return action ? button : <></>;
}
