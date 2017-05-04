import * as React from 'react';
import { Dtl } from '../dtl';
import { browserHistory, Link } from 'react-router';

interface LabSelectorState {
    labs?: Dtl.Lab[];
    loading?: boolean;
}

export class LabNavbar extends React.Component<{}, LabSelectorState> {
    constructor() {
        super();
        this.state = { loading: true };
        this.renderLinks = this.renderLinks.bind(this);
        this.getLabRoute = this.getLabRoute.bind(this);
    }

    getLabRoute(lab: Dtl.Lab): string {
        return `/lab/${lab.location}/${lab.subscriptionId}/${lab.resourceGroupName}/${lab.name}`;
    }

    async componentDidMount() {
        const labs = await Dtl.getLabsAsync();
        this.setState({ labs: labs, loading: false });
        if (labs.length > 0) {
            browserHistory.push(this.getLabRoute(labs[0]));
        }
    }
    
    public render() {
        const content = this.state.loading
            ? <li>
                <a style={{ cursor: 'pointer' }}>
                    <span className="glyphicon glyphicon-refresh" />Loading labs...
                </a>
              </li>
            : this.renderLinks(this.state.labs);

        return <div className="navbar-collapse collapse">
            <ul className="nav navbar-nav">{content}</ul>
        </div>;
    }

    private renderLinks(labs: Dtl.Lab[]) {
        return labs.length < 1
            ? <li>
                <a style={{ cursor: 'pointer' }}><span className="glyphicon glyphicon-remove" />No labs found</a>
              </li>
            : labs.map(lab =>
                <li key={lab.name}>
                    <Link
                        to={this.getLabRoute(lab)}
                        activeClassName="active"
                    >
                        <span className="glyphicon glyphicon-asterisk" /> {lab.name}
                    </Link>
                </li>
            );
    }
}
