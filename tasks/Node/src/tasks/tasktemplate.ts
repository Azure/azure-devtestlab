import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as paramutil from '../../modules/task-utils/parameterutil';
import * as testutil from '../../modules/task-utils/testutil';

import { DevTestLabsClient, DevTestLabsMappers, DevTestLabsModels } from "@azure/arm-devtestlabs";
import { ResourceManagementClient } from "@azure/arm-resources";

async function performOperation(client: DevTestLabsClient): Promise<any> {
}

async function testRun() {
    try {
        const data: any = await testutil.getTestData();

        const client: DevTestLabsClient = await resutil.getDtlClient(data.subscriptionId, true);

        // TODO: add your call below.
        await performOperation(client);

        tl.setResult(tl.TaskResult.Succeeded, `Lab <resourceType> '${data.resourceName}' was successfully created.`);
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
        await performOperation(client);

        tl.setResult(tl.TaskResult.Succeeded, `Lab <resourceType> '${resourceName}' was successfully created.`);
    }
    catch (error) {
        tl.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

// Testing: node <path>/task.js --test
var args = require('minimist')(process.argv.slice(2));
if (args.test) {
    testRun();
}
else {
    run();
}