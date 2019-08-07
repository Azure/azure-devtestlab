import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as paramutil from '../../modules/task-utils/parameterutil';

import { DevTestLabsClient, DevTestLabsMappers, DevTestLabsModels } from "@azure/arm-devtestlabs";
import { ResourceManagementClient } from "@azure/arm-resources";
/*
async function createVm(client: DevTestLabsClient, labId: string): Promise<any> {
    let labName = resutil.getLabResourceName(labId, 'labs');
    let labRgName = resutil.getLabResourceName(labId, 'resourcegroups');
    let customImage: DevTestLabsModels.CustomImage = getCustomImage(sourceVmId, author, description, osType, linuxOsState, windowsOsState);

    console.log(`Creating Custom Image '${customImageName}' in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const results = await client.customImages.createOrUpdate(labRgName, labName, customImageName, customImage);
    if (results) {
        if (results.provisioningState !== 'Succeeded') {
            throw results._response.bodyAsText;
        }

        const customImageId: string = results.id ? results.id : 'undefined';
        tl.setVariable('customImageId', customImageId);
    }

    console.log(`Finished creating Lab Custom Image '${customImageName}'.`);
}

async function testRun() {
    try {
        const subscriptionId = '<subscriptionId>';
        const resourceName = '<resourceName>';

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId, true);

        // TODO: add your call below.
        await createVm(client);

        tl.setResult(tl.TaskResult.Succeeded, `Lab <resourceType> '${resourceName}' was successfully created.`);
    }
    catch (error) {
        tl.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

async function run() {
    try {
        const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);

        const subscriptionId: string = tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true);
        const resourceName = '<resourceName>';

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId);

        // TODO: add your call below.
        //await createVm(client);

        tl.setResult(tl.TaskResult.Succeeded, `Lab <resourceType> '${resourceName}' was successfully created.`);
    }
    catch (error) {
        tl.debug(error);
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

*/