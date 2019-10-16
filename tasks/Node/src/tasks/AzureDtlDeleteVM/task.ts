import '../../modules/task-utils/polyfill';
import { equalsIgnoreCase } from '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { DevTestLabsClient } from "@azure/arm-devtestlabs";

async function ensureVmExists(dtlClient: DevTestLabsClient, labVmId: string): Promise<void> {
    const labName: string = resutil.getLabResourceName(labVmId, 'labs');
    const labRgName: string = resutil.getLabResourceName(labVmId, 'resourcegroups');
    const vmName: string = resutil.getLabResourceName(labVmId, 'virtualmachines');

    console.log(`Determining if VM '${vmName}' exists in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const labVms = await dtlClient.virtualMachines.list(labRgName, labName);

    const vmExists = labVms && labVms.some((vm) => vm && vm.name && equalsIgnoreCase(vm.name, vmName));

    const message: string = `Lab VM '${vmName}' ${vmExists ? 'exists' : 'does not exist'}.`;

    if (vmExists) {
        console.log(message);
    }
    else {
        throw message;
    }
}

async function deleteVm(dtlClient: DevTestLabsClient, labVmId: string): Promise<void> {
    const labName = resutil.getLabResourceName(labVmId, 'labs');
    const labRgName = resutil.getLabResourceName(labVmId, 'resourcegroups');
    const vmName = resutil.getLabResourceName(labVmId, 'virtualmachines');

    await ensureVmExists(dtlClient, labVmId);

    console.log(`Deleting VM '${vmName}' from Lab '${labName}' under Resource Group '${labRgName}'.`);

    const results = await dtlClient.virtualMachines.deleteMethod(labRgName, labName, vmName);
    if (results) {
        const status = Object.keys(results._response.parsedBody);

        if (results._response.parsedBody[status[0]] != 'Succeeded') {
            throw results._response.parsedBody;
        }
    }

    console.log(`Finished deleting Lab VM '${vmName}'.`);
}

async function run(id?: string, test?: boolean): Promise<void> {
    try {
        console.log('Starting Azure DevTest Labs Delete VM Task');

        let subscriptionId: string;
        let labVmId: string;

        if (test) {
            const data: any = testutil.getTestData();
            subscriptionId = data.subscriptionId;
            labVmId = id ? id : data.labVmId;
        } else {
            const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);
            subscriptionId = tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true);
            labVmId = tl.getInput('LabVmId', true);
        }

        const vmName: string = resutil.getLabResourceName(labVmId, 'virtualmachines');

        const dtlClient: DevTestLabsClient = await resutil.getDtlClient(subscriptionId, test);

        await deleteVm(dtlClient, labVmId);

        tl.setResult(tl.TaskResult.Succeeded, `Lab VM '${vmName}' was successfully deleted.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

const args = require('minimist')(process.argv.slice(2));
run(args.id, args.test);