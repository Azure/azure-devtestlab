import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';

import { DevTestLabsClient } from "@azure/arm-devtestlabs";

async function ensureEnvExists(client: DevTestLabsClient, envId: string): Promise<any> {
    let labName: string = resutil.getLabResourceName(envId, 'labs');
    let labRgName: string = resutil.getLabResourceName(envId, 'resourcegroups');
    let envName: string = resutil.getLabResourceName(envId, 'environments');

    console.log(`Determining if Environment '${envName}' exists in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const environments = await client.environments.list(labRgName, labName, '@all');

    var envExists = environments && environments.some((env) => {
        if (env && env.name) {
            return env.name.toLocaleLowerCase() === envName;
        }
    });

    const message: string = `Lab Environment '${envName}' ${envExists ? 'exists' : 'does not exist'}.`;

    if (envExists) {
        console.log(message);
    }
    else {
        throw message;
    }
}

async function deleteEnv(client: DevTestLabsClient, envId: string): Promise<any> {
    let labName: string = resutil.getLabResourceName(envId, 'labs');
    let labRgName: string = resutil.getLabResourceName(envId, 'resourcegroups');
    let envName: string = resutil.getLabResourceName(envId, 'environments');

    await ensureEnvExists(client, envId);

    console.log(`Deleting Environment '${envName}' from Lab '${labName}' under Resource Group '${labRgName}'.`);

    const results = await client.environments.deleteMethod(labRgName, labName, '@me', envName);
    if (results) {
        var status = Object.keys(results._response.parsedBody);

        if (results._response.parsedBody[status[0]] != 'Succeeded') {
            throw results._response.parsedBody;
        }
    }

    console.log(`Finished deleting Lab Environment '${envName}'.`);
}

async function testRun() {
    try {
        const subscriptionId = 'e605a3bc-ee4e-4c7a-9709-1868a28b1d4d';
        const envId = '/subscriptions/e605a3bc-ee4e-4c7a-9709-1868a28b1d4d/resourcegroups/lv-rg-sandbox/providers/microsoft.devtestlab/labs/lv-lab-sandbox/users/6b4e8735-3c05-43f9-8137-2e66c5c4bb87/environments/lv-env-1';
        const envName: string = resutil.getLabResourceName(envId, 'environments');

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId, true);

        await deleteEnv(client, envId);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${envName}' was successfully deleted.`);
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
        const envId: string = tl.getInput('EnvironmentId', true);
        const envName: string = resutil.getLabResourceName(envId, 'environments');

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId);

        await deleteEnv(client, envId);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${envName}' was successfully deleted.`);
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