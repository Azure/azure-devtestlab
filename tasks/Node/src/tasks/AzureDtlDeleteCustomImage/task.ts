import '../../modules/task-utils/polyfill';
import { equalsIgnoreCase } from '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { DevTestLabsClient } from "@azure/arm-devtestlabs";

async function ensureCiExists(dtlClient: DevTestLabsClient, ciId: string): Promise<void> {
    const labName: string = resutil.getLabResourceName(ciId, 'labs');
    const labRgName: string = resutil.getLabResourceName(ciId, 'resourcegroups');
    const ciName: string = resutil.getLabResourceName(ciId, 'customimages');

    console.log(`Determining if Custom Image '${ciName}' exists in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const customImages = await dtlClient.customImages.list(labRgName, labName);

    const ciExists = customImages && customImages.some((ci) => ci && ci.name && equalsIgnoreCase(ci.name, ciName));

    const message: string = `Lab Custom Image '${ciName}' ${ciExists ? 'exists' : 'does not exist'}.`;

    if (ciExists) {
        console.log(message);
    }
    else {
        throw message;
    }
}

async function deleteCi(dtlClient: DevTestLabsClient, ciId: string): Promise<void> {
    const labName: string = resutil.getLabResourceName(ciId, 'labs');
    const labRgName: string = resutil.getLabResourceName(ciId, 'resourcegroups');
    const ciName: string = resutil.getLabResourceName(ciId, 'customimages');

    await ensureCiExists(dtlClient, ciId);

    console.log(`Deleting Custom Image '${ciName}' from Lab '${labName}' under Resource Group '${labRgName}'.`);

    const results = await dtlClient.customImages.deleteMethod(labRgName, labName, ciName);
    if (results) {
        const status = Object.keys(results._response.parsedBody);

        if (results._response.parsedBody[status[0]] != 'Succeeded') {
            throw results._response.parsedBody;
        }
    }

    console.log(`Finished deleting Lab Custom Image '${ciName}'.`);
}

async function run(id?: string, test?: boolean): Promise<void> {
    try {
        console.log('Starting Azure DevTest Labs Delete Custom Image Task');

        let subscriptionId: string;
        let ciId: string;

        if (test) {
            const data: any = testutil.getTestData();
            subscriptionId = data.subscriptionId;
            ciId = id ? id : data.ciId;
        } else {
            const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);
            subscriptionId = tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true);
            ciId = tl.getInput('CustomImageId', true);
        }

        const ciName: string = resutil.getLabResourceName(ciId, 'customimages');

        const dtlClient: DevTestLabsClient = await resutil.getDtlClient(subscriptionId, test);

        await deleteCi(dtlClient, ciId);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Custom Image '${ciName}' was successfully deleted.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

const args = require('minimist')(process.argv.slice(2));
run(args.id, args.test);