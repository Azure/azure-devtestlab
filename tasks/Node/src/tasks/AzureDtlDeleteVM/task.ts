import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { DevTestLabsClient } from "@azure/arm-devtestlabs";

async function ensureVmExists(client: DevTestLabsClient, labVmId: string): Promise<any> {
    let labName: string = resutil.getLabResourceName(labVmId, 'labs');
    let labRgName: string = resutil.getLabResourceName(labVmId, 'resourcegroups');
    let vmName: string = resutil.getLabResourceName(labVmId, 'virtualmachines');

    console.log(`Determining if VM '${vmName}' exists in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const labVms = await client.virtualMachines.list(labRgName, labName);

    var vmExists = labVms && labVms.some((vm) => {
        if (vm && vm.name) {
            return vm.name.toLocaleLowerCase() === vmName;
        }
    });

    const message: string = `Lab VM '${vmName}' ${vmExists ? 'exists' : 'does not exist'}.`;

    if (vmExists) {
        console.log(message);
    }
    else {
        throw message;
    }
}

async function deleteVm(client: DevTestLabsClient, labVmId: string): Promise<any> {
    let labName = resutil.getLabResourceName(labVmId, 'labs');
    let labRgName = resutil.getLabResourceName(labVmId, 'resourcegroups');
    let vmName = resutil.getLabResourceName(labVmId, 'virtualmachines');

    await ensureVmExists(client, labVmId);

    console.log(`Deleting VM '${vmName}' from Lab '${labName}' under Resource Group '${labRgName}'.`);

    const results = await client.virtualMachines.deleteMethod(labRgName, labName, vmName);
    if (results) {
        var status = Object.keys(results._response.parsedBody);

        if (results._response.parsedBody[status[0]] != 'Succeeded') {
            throw results._response.parsedBody;
        }
    }

    console.log(`Finished deleting Lab VM '${vmName}'.`);
}

async function testRun() {
    try {
        const data: any = await testutil.getTestData();

        const vmName: string = resutil.getLabResourceName(data.labVmId, 'virtualmachines');

        const client: DevTestLabsClient = await resutil.getDtlClient(data.subscriptionId, true);

        await deleteVm(client, data.labVmId);

        tl.setResult(tl.TaskResult.Succeeded, `Lab VM '${vmName}' was successfully deleted.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

async function run() {
    try {
        const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);

        const subscriptionId = tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true);
        const labVmId: string = tl.getInput('LabVmId', true);
        const vmName: string = resutil.getLabResourceName(labVmId, 'virtualmachines');

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId);

        await deleteVm(client, labVmId);

        tl.setResult(tl.TaskResult.Succeeded, `Lab VM '${vmName}' was successfully deleted.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

var args = require('minimist')(process.argv.slice(2));
if (args.test) {
    testRun();
}
else {
    run();
}