import { Spinner, DefaultButton} from '@fluentui/react';
import React, { Component } from 'react';

/**
 * Button component for user to claim/unclaim a VM
 * 
 * */
export default class VirtualMachineRow extends Component {
    constructor(props) {
        super(props);

        this.state = {
            isUpdating: false,
        };
    }

    render() {
        if (this.state.isUpdating) {
            return <DefaultButton disabled={true}><Spinner/></DefaultButton>;
        }

        // Check if user currently has this VM claimed
        if (this.props.loggedInUser === this.props.vmOwner) {
            return <DefaultButton text={"Unclaim"} onClick={() => this.unclaim()} />;
        }

        // Check if user is eligible to claim this VM
        if (this.props.vmOwner === "") {
            return <DefaultButton text={"Claim"} onClick={() => this.claim()} />;
        }

        return <></>;
    }

    async unclaim() {
        this.setState({ isUpdating: true });
        await this.props.unclaim();
        this.setState({ isUpdating: false });
    }

    async claim() {
        this.setState({ isUpdating: true });
        await this.props.claim();
        this.setState({ isUpdating: false });
    }
}