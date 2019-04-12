const authority = 'https://login.microsoftonline.com/common/oauth2/authorize';
const redirectUri = window.location;
const baseUrl = 'https://management.azure.com';
const apiVersion = '?api-version=2015-11-01';
var myVmList = [];
var claimableVmList = [];
var ownerObjectId;
var spinner;
var claimedVm;
var timeouHandle;

// Connect And Token Functions 
function ConnectAndStoreToken(clientId) {
  if (window.location.hash) {
    var fragments = {};
    var hashSegments = window.location.hash.substr(1).split('&');
    for (const fragment of hashSegments) {
      const item = fragment.split('=');
      fragments[item[0]] = item[1];
    }
    // Save the token
    window.sessionStorage.setItem('access_token', fragments['access_token']);
    var tokenExpiry = new Date();
    tokenExpiry.setMinutes(tokenExpiry.getMinutes() + 59);
    window.sessionStorage.setItem('token_expiry', tokenExpiry.toString());
    // Redirect back to home page
    window.location = redirectUri;
  } else {
    const token = window.sessionStorage.getItem('access_token');

    if (!token) {
      connect(clientId);
    } else {
      const expiry = window.sessionStorage.getItem('token_expiry');
      var expireTime = Date.parse(expiry);
      if (Date.now > expireTime) {
        connect(clientId);
      }
    }
  }
}

function connect(clientId) {
  const oauthUrl = `${authority}?`
    + '&client_id=' + encodeURIComponent(clientId)
    + '&nonce=' + encodeURIComponent('TODO')
    + '&redirect_uri=' + encodeURIComponent(redirectUri)
    + '&resource=' + encodeURIComponent('https://management.azure.com/')
    + '&response_mode=' + encodeURIComponent('fragment') + '&prompt='
    + encodeURIComponent('consent')
    + '&response_type='
    + encodeURIComponent('token');

  window.location.assign(oauthUrl);
}

function startSpinner() {
  var opts = {
    lines: 13, // The number of lines to draw
    length: 7, // The length of each line
    width: 4, // The line thickness
    radius: 10, // The radius of the inner circle
    corners: 1, // Corner roundness (0..1)
    rotate: 0, // The rotation offset
    color: '#000', // #rgb or #rrggbb
    speed: 1, // Rounds per second
    trail: 60, // Afterglow percentage
    shadow: false, // Whether to render a shadow
    hwaccel: false, // Whether to use hardware acceleration
    class: 'spinner', // The CSS class to assign to the spinner
    zIndex: 2e9, // The z-index (defaults to 2000000000)
    top: '200px', // Top position relative to parent in px
    left: '200px' // Left position relative to parent in px
  };

  var target = document.createElement('spinnerContainer');
  target.className = 'spinner';
  target.style = "width:100px;height:100px;";

  document.body.appendChild(target);
  spinner = new Spinner(opts).spin(target);
}

function stopSpinner() {
  if (spinner) {
    spinner.stop();
  }
}

function startVm(labUrl, vmName) {
  const url = `${labUrl}/virtualmachines/${vmName}/start?api-version=2016-05-15`;
  postRequest(url, null, function (responseText) {
    console.log(responseText);
  });
}

// Main Claim Any VM function
// This is the main function that user calls from this Javascirpt library. 
// We are assuming at this point the user has a valid Token which gets stored in SessionStorage by html onload
// Parameters subscriptionId : Subscription ID of the User
// resourceGroupName : Resource group name of the lab. 
// labName: Name of the lab where we are trying to ClaimAnyVM
// successCallback: Callback called when we claim VM and download an RDP file. The callback takes a string paramter. 
// failureCallback: Callback called when there is some sort of error. This callback also takes a string parameter explaining the error. 
function ClaimAnyVm(subscriptionId, resourceGroupName, labName, successCallback, failureCallback) {
  const labUrl = `${baseUrl}/subscriptions/${subscriptionId}/resourcegroups/${resourceGroupName}/providers/Microsoft.DevTestLab/labs/${labName}`;
  startSpinner();

  const ownerObjecturl = `${labUrl}/users/@me?api-version=2016-05-15`;
  // Set the ownerObjectId
  getRequest(ownerObjecturl, function (response) {
    var json = JSON.parse(response);
    ownerObjectId = json.name;
    // Check if we have Claimable VM's.
    const claimableVmsUrl = `${labUrl}/virtualmachines?api-version=2016-05-15&$expand=Properties($expand=ComputeVm,NetworkInterface,ApplicableSchedule)&$filter=properties/allowClaim`;
    getRequest(claimableVmsUrl, function (response) {
      var json = JSON.parse(response);
      var vms = json.value;
      if (!vms || vms.length <= 0) {
        stopSpinner();
        failureCallback('No Claimable VMs in lab');
      } else {
        // We have Claimable VM's. Starting process of claiming.
        const claimAnyurl = `${labUrl}/claimAnyVm?api-version=2016-05-15`;
        postRequest(claimAnyurl, null, function (response) {
          // Successfully sent Post request 
          pollToGetClaimedVm(10, labUrl, successCallback, failureCallback);
        }, function (response) {
          // Post failed. 
          stopSpinner();
          failureCallback('Unable to perform ClaimAnyVM Post Operation. Error:' + response);
        });
      }
    }, function (response) {
      // No Claimable VM's. 
      stopSpinner();
      failureCallback('Unable to get the list of Claimable VMs. Error:' + response);
    });

  }, function (response) {
    // Error getting Owner Object Id
    stopSpinner();
    failureCallback('Unable to get Owner Object Id. Error:' + response);
  });
}


