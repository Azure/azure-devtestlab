import '../../modules/task-utils/polyfill';

import fs from 'fs';

import * as tl from 'azure-pipelines-task-lib/task';
import * as deployutil from '../../modules/task-utils/deployutil';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { CreateEnvTaskInputData, TaskClients } from '../../modules/task-models/models';

import { Aborter, AnonymousCredential, BlobURL, Models, StorageURL } from "@azure/storage-blob";
import { DevTestLabsClient, DevTestLabsMappers, DevTestLabsModels } from "@azure/arm-devtestlabs";
import { ResourceManagementClient } from "@azure/arm-resources";
import { ResourcesGetByIdResponse } from '@azure/arm-resources/esm/models';

function getInputData(envName?: string, test?: boolean): CreateEnvTaskInputData {
    let inputData: CreateEnvTaskInputData;

    if (test) {
        const data: any = testutil.getTestData();
        const retryOnFailure: boolean = data.retryOnFailure ? Boolean(data.retryOnFailure) : false;

        inputData = {
            armTemplateId: data.armTemplateId,
            connectedServiceName: 'local',
            envName: envName ? envName : data.envName,
            envTemplateLocationVariable: data.envTemplateLocationVariable,
            envTemplateSasTokenVariable: data.envTemplateSasTokenVariable,
            exportEnvTemplate: data.exportEnvTemplate,
            exportEnvTemplateLocation: data.exportEnvTemplateLocation,
            labId: data.labId,
            outputTemplateVariables: data.outputTemplateVariables,
            parametersFile: data.parametersFile,
            parameterOverrides: data.parameterOverrides,
            subscriptionId: data.subscriptionId
        };
    } else {
        const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);

        inputData = {
            armTemplateId: tl.getInput('TemplateId', true),
            connectedServiceName: connectedServiceName,
            envName: tl.getInput('EnvironmentName', true),
            exportEnvTemplate: tl.getBoolInput('ExportEnvironmentTemplate'),
            exportEnvTemplateLocation: tl.getInput('ExportEnvironmentTemplateLocation'),
            envTemplateLocationVariable: tl.getInput('EnvironmentTemplateLocationVariable'),
            envTemplateSasTokenVariable: tl.getInput('EnvironmentTemplateSasTokenVariable'),
            labId: tl.getInput('LabId', true),
            outputTemplateVariables: tl.getBoolInput('OutputTemplateVariables'),
            parametersFile: tl.getInput('ParametersFile', false),
            parameterOverrides: tl.getInput('ParameterOverrides', false),
            subscriptionId: tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true)
        };
    }

    return inputData;
}

async function updateEnvironment(dtlClient: DevTestLabsClient, inputData: CreateEnvTaskInputData): Promise<any> {
    const labName = resutil.getLabResourceName(inputData.labId, 'labs');
    const labRgName = resutil.getLabResourceName(inputData.labId, 'resourcegroups');

    console.log(`Updating Environment '${inputData.envName}' in Lab '${labName}' under Resource Group '${labRgName}'.`);
/*
    const results = await dtlClient.environments.createOrUpdate(labRgName, labName, '@me', inputData.envName, env);
    if (results) {
        if (results.provisioningState !== 'Succeeded') {
            throw results._response.bodyAsText;
        }

        if (results.id) {
            tl.setVariable('environmentResourceId', results.id);
        }
        if (results.resourceGroupId) {
            tl.setVariable('environmentResourceGroupId', results.resourceGroupId);
        }
    }
*/
    console.log(`Finished updating Lab Environment '${inputData.envName}'.`);
}

function showInputData(inputData: CreateEnvTaskInputData): void {
    // console.log('Task called with the following parameters:');
    // console.log(`  ConnectedServiceName = ${inputData.connectedServiceName}`);
    // console.log(`  LabId = ${inputData.labId}`);
    // console.log(`  EnvironmentId = ${inputData.envId}`);
    // console.log(`  TemplateFile = ${inputData.templateFile}`);
    // console.log(`  EnvironmentName = ${inputData.envName}`);
    // console.log(`  ParametersFile = ${inputData.parametersFile}`);
    // console.log(`  OutputTemplateVariables = ${inputData.outputTemplateVariables}`);
    // console.log(`  ExportEnvironmentTemplate = ${inputData.exportEnvTemplate}`);
    // console.log(`  ExportEnvironmentTemplateLocation = ${inputData.exportEnvTemplateLocation}`);
    // console.log(`  EnvironmentTemplateLocationVariable = ${inputData.envTemplateLocationVariable}`);
    // console.log(`  EnvironmentTemplateSasTokenVariable = ${inputData.envTemplateSasTokenVariable}`);
}

async function run(envName?: string, test?: boolean) {
    try {
        console.log('Starting Azure DevTest Labs Create Environment Task');

        const inputData: CreateEnvTaskInputData = getInputData(envName, test);

        const clients: TaskClients = {
            arm: await resutil.getArmClient(inputData.subscriptionId, test),
            dtl: await resutil.getDtlClient(inputData.subscriptionId, test)
        };

        showInputData(inputData);

        await updateEnvironment(clients.dtl, inputData);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${inputData.envName}' was successfully created.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

var args = require('minimist')(process.argv.slice(2));
run(args.name, args.test);