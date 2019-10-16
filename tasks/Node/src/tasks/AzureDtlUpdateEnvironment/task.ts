import '../../modules/task-utils/polyfill';
import { equalsIgnoreCase } from '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as deployutil from '../../modules/task-utils/deployutil';
import * as envutil from '../../modules/task-utils/envutil';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { CreateOrUpdateEnvTaskInputData, TaskClients } from '../../modules/task-models/models';

import { DevTestLabsModels } from "@azure/arm-devtestlabs";
import { ResourceManagementMappers, ResourceManagementModels } from '@azure/arm-resources';

function getDeploymentParameters(parametersFile: string, parameterOverrides: string): any {
    const parameters = {};

    const deploymentParameters: DevTestLabsModels.ArmTemplateParameterProperties[] = deployutil.getDeploymentParameters(parametersFile, parameterOverrides);

    deploymentParameters.forEach((p) => parameters[`${p.name}`] = { value: p.value });

    return parameters;
}

function getDeployment(templateFile: string, parametersFile: string, parameterOverrides: string): ResourceManagementModels.Deployment {
    const deployment = Object.create(ResourceManagementMappers.Deployment);
    const deploymentProperties = Object.create(ResourceManagementMappers.DeploymentProperties);

    deploymentProperties.mode = 'Incremental';
    deploymentProperties.template = deployutil.getDeploymentTemplate(templateFile);
    deploymentProperties.parameters = getDeploymentParameters(parametersFile, parameterOverrides);

    deployment.properties = deploymentProperties;

    return deployment;
}

function getInputData(envId?: string, test?: boolean): CreateOrUpdateEnvTaskInputData {
    let inputData: CreateOrUpdateEnvTaskInputData;

    if (test) {
        const data: any = testutil.getTestData();

        inputData = {
            connectedServiceName: 'local',
            envId: envId ? envId : data.envId,
            envName: '',
            envTemplateLocationVariable: data.envTemplateLocationVariable,
            envTemplateSasTokenVariable: data.envTemplateSasTokenVariable,
            exportEnvTemplate: data.exportEnvTemplate,
            exportEnvTemplateLocation: data.exportEnvTemplateLocation,
            labId: data.labId,
            outputTemplateVariables: data.outputTemplateVariables,
            parametersFile: data.parametersFile,
            parameterOverrides: data.parameterOverrides,
            subscriptionId: data.subscriptionId,
            templateFile: data.templateFile,
            templateId: ''
        };
    } else {
        const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);

        inputData = {
            connectedServiceName: connectedServiceName,
            envId: tl.getInput('EnvironmentId', true),
            envName: '',
            exportEnvTemplate: tl.getBoolInput('ExportEnvironmentTemplate'),
            exportEnvTemplateLocation: tl.getInput('ExportEnvironmentTemplateLocation'),
            envTemplateLocationVariable: tl.getInput('EnvironmentTemplateLocationVariable'),
            envTemplateSasTokenVariable: tl.getInput('EnvironmentTemplateSasTokenVariable'),
            labId: tl.getInput('LabId', true),
            outputTemplateVariables: tl.getBoolInput('OutputTemplateVariables'),
            parametersFile: tl.getInput('ParametersFile', false),
            parameterOverrides: tl.getInput('ParameterOverrides', false),
            subscriptionId: tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true),
            templateFile: tl.getInput('TemplateFile', true),
            templateId: ''
        };
    }

    return inputData;
}

