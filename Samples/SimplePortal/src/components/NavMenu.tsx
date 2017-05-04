import * as React from 'react';
import { Link } from 'react-router';
import { LabNavbar } from './LabNavbar';

const NavMenu = () => (
    <div className="main-nav">
        <div className="navbar navbar-inverse">
            <div className="navbar-header">
                <button
                    type="button"
                    className="navbar-toggle"
                    data-toggle="collapse"
                    data-target=".navbar-collapse"
                >
                    <span className="sr-only">Toggle navigation</span>
                    <span className="icon-bar" />
                    <span className="icon-bar" />
                    <span className="icon-bar" />
                </button>
                <Link className="navbar-brand" to={'/'}>SimplePortal</Link>
            </div>
            <div className="clearfix" />
            <LabNavbar />
        </div>
    </div>
);

export default NavMenu;