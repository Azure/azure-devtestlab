import * as React from 'react';
import { Dtl } from '../dtl';
import { VmSizeDropdown } from './VmSizeDropdown';
                         
export interface AddVmFormState {
    notes?: string;
    password?: string;
    sshKey?: string;
    isAuthenticationWithSshKey?: boolean;
    selectedImage?: Dtl.Image;
    storageType?: string;
    isPremiumStorageEnabled?: boolean;
    userName?: string;
    vmName?: string;
    vmSize?: string;
    artifacts?: Dtl.Artifact[];
    allowClaim?: boolean;
    addAdmin?: boolean;
    domainJoin?: boolean;
    lab?: Dtl.Lab;
}

interface AddVmFormProps {
    exitForm: () => void;
    lab: Dtl.Lab;
    selectedImage?: Dtl.Image; 
    submitHandler: (state: AddVmFormState) => void;
}

export class AddVmForm extends React.Component<AddVmFormProps, AddVmFormState> {
    constructor(props: AddVmFormProps) {
        super();
        this.state = {
            notes: '',
            password: '',
            sshKey: '',
            userName: '',
            selectedImage: props.selectedImage,
            storageType: 'Standard',
            isPremiumStorageEnabled: false,
            isAuthenticationWithSshKey: false,
            vmName: '',
            vmSize: '',
            allowClaim: false,
            lab: props.lab,
            artifacts: [],
            addAdmin: false,
            domainJoin: false
        };

        this.handleVmSizeChange = this.handleVmSizeChange.bind(this);
        this.handleAuthTypeRadioButtonChange = this.handleAuthTypeRadioButtonChange.bind(this);
        this.handleFormulaContent = this.handleFormulaContent.bind(this);
        this.handleParameterChange = this.handleParameterChange.bind(this);
        this.evaluatePoliciesAndHandleSubmitAsync = this.evaluatePoliciesAndHandleSubmitAsync.bind(this);
        this.handleAddAdminChange = this.handleAddAdminChange.bind(this);
        this.handleDomainJoinChange = this.handleDomainJoinChange.bind(this);

        if (props.selectedImage && props.selectedImage.formulaContent ) {
            this.handleFormulaContent(props);
        }
    }

    componentWillReceiveProps(nextProps: AddVmFormProps) {
        if (this.state.selectedImage === nextProps.selectedImage) {
            return;
        }
        if ( nextProps.selectedImage.formulaContent ) {
            this.handleFormulaContent(nextProps);
        } else {
            this.setState({selectedImage: nextProps.selectedImage,
                           lab: nextProps.lab,
                           artifacts: []});
        }
    }

    async handleFormulaContent(props: AddVmFormProps) {
        let formulaArtifacts =  props.selectedImage.formulaContent.properties.artifacts;
        const detailedArtifacts = await Promise.all(
            formulaArtifacts.map(artifact => {
                return Dtl.getArtifactDetailsAndParametersAsync(artifact);
            })
        );
       
        this.setState({
            notes: props.selectedImage.formulaContent.properties.notes || '',
            userName: props.selectedImage.formulaContent.properties.userName || '',  
            password: props.selectedImage.formulaContent.properties.password || '',  
            sshKey: props.selectedImage.formulaContent.properties.password || '',  
            isAuthenticationWithSshKey: props.selectedImage.formulaContent.properties.isAuthenticationWithSshKey,  
            vmSize: props.selectedImage.formulaContent.properties.size || '',
            artifacts: detailedArtifacts, 
            selectedImage: props.selectedImage,
            lab: props.lab
        });
    }
    
    handleVmSizeChange(selectedSize: string, premiumStorage?: boolean) {
        this.setState({vmSize: selectedSize, isPremiumStorageEnabled: premiumStorage});
    }
    
    authTypeRadioButton() {
        if (this.state.selectedImage && this.state.selectedImage.ostype !== 'Windows') {
            return <div className="form-group">
                <label htmlFor="AuthenticationType">
                    Authentication type
                </label>
                <div>
                    <label>
                        <input
                            type="radio"
                            checked={!this.state.isAuthenticationWithSshKey}
                            onChange={this.handleAuthTypeRadioButtonChange}
                            value="Password"
                        />
                        Password
                    </label>
                    <label>
                        <input
                            type="radio"
                            checked={this.state.isAuthenticationWithSshKey}
                            onChange={this.handleAuthTypeRadioButtonChange}
                            value="SSHKey"
                        />
                        SSH public key
                    </label>
                </div>
            </div>;
        } 
    }

