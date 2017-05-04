import * as React from 'react';
import { AddVm } from './AddVm';
import { Dtl } from '../dtl';
import { VmList } from './VmList';

interface LabState {
    lab?: Dtl.Lab;
    loading?: boolean;
    showVmList?: boolean;
    ownerObjectId?: string;
    vms?: Dtl.Vm[];
    claimableVms?: Dtl.Vm[];  
    baseImages?: Dtl.Image[];
}

interface LabProps {
    params: {
        name: string;
        resourceGroupName: string;
        subscriptionId: string;
        location: string;
    };
}

export class Lab extends React.Component<LabProps, LabState> {
    refresh: number;
    isComponentMounted: boolean;
    constructor(props: LabProps) {
        super();

        const lab: Dtl.Lab = {
            name: props.params.name,
            resourceGroupName: props.params.resourceGroupName,
            subscriptionId: props.params.subscriptionId,
            location: props.params.location
        };

        this.refreshVms = this.refreshVms.bind(this);
        this.state = {lab: lab, showVmList: true, loading: true, vms: [], claimableVms: [], baseImages: []};
    }

    componentWillReceiveProps(nextProps: LabProps) {
        if (nextProps.params.name === this.state.lab.name
            && nextProps.params.resourceGroupName === this.state.lab.resourceGroupName) {
            return;
        }
     
        const newLab: Dtl.Lab = {
            name: nextProps.params.name,
            resourceGroupName: nextProps.params.resourceGroupName,
            subscriptionId: nextProps.params.subscriptionId,
            location: nextProps.params.location
        };

        this.setState({lab: newLab, showVmList: true, loading: true }, () => {this.refreshVms(); this.getImages(); });
    }

    async componentDidMount() {
        this.isComponentMounted = true;
        const ownerObjectId = await Dtl.getUserIdAsync(this.state.lab);
        this.setState({ ownerObjectId: ownerObjectId}, () => {this.refreshVms(); this.getImages(); });
    }
 
    componentWillUnmount() {
        this.isComponentMounted = false;
        window.clearTimeout(this.refresh);
    }

    async refreshVms(interval?: number) {
        if (interval) {
            await this.sleep(interval);
        }
        
        if (!this.state.showVmList) {
            return;
        }
        const vms = await Promise.all([Dtl.getVmsAsync(this.state.lab, this.state.ownerObjectId),
                                      Dtl.getClaimableVmsAsync(this.state.lab)]);

        window.clearTimeout(this.refresh);
        this.refresh = window.setTimeout(() => this.refreshVms(), 10000);
        if (this.isComponentMounted) {
            this.setState({vms: vms[0], claimableVms: vms[1], loading: false});
        }
    }

    async getImages() {
        const images = await Promise.all([
            Dtl.getCustomImagesAsync(this.state.lab),
            Dtl.getFormulasAsync(this.state.lab),
            Dtl.getGalleryImagesAsync(this.state.lab)
        ]);
        this.setState({baseImages: [].concat.apply([], images)});
    }
    
    async sleep(ms: number) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    public render() {
        const content = this.state.loading
            ? <p><em>Loading...</em></p>
            : this.renderTable();
        
        return <div>{content}</div>;
    }

    renderTable() {
        return this.state.showVmList ?
        <VmList 
            lab={this.state.lab} 
            vms={this.state.vms} 
            claimableVms={this.state.claimableVms}
            addVm={() => this.setState({showVmList: false})}
            refreshVms={(interval?: number) => this.refreshVms(interval)}
        /> :
         <AddVm
            lab={this.state.lab} 
            exitForm={() => this.setState({ showVmList: true })} 
            baseImages={this.state.baseImages}
         />;
    }
}