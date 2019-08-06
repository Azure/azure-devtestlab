import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';

import { DevTestLabsClient, DevTestLabsModels, DevTestLabsMappers } from '@azure/arm-devtestlabs';

function getCustomImageProperties(sourceVmId: string, osType: string, linuxOsState: string, windowsOsState: string): DevTestLabsModels.CustomImagePropertiesFromVm {
    let properties = Object.create(DevTestLabsMappers.CustomImagePropertiesFromVm);
    properties.sourceVmId = sourceVmId;

    switch (osType) {
        case 'Linux':
            let linuxOsInfo: DevTestLabsModels.LinuxOsInfo = Object.create(DevTestLabsMappers.LinuxOsInfo);
            switch (linuxOsState) {
                case ('NonDeprovisioned'):
                    linuxOsInfo.linuxOsState = "NonDeprovisioned";
                    break;
                case ('DeprovisionRequested'):
                    linuxOsInfo.linuxOsState = "DeprovisionRequested";
                    break;
                case ('DeprovisionApplied'):
                    linuxOsInfo.linuxOsState = "DeprovisionApplied";
                    break;
                default:
                    throw `Invalid Linux OS State: ${linuxOsState ? linuxOsState : 'undefined'}. Expecting on of 'NonDeprovisioned' or 'DeprovisionRequested' or 'DeprovisionApplied'.`;
            }
            properties.linuxOsInfo = linuxOsInfo;
            break;
        case 'Windows':
            let windowsOsInfo: DevTestLabsModels.WindowsOsInfo = Object.create(DevTestLabsMappers.WindowsOsInfo);

            switch (windowsOsState) {
                case ('SysprepRequested'):
                    windowsOsInfo.windowsOsState = "SysprepRequested";
                    break;
                case ('NonSysprepped'):
                    windowsOsInfo.windowsOsState = "NonSysprepped";
                    break;
                case ('SysprepApplied'):
                    windowsOsInfo.windowsOsState = "SysprepApplied";
                    break;
                default:
                    throw `Invalid Windows OS State: ${windowsOsState ? windowsOsState : 'undefined'}. Expecting one of 'SysprepRequested' or 'NonSysprepped' or 'SysprepApplied'.`;
            }
            properties.windowsOsInfo = windowsOsInfo;
            break;
        default:
            throw `Invalid OS Type: ${osType ? osType : 'undefined'}. Expecting one of 'Linux' or 'Windows'.`;
    }

    return properties;
}

function getCustomImage(sourceVmId: string, author: string, description: string, osType: string, linuxOsState: string, windowsOsState: string): DevTestLabsModels.CustomImage {
    let customImage: DevTestLabsModels.CustomImage = Object.create(DevTestLabsMappers.CustomImage);

    customImage.vm = getCustomImageProperties(sourceVmId, osType, linuxOsState, windowsOsState);
    customImage.description = description;
    customImage.author = author;

    return customImage;
}

async function createCustomImage(client: DevTestLabsClient, labId: string, sourceVmId: string, customImageName: string, author: string, description: string, osType: string, linuxOsState: string, windowsOsState: string): Promise<any> {
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
        const subscriptionId = 'e605a3bc-ee4e-4c7a-9709-1868a28b1d4d';
        const labId = '/subscriptions/e605a3bc-ee4e-4c7a-9709-1868a28b1d4d/resourcegroups/lv-rg-sandbox/providers/microsoft.devtestlab/labs/lv-lab-sandbox';
        const labVmId = '/subscriptions/e605a3bc-ee4e-4c7a-9709-1868a28b1d4d/resourcegroups/lv-rg-sandbox/providers/microsoft.devtestlab/labs/lv-lab-sandbox/virtualmachines/leov001';
        const customImageName = 'lv-ci-fromtask3';
        const author = 'leov@microsoft.com';
        const description = `Custom image created from local task tests requested for ${author}.`;
        const osType = 'Windows';
        const linuxOsState = 'NonDeprovisioned';
        const windowsOsState = 'NonSysprepped';

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId, true);

        await createCustomImage(client, labId, labVmId, customImageName, author, description, osType, linuxOsState, windowsOsState);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Custom Image '${customImageName}' was successfully created.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

async function run() {
    try {
        const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);

        const subscriptionId: string = tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true);
        const labId: string = tl.getInput('LabId', true);
        const labVmId: string = tl.getInput('LabVMId', false);
        const customImageName: string = tl.getInput('NewCustomImageName', false);
        const osType: string = tl.getInput('OSType', false)
        const linuxOsState: string = tl.getInput('LinuxOsState', false);
        const windowsOsState: string = tl.getInput('WindowsOsState', false);

        let author = process.env.RELEASE_RELEASENAME;
        let authorType = 'release';
        if (!author) {
            author = process.env.BUILD_BUILDNUMBER;
            authorType = 'build';
        }
        if (!author) {
            author = '';
            authorType = 'unknown';
        }
        let requestedFor = process.env.RELEASE_REQUESTEDFOR;
        if (!requestedFor) {
            requestedFor = process.env.BUILD_REQUESTEDFOR;
        }
        let description = tl.getInput('Description', false);
        if (!description) {
            description = `Custom image created from ${authorType} ${author} requested for ${requestedFor}.`;
        }

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId);

        await createCustomImage(client, labId, labVmId, customImageName, author, description, osType, linuxOsState, windowsOsState);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Custom Image '${customImageName}' was successfully created.`);
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