async function updateEnvironment(clients: TaskClients, inputData: CreateOrUpdateEnvTaskInputData): Promise<void> {
    const labName: string = resutil.getLabResourceName(inputData.labId, 'labs');
    const labRgName: string = resutil.getLabResourceName(inputData.labId, 'resourcegroups');
    const envName: string = resutil.getLabResourceName(inputData.envId, 'environments');

    console.log(`Updating Environment '${envName}' in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const environments: DevTestLabsModels.EnvironmentsListResponse = await clients.dtl.environments.list(labRgName, labName, '@all');
    const env: DevTestLabsModels.DtlEnvironment | undefined = environments && environments.find((env) => env && env.name && equalsIgnoreCase(env.name, envName));

    if (!env) {
        throw `Lab Environment '${envName}' does not exist.`;
    }

    if (!env.resourceGroupId) {
        throw `Unable to determine property 'resourceGroupId' for Lab Environment '${envName}'.`;
    }

    const envRgName: string = resutil.getResourceName(env.resourceGroupId, 'resourcegroups');

    if (!envRgName) {
        throw `Unable to extract the name from Resource Group '${env.resourceGroupId}'.`;
    }

    const deploymentName: string = deployutil.getDeploymentName();
    const deployment: ResourceManagementModels.Deployment = getDeployment(inputData.templateFile, inputData.parametersFile, inputData.parameterOverrides);

    console.log('Invoking deployment with the following parameters:');
    console.log(`  DeploymentName = ${deploymentName}`);
    console.log(`  ResourceGroupName = ${envRgName}`);
    console.log(`  TemplateFile = ${inputData.templateFile}`);

    const results: ResourceManagementModels.DeploymentsCreateOrUpdateResponse = await clients.arm.deployments.createOrUpdate(envRgName, deploymentName, deployment);

    if (results && results.properties) {
        const properties: any = results.properties;

        if (properties.provisioningState !== 'Succeeded') {
            throw results._response.parsedBody;
        }

        tl.setVariable('environmentResourceId', inputData.envId);
        tl.setVariable('environmentResourceGroupId', env.resourceGroupId);
    }

    console.log(`Finished updating Lab Environment '${envName}'.`);
}

function showInputData(inputData: CreateOrUpdateEnvTaskInputData): void {
    console.log('Task called with the following parameters:');
    console.log(`  ConnectedServiceName = ${inputData.connectedServiceName}`);
    console.log(`  LabId = ${inputData.labId}`);
    console.log(`  EnvironmentId = ${inputData.envId}`);
    console.log(`  TemplateFile = ${inputData.templateFile}`);
    console.log(`  ParametersFile = ${inputData.parametersFile}`);
    console.log(`  OutputTemplateVariables = ${inputData.outputTemplateVariables}`);
    console.log(`  ExportEnvironmentTemplate = ${inputData.exportEnvTemplate}`);
    console.log(`  ExportEnvironmentTemplateLocation = ${inputData.exportEnvTemplateLocation}`);
    console.log(`  EnvironmentTemplateLocationVariable = ${inputData.envTemplateLocationVariable}`);
    console.log(`  EnvironmentTemplateSasTokenVariable = ${inputData.envTemplateSasTokenVariable}`);
}

async function run(envId?: string, test?: boolean): Promise<void> {
    try {
        console.log('Starting Azure DevTest Labs Update Environment Task');

        const inputData: CreateOrUpdateEnvTaskInputData = getInputData(envId, test);

        const clients: TaskClients = {
            arm: await resutil.getArmClient(inputData.subscriptionId, test),
            dtl: await resutil.getDtlClient(inputData.subscriptionId, test)
        };

        showInputData(inputData);

        await updateEnvironment(clients, inputData);

        const envRgId: string = tl.getVariable('environmentResourceGroupId');
        if (envRgId) {
            if (inputData.outputTemplateVariables) {
                const template: any = deployutil.getDeploymentTemplate(inputData.templateFile);
                await envutil.setOutputVariables(clients.arm, envRgId, template);
            }

            if (inputData.exportEnvTemplate) {
                const envTemplateLocation: string = tl.getVariable(inputData.envTemplateLocationVariable);
                const envTemplateSasToken: string = tl.getVariable(inputData.envTemplateSasTokenVariable);
                await envutil.exportEnvironmentTemplate(inputData.exportEnvTemplateLocation, envTemplateLocation, envTemplateSasToken);
            }
        }

        const envName: string = resutil.getLabResourceName(inputData.envId, 'environments');
        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${envName}' was successfully updated.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, error.message);
    }
}

const args = require('minimist')(process.argv.slice(2));
run(args.id, args.test);