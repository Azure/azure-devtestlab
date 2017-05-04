import * as React from 'react';
import { browserHistory, Router } from 'react-router';
import routes from './routes';

const App = () => (
    <Router history={browserHistory} children={routes} />
);

export default App;