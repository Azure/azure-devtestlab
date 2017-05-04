import * as React from 'react';
import * as ReactDOM from 'react-dom';
import App from './App';

// this is broken due to reliance on window.sessionStorage
it('renders without crashing', () => {
  const div = document.createElement('div');
  ReactDOM.render(<App />, div);
});