    // tslint:disable
    // typing onChange handlers will be easier with https://github.com/DefinitelyTyped/DefinitelyTyped/pull/14028
    passwordInputBox() {
        let inputBoxLabel =  <label>Password</label> ;
        if (this.state.selectedImage  && this.state.selectedImage.ostype !== 'Windows') {
            inputBoxLabel =  <label>Type a value</label> ;
        }
        const inputBoxElement = this.state.isAuthenticationWithSshKey ?
            <input
                type="text"
                className="form-control"
                onChange={(event: any) => this.setState({ sshKey: event.target.value })}
                value={this.state.sshKey}
                required={true}
            /> :
           <input
                type="password"
                className="form-control"
                onChange={(event: any) => this.setState({ password: event.target.value })}
                value={this.state.password} 
                required={true}
           />;
        return <div className="form-group">
                    {inputBoxLabel}
                    {inputBoxElement}
                </div>;
    }

    handleParameterChange (e: any, parameter: Dtl.Parameter) {
        parameter.value = e.target.value;
        this.setState({});
    }
    
    renderArtifacts() {
        if (this.props.selectedImage) {
            const renderArtifactParameters  = (parameter, artifact) => <div className="form-group" key={parameter.name}>
                <div>
                    <label>
                         {`${artifact.title}:${parameter.displayName}`}
                    </label>
                </div>
                <div> 
                    <input
                        className="form-control"
                        value={parameter.value}
                        type={parameter.type === 'securestring' ? 'password' : parameter.type}
                        id={parameter.name}
                        required={!parameter.allowEmpty}
                        // Now this is read only for artifacts having file input parameters. 
                        readOnly={parameter.controlType === 'fileContents'} 
                        onChange={(event: any) => this.handleParameterChange(event, parameter)}
                    />
                </div>
            </div>;

            if (this.state.artifacts) {
                let renderItems = Array<JSX.Element>();
                for (const artifact of this.state.artifacts) {
                    const parameters = artifact.parameters.map(parameter => 
                                                               renderArtifactParameters (parameter, artifact));
                    renderItems = renderItems.concat(parameters);
                }
                
                if (renderItems) {
                    return <div htmlFor="Artifacts">
                            <label>Required artifact parameters</label>
                                {renderItems}
                       </div>;
                }
            }
        }
    }
   
    // These artifacts are mandatory for domain joining the machines for DDIT. 
    // This is just a nice to have feature for internal customers who find adding articfacts painful. 
    renderWindowsDomainOptions() {
        if (this.state.selectedImage && this.state.selectedImage.type !== 'Formula' &&
            this.state.selectedImage.ostype === 'Windows') {
           return <div>
                <div className="form-group">
                    <label >
                        <input 
                            type="checkbox" 
                            id="addAdmin"
                            onChange={this.handleAddAdminChange}
                            checked={this.state.addAdmin}
                        />
                        Add user as admin
                    </label>
                    </div>
                    <div className="form-group">   
                    <label >
                        <input 
                            type="checkbox" 
                            id="domainJoin"
                            onChange={this.handleDomainJoinChange}
                            checked={this.state.domainJoin}
                        />
                        Domain join the machine
                    </label>
                </div>
            </div>;
        }
    }

    handleAddAdminChange() {
        const lab = this.state.lab;
        const addAdminArtifact: Dtl.Artifact = {'artifactId': `/subscriptions/${lab.subscriptionId}/resourceGroups/` +
                                         `${lab.resourceGroupName}/providers/Microsoft.DevTestLab/labs/${lab.name}/` +
                                       `artifactSources/public repo/artifacts/windows-enable-local-admins`,
                          'parameters': []} ;               
    
        let artifacts = this.state.artifacts;
        if (this.state.addAdmin) {
            if (artifacts) {
                const index = artifacts.findIndex(artifact => artifact.artifactId === addAdminArtifact.artifactId);
                if (index > -1) {
                    artifacts.splice(index, 1);
                }
            } 

            this.setState({artifacts: artifacts,
                           addAdmin: false});
        } else {
            artifacts.push(addAdminArtifact);
            this.setState({artifacts: artifacts,
                           addAdmin: true});
        }
    }

