import * as React from 'react';
import { Dtl } from '../dtl';
import ConnectButton from './ConnectButton';
import * as NotificationSystem from 'react-notification-system';

interface VmListState {
    selectedVm?: Dtl.Vm;
    claimableVmSelected?: boolean;

}

interface VmListProps {
    vms: Dtl.Vm[];
    claimableVms?: Dtl.Vm[];  
    lab: Dtl.Lab;
    addVm?: () => void;
    refreshVms?: (interval?: number) => void;
}

var style = {
    NotificationItem: { 
        DefaultStyle: { 
            margin: '10px 10px 1px 1px',
            backgroundColor: '#C0EFFC',
            color: '#4b583a',
            borderTop: '2px solid ' + '#00bcf2',
        }
    }
};
    
export class VmList extends React.Component<VmListProps, VmListState> {
    refresh: number;
    notification;
    isVmListMounted: boolean;
   
    constructor(props: VmListProps) {
        super();
        this.state = {};
        this.deleteVm = this.deleteVm.bind(this);
        this.addAlert = this.addAlert.bind(this);
    }

    deleteVm() {
        if (this.state.selectedVm && 
            confirm(`Are you sure you want to delete ${this.state.selectedVm.name}`)) {
            Dtl.deleteVm(this.state.selectedVm);
            this.addAlert(`Deleting ${this.state.selectedVm.name}`);
        }
    }

    addAlert(message: string) {
        this.notification.addNotification({
            message: message,
            position: 'tr',
            level: 'success'
        });
    }

    public render() {
        const selectedVm = this.state.selectedVm;

        return <div>
            <NotificationSystem  ref = {(notification) => {this.notification = notification; }} style = {style}/>
            <button
                className="btn btn-default"
                onClick={() => {this.addAlert('Refreshing ...');
                                this.props.refreshVms();
                                this.setState({selectedVm: undefined, claimableVmSelected: false}); }}
            >
                <div className="glyphicon glyphicon-refresh" />
                Refresh
            </button>
            <button
                onClick={this.props.addVm}
                className="btn btn-default"
            >
                <div className="glyphicon glyphicon-plus" />
                Add VM
            </button>
            <button
                onClick={() => { Dtl.claimAnyVm(this.props.lab);
                                 this.addAlert('Claiming any available VM ...'); }}
                disabled={!(this.props.claimableVms && this.props.claimableVms.length > 0)}
                className="btn btn-default"
            >
                <div className="glyphicon glyphicon-download-alt" />
                Claim any VM
            </button>
            <button
                onClick={() => { Dtl.claimVm(selectedVm);
                                 this.addAlert(`Claiming ${selectedVm.name} ...`);
                                 this.setState({claimableVmSelected: false});
                                 this.props.refreshVms(5000); }}
                disabled={!this.state.claimableVmSelected}
                className="btn btn-default"
            >
                <div className="glyphicon glyphicon-download-alt" />
                Claim VM
            </button>
            <ConnectButton vm={selectedVm} />
            <button
                className="btn btn-default"
                disabled={!selectedVm || selectedVm.state === 'running'}
                onClick={() => { Dtl.startVm(selectedVm); 
                                 this.props.refreshVms(5000);
                                 this.addAlert(`Starting ${selectedVm.name} ...`); }}
            >                    
                <div className="glyphicon glyphicon-play" />
                Start
            </button>
            <button
                className="btn btn-default"
                disabled={!selectedVm || selectedVm.state !== 'running'}
                onClick={() => { Dtl.stopVm(selectedVm);
                                 this.props.refreshVms(5000);
                                 this.addAlert(`Stopping ${selectedVm.name} ...`); }}
            >
                <div className="glyphicon glyphicon-stop" />
                Stop
            </button>
            <button
                className="btn btn-default"

                disabled={!selectedVm}
                onClick={() => this.deleteVm()}
            >
                <div className="glyphicon glyphicon-trash" />
                Delete
            </button>
            <button
                className="btn btn-default"
                disabled={!selectedVm}
                onClick={() => window.open(`https://portal.azure.com/#resource${selectedVm.id}/overview`)}
            >
                <div className="glyphicon glyphicon-cloud" />
                View in Azure Portal
            </button>
            <div>
            <br/>
            <label>My virtual machines</label> 
                <table className="table table-hover textsmall">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>DNS Name</th>
                            <th>Creator</th>
                            <th>State</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.props.vms.map(vm =>
                            <tr
                                key={vm.name}
                                className={(selectedVm && selectedVm.name === vm.name) ? 'active' : ''}
                                onClick={() => this.setState({ selectedVm: vm, claimableVmSelected: false })}
                            >
                                <td>{vm.name}</td>
                                <td>{vm.fqdn}</td>
                                <td>{vm.createdByUser}</td>
                                <td>{vm.state || ''}</td>
                            </tr>
                        )}
                    </tbody>
                </table>
            <br/>
            <label>Claimable virtual machines</label> 
                <table className="table table-hover textsmall">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>DNS Name</th>
                            <th>Creator</th>
                            <th>State</th>
                        </tr>
                    </thead>
                    <tbody>
                        {this.props.claimableVms.map(vm =>
                            <tr
                                key={vm.name}
                                className={(selectedVm && selectedVm.name === vm.name) ? 'active' : ''}
                                onClick={() => this.setState({ selectedVm: vm, claimableVmSelected: true })}
                            >
                                <td>{vm.name}</td>
                                <td>{vm.fqdn}</td>
                                <td>{vm.createdByUser}</td>
                                <td>{vm.state || ''}</td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>
        </div>;
    }
}
