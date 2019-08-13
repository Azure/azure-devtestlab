import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as deployutil from '../../modules/task-utils/deployutil';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { DevTestLabsClient, DevTestLabsMappers, DevTestLabsModels } from "@azure/arm-devtestlabs";
import { ResourceManagementClient } from "@azure/arm-resources";

async function getEnvironment(armTemplateId: string, parametersFile: string, parameterOverrides: string): Promise<DevTestLabsModels.DtlEnvironment> {
    let environment = Object.create(DevTestLabsMappers.DtlEnvironment);
    let environmentProperties = Object.create(DevTestLabsMappers.EnvironmentDeploymentProperties);

    environmentProperties.armTemplateId = armTemplateId;
    environmentProperties.parameters = await deployutil.getDeploymentParameters(parametersFile, parameterOverrides);

    environment.deploymentProperties = environmentProperties;

    return environment;
}

async function createEnvironment(client: DevTestLabsClient, armClient: ResourceManagementClient, labId: string, environmentName: string, armTemplateId: string, parametersFile: string, parameterOverrides: string): Promise<any> {
    const labName = resutil.getLabResourceName(labId, 'labs');
    const labRgName = resutil.getLabResourceName(labId, 'resourcegroups');
    const environment: DevTestLabsModels.DtlEnvironment = await getEnvironment(armTemplateId, parametersFile, parameterOverrides);

    console.log(`Creating Environment '${environmentName}' in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const results = await client.environments.createOrUpdate(labRgName, labName, '@me', environmentName, environment);
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

    console.log(`Finished creating Lab Environment '${environmentName}'.`);
}

async function testRun() {
    try {
        const data: any = await testutil.getTestData();

        const client: DevTestLabsClient = await resutil.getDtlClient(data.subscriptionId, true);
        const armClient: ResourceManagementClient = await resutil.getArmClient(data.subscriptionId, true);

        await createEnvironment(client, armClient, data.labId, data.envName, data.armTemplateId, data.parameterFile, data.parameterOverrides);

        const envRgId = tl.getVariable('environmentResourceGroupId');
        if (envRgId) {
            const envRgName = resutil.getResourceName(envRgId, 'resourcegroups');

            const deploymentOutput = await deployutil.getDeploymentOutput(armClient, envRgName);
            deploymentOutput.forEach((element: any[]) => {
                tl.setVariable(element[0], element[1], false);
            });

            // TODO: Store the template, if requested.
        }

        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${data.envName}' was successfully created.`);
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
        const labId: string = tl.getInput('LabId', false);
        const envName: string = tl.getInput('EnvironmentName', false);
        const armTemplateId: string = tl.getInput('TemplateId', false);
        const parametersFile: string = tl.getInput('ParametersFile', false)
        const parameterOverrides: string = tl.getInput('ParameterOverrides', false);

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId);
        const armClient: ResourceManagementClient = await resutil.getArmClient(subscriptionId);

        await createEnvironment(client, armClient, labId, envName, armTemplateId, parametersFile, parameterOverrides);

        const templateOutputVariables = tl.getBoolInput('TemplateOutputVariables');
        if (templateOutputVariables) {
            const envRgId = tl.getVariable('environmentResourceGroupId');
            if (envRgId) {
                const envRgName = resutil.getResourceName(envRgId, 'resourcegroups');
    
                const deploymentOutput = await deployutil.getDeploymentOutput(armClient, envRgName);
                deploymentOutput.forEach((element: any[]) => {
                    tl.setVariable(element[0], element[1], false);
                });
            }
        }

        const exportEnvironmentTemplate = tl.getBoolInput('ExportEnvironmentTemplate');
        if (exportEnvironmentTemplate) {
            const exportEnvironmentTemplateLocation: string = tl.getInput('ExportEnvironmentTemplateLocation');
            const environmentTemplateLocationVariable: string = tl.getInput('EnvironmentTemplateLocationVariable');
            const environmentTemplateSasTokenVariable: string = tl.getInput('EnvironmentTemplateSasTokenVariable');

            // TODO: Store the template, if requested.
        }

        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${envName}' was successfully created.`);
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