    async handleDomainJoinChange() {
        const lab = this.state.lab;
        const domainJoinArtifact: Dtl.Artifact = {'artifactId': `/subscriptions/${lab.subscriptionId}/resourceGroups/` +
                                         `${lab.resourceGroupName}/providers/Microsoft.DevTestLab/labs/${lab.name}/` +
                                         `artifactSources/public repo/artifacts/windows-domain-join`,
                            'parameters': [{'name': 'domainName', 'value': 'corp.microsoft.com'},
                                          {'name': 'domainOU', 'value': 'redmond'},
                                          {'name': 'domainJoinUser', 'value': 'REDMOND\\user'},
                                          {'name': 'domainJoinUserPassword', 'value': 'passowrd'},
                                          {'name': 'domainJoinOptions', 'value': '3'}]};
        
       
        let artifacts = this.state.artifacts;
        if (this.state.domainJoin) {
            if (artifacts) {
                const index = artifacts.findIndex(artifact => artifact.artifactId === domainJoinArtifact.artifactId);
                if (index > -1) {
                    artifacts.splice(index, 1);
                }
            } 
            this.setState({artifacts: artifacts,
                           domainJoin: false});
        } else {
            const detailedArtifact = await Dtl.getArtifactDetailsAndParametersAsync(domainJoinArtifact);
            artifacts.push(detailedArtifact);
            this.setState({artifacts: artifacts,
                           domainJoin: true});
        }
    }

    async evaluatePoliciesAndHandleSubmitAsync() {
        const maximumVMpolicies: Dtl.Policy[] =  [{
            factName : 'UserOwnedLabVmCount',
            factData: '',
            valueOffset: '1'
        },
        {
            factName : 'UserOwnedLabPremiumVmCount',
            factData: '',
            valueOffset: '1'
        },
        {
            factName : 'LabVmCount',
            factData: '',
            valueOffset: '1'
        },
        {
            factName: 'LabPremiumVmCount',
            factData: '',
            valueOffset: '1'
        }];
        
        const policyEvaluationResult = await Dtl.evaluatePoliciesAsync(this.props.lab, maximumVMpolicies);
        if (policyEvaluationResult) {
            alert(policyEvaluationResult.errorMessage);
        } else {
            this.props.submitHandler(this.state);
        }
    }
    
     handleAuthTypeRadioButtonChange(event: any) {
        if (event.target.value === 'SSHKey') {
            this.setState({password: '', isAuthenticationWithSshKey: true}); 
        } else {
            this.setState({sshKey: '', isAuthenticationWithSshKey: false});
        }
    }

    public render() {
        return <form> 
            <div className="form-group">
                <label htmlFor="vmName">Virtual machine name</label>
                <input
                    type="text"
                    className="form-control"
                    id="vmName"
                    onChange={(event: any) => this.setState({ vmName: event.target.value })}
                    value={this.state.vmName}
                    required={true}
                />
            </div>
            <div className="form-group">
                <label htmlFor="userName">User name</label>
                <input
                    type="text"
                    className="form-control"
                    id="userName"
                    onChange={(event: any) => this.setState({ userName: event.target.value })}
                    value={this.state.userName}
                    required={true}
                />
            </div>
            {this.authTypeRadioButton()}
            {this.passwordInputBox()}
            <div className="form-group">
                <label htmlFor="StorageType">Disk and size</label>
                <div>
                    <label>
                        <input
                            type="radio"
                            checked={this.state.storageType === 'Standard'}
                            onChange={(event: any) => this.setState({ storageType: event.target.value })}
                            value="Standard"
                        />
                        HDD
                    </label>
                    <label>
                        <input
                            type="radio"
                            checked={this.state.storageType === 'Premium'}
                            onChange={(event: any) => this.setState({ storageType: event.target.value })}
                            value="Premium"
                            disabled={!this.state.isPremiumStorageEnabled}
                        />
                        SDD
                    </label>
                </div>
            </div>
            <div className="form-group">
                <label htmlFor="vmSize">Virtual machine size</label>
                <VmSizeDropdown 
                    lab={this.props.lab}
                    storageType={this.state.storageType}
                    defaultSize={this.state.vmSize}
                    changeHandler={this.handleVmSizeChange}
                />
            </div>
            <div className="form-group">
                <label >
                    <input 
                        type="checkbox" 
                        id="cbox2"
                        onChange={() => this.setState({allowClaim: !this.state.allowClaim})}
                        checked={this.state.allowClaim}
                    />
                    Allow claim
                </label>
            </div>
            {this.renderWindowsDomainOptions()}
            <div className="form-group">
                <label htmlFor="notes">Notes</label>
                <input
                    type="text"
                    className="form-control"
                    id="notes"
                    onChange={(event: any) => this.setState({ notes: event.target.value })}
                    value={this.state.notes}
                    required={true}
                />
            </div>
            {this.renderArtifacts()}
            <button
                type="button"
                className="btn btn-default"
                onClick={this.evaluatePoliciesAndHandleSubmitAsync}
            >
                Create
            </button>
            <button type="button" className="btn btn-default" onClick={this.props.exitForm}>Cancel</button>
        </form>;
    }
}