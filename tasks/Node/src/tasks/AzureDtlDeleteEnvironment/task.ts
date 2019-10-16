import '../../modules/task-utils/polyfill';
import { equalsIgnoreCase } from '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { DevTestLabsClient } from "@azure/arm-devtestlabs";

async function ensureEnvExists(dtlClient: DevTestLabsClient, envId: string): Promise<void> {
    const labName: string = resutil.getLabResourceName(envId, 'labs');
    const labRgName: string = resutil.getLabResourceName(envId, 'resourcegroups');
    const envName: string = resutil.getLabResourceName(envId, 'environments');

    console.log(`Determining if Environment '${envName}' exists in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const environments = await dtlClient.environments.list(labRgName, labName, '@all');

    const envExists = environments && environments.some((env) => env && env.name && equalsIgnoreCase(env.name, envName));

    const message: string = `Lab Environment '${envName}' ${envExists ? 'exists' : 'does not exist'}.`;

    if (envExists) {
        console.log(message);
    }
    else {
        throw message;
    }
}

async function deleteEnv(dtlClient: DevTestLabsClient, envId: string): Promise<void> {
    const labName: string = resutil.getLabResourceName(envId, 'labs');
    const labRgName: string = resutil.getLabResourceName(envId, 'resourcegroups');
    const envName: string = resutil.getLabResourceName(envId, 'environments');

    await ensureEnvExists(dtlClient, envId);

    console.log(`Deleting Environment '${envName}' from Lab '${labName}' under Resource Group '${labRgName}'.`);

    const results = await dtlClient.environments.deleteMethod(labRgName, labName, '@me', envName);
    if (results) {
        const status = Object.keys(results._response.parsedBody);

        if (results._response.parsedBody[status[0]] != 'Succeeded') {
            throw results._response.parsedBody;
        }
    }

    console.log(`Finished deleting Lab Environment '${envName}'.`);
}

async function run(id?: string, test?: boolean): Promise<void> {
    try {
        console.log('Starting Azure DevTest Labs Delete Environment Task');

        let subscriptionId: string;
        let envId: string;

        if (test) {
            const data: any = testutil.getTestData();
            subscriptionId = data.subscriptionId;
            envId = id ? id : data.envId;
        } else {
            const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);
            subscriptionId = tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true);
            envId = tl.getInput('EnvironmentId', true);
        }

        const envName: string = resutil.getLabResourceName(envId, 'environments');

        const dtlClient: DevTestLabsClient = await resutil.getDtlClient(subscriptionId, test);

        await deleteEnv(dtlClient, envId);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${envName}' was successfully deleted.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

const args = require('minimist')(process.argv.slice(2));
run(args.id, args.test);