function pollToGetClaimedVm(attempts, labUrl, successCallback, failureCallback) {
  const url = `${labUrl}/virtualmachines?api-version=2016-05-15&$expand=Properties($expand=ComputeVm,NetworkInterface,ApplicableSchedule)&$filter=tolower(Properties/OwnerObjectId)%20eq%20tolower('${ownerObjectId}')`;

  if (claimedVm) {
    return;
  }
  getRequest(url, function (response) {
    var json = JSON.parse(response);
    newVmList = json.value;

    if (newVmList.length > 0) {
      // Store claimedVm to create the rdp file
      claimedVm = newVmList[0];
      startVm(labUrl, claimedVm.name);
      // Now wait till the claimedVM is starting 
      pollTillVmRunning(labUrl, claimedVm.name, 20, function () {
        const networkInterface = claimedVm.properties.networkInterface;
        const address = claimedVm.properties.fqdn || networkInterface.publicIpAddress || networkInterface.privateIpAddress;
        connectWindowsVm(claimedVm.name, address);
        successCallback('Claimed VM is ' + claimedVm.name);
      });
    }
    setTimeout(function () {
      if (attempts > 0 && !claimedVm) {
        pollToGetClaimedVm(attempts - 1, labUrl, successCallback, failureCallback);
      } else {
        if (!claimedVm) {
          stopSpinner();
          failureCallback('Unable to get Claimed VM.');
        }
      }
    }, 10000);
  }, function (response) {
    setTimeout(function () {
      if (attempts > 0 && !claimedVm) {
        pollToGetClaimedVm(attempts - 1, labUrl, successCallback, failureCallback);
      } else {
        if (!claimedVm) {
          stopSpinner();
          failureCallback('Unable to get Claimed VM.');
        }
      }
    }, 10000);
  });

}

function pollTillVmRunning(labUrl, vmName, pollAttempts, success) {
  const url = `${labUrl}/virtualmachines/${vmName}?api-version=2016-05-15&$expand=Properties($expand=ComputeVm,NetworkInterface,ApplicableSchedule)`;
  getRequest(url, function (response) {
    var vm = JSON.parse(response);
    var state = vm.properties.provisioningState;
    if (state === 'Succeeded') {
      const powerState = vm
        .properties
        .computeVm
        .statuses
        .find(status => status.code.startsWith('PowerState'));

      if (powerState) {
        state = powerState.displayStatus.replace('VM ', '');
      }
    }
    if (state === 'running') {
      success();

    } else {
      setTimeout(function () {
        if (pollAttempts > 0) {
          pollTillVmRunning(labUrl, vmName, pollAttempts - 1, success);
        }
      }, 10000);
    }
  }, function (response) {
    setTimeout(function () {
      if (pollAttempts > 0) {
        pollTillVmRunning(labUrl, vmName, pollAttempts - 1, success);
      }
    }, 10000);
  });
}

function connectWindowsVm(vmName, vmFqdn) {
  const fileContents = `full address:s:${vmFqdn}:3389 \n prompt for credentials:i:1`;
  const filename = `${vmName}.rdp`;
  const filetype = 'text/plain';
  const dataURI = `data:${filetype};base64,${btoa(fileContents)}`;

  const blob = this.dataURItoBlob(dataURI);
  // IE 10 and above supports a msSaveBlob or msSaveOrOpenBlob to trigger file
  // save dialog.
  if (navigator.msSaveOrOpenBlob) {
    navigator.msSaveOrOpenBlob(blob, filename);
  } else {
    // For other browsers (Chrome, Firefox, ...) to prevent popup blockers, we
    // create a hidden <a> tag and set the url and invoke a click action.
    var a = document.createElement('a');
    a.href = dataURI;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
  }

  // At this point if the spinner is still running stop it. 
  if (spinner) {
    spinner.stop();
  }
}

function dataURItoBlob(dataURI) {
  const byteString = atob(dataURI.split(',')[1]);

  const mimeString = dataURI
    .split(',')[0]
    .split(':')[1]
    .split(';')[0];

  // write the bytes of the string to an ArrayBuffer
  const ab = new ArrayBuffer(byteString.length);
  const ia = new Uint8Array(ab);
  for (var i = 0; i < byteString.length; i++) {
    ia[i] = byteString.charCodeAt(i);
  }

  // write the ArrayBuffer to a blob, and you're done
  const blob = new Blob([ab], { type: mimeString });
  return blob;
}

// Get and Post functions
function getRequest(url, success, reject) {
  var accessToken = window.sessionStorage.getItem('access_token');
  var xhr = new XMLHttpRequest();
  xhr.open('GET', url);
  xhr.setRequestHeader('Authorization', 'Bearer ' + accessToken);
  xhr.onload = function () {
    if (xhr.status >= 200 && xhr.status < 300) {
      success(xhr.response);
    }
    else {
      if (typeof (failureCallback) === 'function') {
        reject(xhr.statusText);
      }
    }
  };
  xhr.onerror = function () {
    if (typeof (failureCallback) === 'function') {
      reject(xhr.statusText);
    }
  };
  xhr.send();
}

function postRequest(url, data, success, reject) {
  var accessToken = window.sessionStorage.getItem('access_token');
  var xhr = new XMLHttpRequest();
  xhr.open('POST', url);
  xhr.setRequestHeader('Authorization', 'Bearer ' + accessToken);

  xhr.onreadystatechange = function () {
    if (xhr.readyState == XMLHttpRequest.DONE && xhr.status >= 200 && xhr.status < 300) {
      success(xhr.responseText);
    }
    else if (xhr.status > 399) {
      reject(xhr.statusText);
    }
  }
  xhr.onerror = function () {
    reject(xhr.statusText);
  };
  xhr.send(data);
}
