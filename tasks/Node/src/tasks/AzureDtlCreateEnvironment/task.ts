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

async function createEnvironment(dtlClient: DevTestLabsClient, inputData: CreateEnvTaskInputData): Promise<any> {
    const labName = resutil.getLabResourceName(inputData.labId, 'labs');
    const labRgName = resutil.getLabResourceName(inputData.labId, 'resourcegroups');
    const env: DevTestLabsModels.DtlEnvironment = getEnvironment(inputData.armTemplateId, inputData.parametersFile, inputData.parameterOverrides);

    console.log(`Creating Environment '${inputData.envName}' in Lab '${labName}' under Resource Group '${labRgName}'.`);

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

    console.log(`Finished creating Lab Environment '${inputData.envName}'.`);
}

async function exportEnvironmentTemplate(exportEnvTemplateLocation: string, envTemplateLocation: string, envTemplateSasToken: string): Promise<any> {
    if (!envTemplateLocation || !envTemplateSasToken) {
        throw 'Missing Environment Location or Environment SAS Token as outputs variables.';
    }

    console.log('Exporting environment template.');

    const templateFileName = 'azuredeploy.json';
    const credential = new AnonymousCredential();
    const pipeline = StorageURL.newPipeline(credential);

    const blobUrl = new BlobURL(`${envTemplateLocation}/${templateFileName}${envTemplateSasToken}`, pipeline);
    const response: Models.BlobDownloadResponse = await blobUrl.download(Aborter.none, 0);

    if (response && response.readableStreamBody) {
        tl.mkdirP(exportEnvTemplateLocation);
        const templateFileLocation = `${exportEnvTemplateLocation}/${templateFileName}`;
        const data: string = response.readableStreamBody.read().toString();
        fs.writeFileSync(templateFileLocation, data, 'utf8');
        console.log(`Environment template has been exported to file: ${templateFileLocation}`);
    }
    
    console.log('Environment template has been exported successfully.');
}

function getEnvironment(armTemplateId: string, parametersFile: string, parameterOverrides: string): DevTestLabsModels.DtlEnvironment {
    let environment = Object.create(DevTestLabsMappers.DtlEnvironment);
    let environmentProperties = Object.create(DevTestLabsMappers.EnvironmentDeploymentProperties);

    environmentProperties.armTemplateId = armTemplateId;
    environmentProperties.parameters = deployutil.getDeploymentParameters(parametersFile, parameterOverrides);

    environment.deploymentProperties = environmentProperties;

    return environment;
}

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

async function setOutputVariables(armClient: ResourceManagementClient, envRgId: string, armTemplateId: string): Promise<any> {
    const template: ResourcesGetByIdResponse = await armClient.resources.getById(armTemplateId, '2016-05-15');
    const templateProperties: any = template._response.parsedBody.properties;
    if (templateProperties && templateProperties.contents && templateProperties.contents.outputs) {
        const envRgName = resutil.getResourceName(envRgId, 'resourcegroups');
        const templateOutputs: any = templateProperties.contents.outputs;
        const deploymentOutput = await deployutil.getDeploymentOutput(armClient, envRgName);
        deploymentOutput.forEach((element: any[]) => {
            const name: string = element[0];
            const value: string = element[1];
            const key = Object.keys(templateOutputs).find(key => key.toLowerCase() === name.toLowerCase());
            if (key) {
                const type: string = templateOutputs[key].type;
                if (type) {
                    const secret: boolean = type.toLowerCase().indexOf('secure') !== -1;
                    tl.setVariable(name, value, secret);
                }
            }
        });
    }
}

function showInputData(inputData: CreateEnvTaskInputData): void {
    console.log('Task called with the following parameters:');
    console.log(`  ConnectedServiceName = ${inputData.connectedServiceName}`);
    console.log(`  LabId = ${inputData.labId}`);
    console.log(`  TemplateId = ${inputData.armTemplateId}`);
    console.log(`  EnvironmentName = ${inputData.envName}`);
    console.log(`  ParametersFile = ${inputData.parametersFile}`);
    console.log(`  OutputTemplateVariables = ${inputData.outputTemplateVariables}`);
    console.log(`  ExportEnvironmentTemplate = ${inputData.exportEnvTemplate}`);
    console.log(`  ExportEnvironmentTemplateLocation = ${inputData.exportEnvTemplateLocation}`);
    console.log(`  EnvironmentTemplateLocationVariable = ${inputData.envTemplateLocationVariable}`);
    console.log(`  EnvironmentTemplateSasTokenVariable = ${inputData.envTemplateSasTokenVariable}`);
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

        await createEnvironment(clients.dtl, inputData);

        const envRgId = tl.getVariable('environmentResourceGroupId');
        if (envRgId) {
            if (inputData.outputTemplateVariables) {
                await setOutputVariables(clients.arm, envRgId, inputData.armTemplateId);
            }

            if (inputData.exportEnvTemplate) {
                const envTemplateLocation: string = tl.getVariable(inputData.envTemplateLocationVariable);
                const envTemplateSasToken: string = tl.getVariable(inputData.envTemplateSasTokenVariable);
                await exportEnvironmentTemplate(inputData.exportEnvTemplateLocation, envTemplateLocation, envTemplateSasToken);
            }
        }

        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${inputData.envName}' was successfully created.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

var args = require('minimist')(process.argv.slice(2));
run(args.envName, args.test);