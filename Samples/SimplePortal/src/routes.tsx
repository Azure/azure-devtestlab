import * as React from 'react';
import { Route } from 'react-router';
import { Lab } from './components/Lab';
import { Layout } from './components/Layout';
import innercomponent from './components/AuthenticatedComponent';

export default <Route path="/" component={innercomponent(Layout)}>
    (<Route path="/lab/:location/:subscriptionId/:resourceGroupName/:name" component={Lab} />)
</Route>;
