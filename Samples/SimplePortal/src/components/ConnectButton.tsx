import * as React from 'react';
import {Dtl} from '../dtl';

interface ConnectButtonProps {
    vm: Dtl.Vm;
}

function connectWindowsVm(vm: Dtl.Vm) {   
    const fileContents = `full address:s:${vm.fqdn}:3389 \n prompt for credentials:i:1`;
    const filename = `${vm.name}.rdp`;
    const filetype = 'text/plain';
    const dataURI = `data:${filetype};base64,${btoa(fileContents)}`;

    const blob = dataURItoBlob(dataURI);

    // IE 10 and above supports a msSaveBlob or msSaveOrOpenBlob to trigger file
    // save dialog.
    if (navigator.msSaveOrOpenBlob) {
        navigator.msSaveOrOpenBlob(blob, filename);
    } else {
        // For other browsers (Chrome, Firefox, ...) to prevent popup blockers, we
        // create a hidden <a> tag and set the url and invoke a click action.
        let a = document.createElement('a');
        a.href = dataURI;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        a.remove();
    }
}

function dataURItoBlob(dataURI: string): Blob {
    const byteString = atob(dataURI.split(',')[1]);

    const mimeString = dataURI
        .split(',')[0]
        .split(':')[1]
        .split(';')[0];

    // write the bytes of the string to an ArrayBuffer
    const ab = new ArrayBuffer(byteString.length);
    const ia = new Uint8Array(ab);
    for (let i = 0; i < byteString.length; i++) {
        ia[i] = byteString.charCodeAt(i);
    }

    // write the ArrayBuffer to a blob, and you're done
    const blob = new Blob([ab], {type: mimeString});
    return blob;
}

const ConnectButton = (props: ConnectButtonProps) => (
    <button
        className="btn btn-default"
        disabled={!props.vm || !props.vm.fqdn || props.vm.os.toLowerCase() === 'linux'}
        onClick={() => connectWindowsVm(props.vm)}
    >
        <div className="glyphicon glyphicon-link"/>
        Connect
    </button>
);

export default ConnectButton;