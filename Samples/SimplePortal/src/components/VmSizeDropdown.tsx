import * as React from 'react';
import {Dtl} from '../dtl';

interface VmSizeDropdownProps {
    lab: Dtl.Lab;
    storageType?: string;
    defaultSize?: string;
    changeHandler: (selectedSize: string, premiumStorage?: boolean) => void;
}

interface VmSizeDropdownState {
    selectedSize?: string;
    vmSizes?: string[];
}

export class VmSizeDropdown extends React.Component < VmSizeDropdownProps, VmSizeDropdownState > {
    constructor(props: VmSizeDropdownProps) {
        super(props);
        this.handleChange = this.handleChange.bind(this);
        this.state = {
            selectedSize: props.defaultSize || '',
            vmSizes: []
        };
        this.doesSizeSupportPremiumStorage = this.doesSizeSupportPremiumStorage.bind(this);
    }

    componentWillReceiveProps(nextProps: VmSizeDropdownProps) {
        this.setState({selectedSize: nextProps.defaultSize || ''});
    }
    
    async componentDidMount() {
        const vmSizes = await Dtl.getVmSizesAsync(this.props.lab);
        let premiumStorage;
        for (const sizeName of vmSizes) {
            if (this.doesSizeSupportPremiumStorage(sizeName)) {
                premiumStorage = true;
                break;
            }
        }
        this.setState({selectedSize: vmSizes[0], vmSizes: vmSizes});
        this.props.changeHandler(this.state.selectedSize, premiumStorage);
    }

    doesSizeSupportPremiumStorage(sizeName: string): boolean {
        const sizeNameLowerCase = sizeName.toLowerCase();
        return (sizeNameLowerCase.startsWith('standard_ds') ||
            sizeNameLowerCase.startsWith('standard_gs') ||
            new RegExp('standard_f[0-9]+s').test(sizeNameLowerCase));
    }

    handleChange(event: React.FormEvent < HTMLSelectElement >) {
        const newSize = event.currentTarget.value;
        this.setState({selectedSize: newSize});
        this.props.changeHandler(newSize);
    }

    render() {
        const renderOption = item => <option key={item} value={item}>{item}</option>;
        let dropdownItems = Array<JSX.Element>();
        for (const vmSize of this.state.vmSizes) {
            if (this.props.storageType === 'Premium' && !this.doesSizeSupportPremiumStorage(vmSize)) {
                // lets not allow user to select Basic vms incase of SDD storage storageType
                continue;
            }
            dropdownItems.push(renderOption(vmSize));
        }

        return (
            <select
                className="form-control"
                value={this.state.selectedSize}
                onChange={this.handleChange}
                required={true}
            >
                {dropdownItems}
            </select>
        );
    }
}
