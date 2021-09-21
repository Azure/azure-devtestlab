import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as deployutil from '../../modules/task-utils/deployutil';
import * as envutil from '../../modules/task-utils/envutil';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { CreateOrUpdateEnvTaskInputData, TaskClients } from '../../modules/task-models/models';

import { DevTestLabsClient, DevTestLabsMappers, DevTestLabsModels } from "@azure/arm-devtestlabs";
import { ResourcesGetByIdResponse } from '@azure/arm-resources/esm/models';

async function createEnvironment(dtlClient: DevTestLabsClient, inputData: CreateOrUpdateEnvTaskInputData): Promise<void> {
    const labName: string = resutil.getLabResourceName(inputData.labId, 'labs');
    const labRgName: string = resutil.getLabResourceName(inputData.labId, 'resourcegroups');
    const env: DevTestLabsModels.DtlEnvironment = getEnvironment(inputData.templateId, inputData.parametersFile, inputData.parameterOverrides);

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

function getEnvironment(templateId: string, parametersFile: string, parameterOverrides: string): DevTestLabsModels.DtlEnvironment {
    const environment = Object.create(DevTestLabsMappers.DtlEnvironment);
    const environmentProperties = Object.create(DevTestLabsMappers.EnvironmentDeploymentProperties);

    environmentProperties.armTemplateId = templateId;
    environmentProperties.parameters = deployutil.getDeploymentParameters(parametersFile, parameterOverrides);

    environment.deploymentProperties = environmentProperties;

    return environment;
}

function getInputData(envName?: string, test?: boolean): CreateOrUpdateEnvTaskInputData {
    let inputData: CreateOrUpdateEnvTaskInputData;

    if (test) {
        const data: any = testutil.getTestData();

        inputData = {
            connectedServiceName: 'local',
            envId: '',
            envName: envName ? envName : data.envName,
            envTemplateLocationVariable: data.envTemplateLocationVariable,
            envTemplateSasTokenVariable: data.envTemplateSasTokenVariable,
            exportEnvTemplate: data.exportEnvTemplate,
            exportEnvTemplateLocation: data.exportEnvTemplateLocation,
            labId: data.labId,
            outputTemplateVariables: data.outputTemplateVariables,
            parametersFile: data.parametersFile,
            parameterOverrides: data.parameterOverrides,
            subscriptionId: data.subscriptionId,
            templateFile: '',
            templateId: data.templateId
        };
    } else {
        const connectedServiceName: string = String(tl.getInput('ConnectedServiceName', true));

        inputData = {
            connectedServiceName: connectedServiceName,
            envId: '',
            envName: String(tl.getInput('EnvironmentName', true)),
            exportEnvTemplate: tl.getBoolInput('ExportEnvironmentTemplate'),
            exportEnvTemplateLocation: String(tl.getInput('ExportEnvironmentTemplateLocation')),
            envTemplateLocationVariable: String(tl.getInput('EnvironmentTemplateLocationVariable')),
            envTemplateSasTokenVariable: String(tl.getInput('EnvironmentTemplateSasTokenVariable')),
            labId: String(tl.getInput('LabId', true)),
            outputTemplateVariables: tl.getBoolInput('OutputTemplateVariables'),
            parametersFile: String(tl.getInput('ParametersFile', false)),
            parameterOverrides: String(tl.getInput('ParameterOverrides', false)),
            subscriptionId: String(tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true)),
            templateFile: '',
            templateId: String(tl.getInput('TemplateId', true))
        };
    }

    return inputData;
}

function showInputData(inputData: CreateOrUpdateEnvTaskInputData): void {
    console.log('Task called with the following parameters:');
    console.log(`  ConnectedServiceName = ${inputData.connectedServiceName}`);
    console.log(`  LabId = ${inputData.labId}`);
    console.log(`  EnvironmentName = ${inputData.envName}`);
    console.log(`  TemplateId = ${inputData.templateId}`);
    console.log(`  ParametersFile = ${inputData.parametersFile}`);
    console.log(`  OutputTemplateVariables = ${inputData.outputTemplateVariables}`);
    console.log(`  ExportEnvironmentTemplate = ${inputData.exportEnvTemplate}`);
    console.log(`  ExportEnvironmentTemplateLocation = ${inputData.exportEnvTemplateLocation}`);
    console.log(`  EnvironmentTemplateLocationVariable = ${inputData.envTemplateLocationVariable}`);
    console.log(`  EnvironmentTemplateSasTokenVariable = ${inputData.envTemplateSasTokenVariable}`);
}

async function run(envName?: string, test?: boolean): Promise<void> {
    try {
        console.log('Starting Azure DevTest Labs Create Environment Task');

        const inputData: CreateOrUpdateEnvTaskInputData = getInputData(envName, test);

        const clients: TaskClients = {
            arm: await resutil.getArmClient(inputData.subscriptionId, test),
            dtl: await resutil.getDtlClient(inputData.subscriptionId, test)
        };

        showInputData(inputData);

        await createEnvironment(clients.dtl, inputData);

        const envRgId: string = String(tl.getVariable('environmentResourceGroupId'));
        if (envRgId) {
            if (inputData.outputTemplateVariables) {
                const response: ResourcesGetByIdResponse = await clients.arm.resources.getById(inputData.templateId, '2016-05-15');
                await envutil.setOutputVariables(clients.arm, envRgId, response._response.parsedBody);
            }

            if (inputData.exportEnvTemplate) {
                const envTemplateLocation: string = String(tl.getVariable(inputData.envTemplateLocationVariable));
                const envTemplateSasToken: string = String(tl.getVariable(inputData.envTemplateSasTokenVariable));
                await envutil.exportEnvironmentTemplate(inputData.exportEnvTemplateLocation, envTemplateLocation, envTemplateSasToken);
            }
        }

        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${inputData.envName}' was successfully created.`);
    }
    catch (error:any) {
        console.debug(JSON.stringify(error, null, 2));
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

const args = require('minimist')(process.argv.slice(2));
run(args.name, args.test);