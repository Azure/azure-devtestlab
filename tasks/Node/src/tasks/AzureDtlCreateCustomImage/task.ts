import '../../modules/task-utils/polyfill';
import { equalsIgnoreCase } from '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { CreateCiTaskInputData } from '../../modules/task-models/models';

import { DevTestLabsClient, DevTestLabsModels, DevTestLabsMappers } from '@azure/arm-devtestlabs';

async function createCustomImage(dtlClient: DevTestLabsClient, inputData: CreateCiTaskInputData): Promise<void> {
    const labName: string = resutil.getLabResourceName(inputData.labId, 'labs');
    const labRgName: string = resutil.getLabResourceName(inputData.labId, 'resourcegroups');
    const customImage: DevTestLabsModels.CustomImage = getCustomImage(inputData);

    console.log(`Creating Custom Image '${inputData.ciName}' in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const results = await dtlClient.customImages.createOrUpdate(labRgName, labName, inputData.ciName, customImage);
    if (results) {
        if (results.provisioningState !== 'Succeeded') {
            throw results._response.bodyAsText;
        }

        if (results.id) {
            tl.setVariable('customImageId', results.id);
        }
    }

    console.log(`Finished creating Lab Custom Image '${inputData.ciName}'.`);
}

function getCustomImageProperties(sourceVmId: string, osType: string, linuxOsState: string, windowsOsState: string): DevTestLabsModels.CustomImagePropertiesFromVm {
    const properties = Object.create(DevTestLabsMappers.CustomImagePropertiesFromVm);
    properties.sourceVmId = sourceVmId;

    switch (osType) {
        case 'Linux':
            const linuxOsInfo: DevTestLabsModels.LinuxOsInfo = Object.create(DevTestLabsMappers.LinuxOsInfo);
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
            const windowsOsInfo: DevTestLabsModels.WindowsOsInfo = Object.create(DevTestLabsMappers.WindowsOsInfo);

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

function getCustomImage(inputData: CreateCiTaskInputData): DevTestLabsModels.CustomImage {
    const customImage: DevTestLabsModels.CustomImage = Object.create(DevTestLabsMappers.CustomImage);

    customImage.vm = getCustomImageProperties(inputData.labVmId, inputData.osType, inputData.linuxOsState, inputData.windowsOsState);
    customImage.description = inputData.description;
    customImage.author = inputData.author;

    return customImage;
}

function getInputData(ciName?: string, test?: boolean): CreateCiTaskInputData {
    let inputData: CreateCiTaskInputData;

    if (test) {
        const data: any = testutil.getTestData();

        inputData = {
            author: data.author ? data.author : 'local',
            ciName: ciName ? ciName : data.ciName,
            connectedServiceName: 'local',
            description: data.description ? data.description : 'Custom image created from local task tests.',
            labId: data.labId,
            labVmId: data.labVmId,
            linuxOsState: data.linuxOsState,
            osType: data.osType,
            subscriptionId: data.subscriptionId,
            windowsOsState: data.windowsOsState
        };
    } else {
        const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);
        const osType: string = tl.getInput('OSType', true)

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

        inputData = {
            author: author,
            ciName: tl.getInput('NewCustomImageName', true),
            connectedServiceName: connectedServiceName,
            description: description,
            labId: tl.getInput('LabId', true),
            labVmId: tl.getInput('LabVmId', true),
            linuxOsState: tl.getInput('LinuxOsState', equalsIgnoreCase(osType, 'Linux')),
            osType: osType,
            subscriptionId: tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true),
            windowsOsState: tl.getInput('WindowsOsState', equalsIgnoreCase(osType, 'Windows'))
        };
    }

    return inputData;
}

function showInputData(inputData: CreateCiTaskInputData): void {
    console.log('Task called with the following parameters:');
    console.log(`  ConnectedServiceName = ${inputData.connectedServiceName}`);
    console.log(`  LabId = ${inputData.labId}`);
    console.log(`  NewCustomImageName = ${inputData.ciName}`);
    console.log(`  Description = ${inputData.description}`);
    console.log(`  SourceLabVmId = ${inputData.labVmId}`);
    console.log(`  OsType = ${inputData.osType}`);
    console.log(`  LinuxOsState = ${inputData.linuxOsState}`);
    console.log(`  WindowsOsState = ${inputData.windowsOsState}`);
}

async function run(ciName?: string, test?: boolean): Promise<void> {
    try {
        console.log('Starting Azure DevTest Labs Create Custom Image Task');

        const inputData: CreateCiTaskInputData = getInputData(ciName, test);

        const dtlClient: DevTestLabsClient = await resutil.getDtlClient(inputData.subscriptionId, test);

        showInputData(inputData);

        await createCustomImage(dtlClient, inputData);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Custom Image '${inputData.ciName}' was successfully created.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

const args = require('minimist')(process.argv.slice(2));
run(args.name, args.test);