import * as React from 'react';
import { AddVmForm, AddVmFormState } from './AddVmForm';
import { Dtl } from '../dtl';

const deny = 'Deny';

interface AddVmState {
    lab?: Dtl.Lab;
    selectedImage?: Dtl.Image;
}

interface AddVmProps {
    exitForm: () => void;
    lab: Dtl.Lab;
    baseImages: Dtl.Image[];
}

export class AddVm extends React.Component<AddVmProps, AddVmState> {
    constructor(props: AddVmProps) {
        super();
        
        this.state = { lab: props.lab };
        this.handleSubmit = this.handleSubmit.bind(this);
    }

    async componentDidMount() {
        const lab = this.state.lab;
    }

    public render() {
        if (!this.props.baseImages) {
            return <div><p><em>Loading...</em></p></div>;
        }

        const imagesList = this.renderImagesList(this.props.baseImages);

        return <div className="container-fluid">
            <div className="row">
                <div className="col-md-8">
                    {imagesList}
                </div>
                <div className="col-md-4">
                    <AddVmForm
                        lab={this.state.lab}
                        selectedImage={this.state.selectedImage}
                        submitHandler={this.handleSubmit}
                        exitForm={this.props.exitForm}
                    />
                </div>
            </div>
        </div>;
    }

    async handleSubmit(formState: AddVmFormState) {
        if (!this.state.selectedImage) {
            alert('select a base image');
            return;
        }

        alert(`Creating ${formState.vmName}`);

        const vnets = await Dtl.getVirtualNetworksAsync(this.state.lab);
        const vnetWithAllowedSubnet = vnets.find(vnet => vnet.allowedSubnets.length > 0);
        if (vnets.length < 1 || !vnetWithAllowedSubnet) {
            alert('no useable subnet found');
            return;
        }
        
        const subnetPolicies: Dtl.Policy[] = [{factName: 'UserOwnedLabVmCountInSubnet',
                                                factData: vnetWithAllowedSubnet.allowedSubnets[0].resourceId,
                                                valueOffset: '1'}];
        const subnetPolicyError = await Dtl.evaluatePoliciesAsync(this.state.lab, subnetPolicies);  
                                                                    
        if (subnetPolicyError) {
            alert(subnetPolicyError.errorMessage);
            return;
        }

        const disallowPublicIpAddress = vnetWithAllowedSubnet.allowedSubnets[0].allowPublicIp === deny;
        let newVmProperties: Dtl.LabVirtualMachine = {
            location: this.state.lab.location,
            name: formState.vmName,
            properties: {
                allowClaim: formState.allowClaim,
                customImageId: this.state.selectedImage.customImageId,
                galleryImageReference: this.state.selectedImage.imageReference,
                artifacts: formState.artifacts,
                disallowPublicIpAddress: disallowPublicIpAddress,
                isAuthenticationWithSshKey: formState.isAuthenticationWithSshKey,
                labSubnetName: vnetWithAllowedSubnet.allowedSubnets[0].labSubnetName,
                labVirtualNetworkId: vnetWithAllowedSubnet.id,
                notes: formState.notes,
                size: formState.vmSize, 
                storageType: formState.storageType,
                userName: formState.userName
            }
        };
        
        if (formState.isAuthenticationWithSshKey) {
            newVmProperties.properties.sshKey = formState.sshKey;
        } else {
            newVmProperties.properties.password = formState.password;
        }

        const requestAccepted = await Dtl.addVmAsync(this.state.lab, newVmProperties);
        if (!requestAccepted) {
            alert('dtl returned an error'); // TODO
        } else {
            this.props.exitForm();
        }
    }

    private renderImagesList(images: Array<Dtl.Image>) {
        return <table className="table table-hover textsmall">
            <thead>
                <tr>
                    <th>NAME</th>
                    <th>PUBLISHER</th>
                    <th>OS TYPE</th>
                    <th>TYPE</th>
                </tr>
            </thead>
            <tbody>
                {images.map(image =>
                    <tr
                        key={`${image.author}-${image.name}`}
                        className={(this.state.selectedImage && this.state.selectedImage.id === image.id 
                                    && this.state.selectedImage.name === image.name
                                    && this.state.selectedImage.author === image.author) ? 'active' : ''}
                        onClick={() => this.setState({ selectedImage: image })}
                    >
                        <td>{image.name}</td>
                        <td>{image.author}</td>
                        <td>{image.ostype}</td>
                        <td>{image.type}</td>
                    </tr>
                )}
            </tbody>
        </table>;
    }
}