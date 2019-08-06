import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as paramutil from '../../modules/task-utils/parameterutil';

import { DevTestLabsClient, DevTestLabsMappers, DevTestLabsModels } from "@azure/arm-devtestlabs";
import { ResourceManagementClient } from "@azure/arm-resources";

async function getEnvironment(armTemplateId: string, parametersFile: string, parameterOverrides: string): Promise<DevTestLabsModels.DtlEnvironment> {
    let environment = Object.create(DevTestLabsMappers.DtlEnvironment);
    let deploymentProperties = Object.create(DevTestLabsMappers.EnvironmentDeploymentProperties);

    deploymentProperties.armTemplateId = armTemplateId;
    deploymentProperties.parameters = await paramutil.getDeploymentParameters(parametersFile, parameterOverrides);

    environment.deploymentProperties = deploymentProperties;

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

        const environmentResourceId: string = results.id ? results.id : 'undefined';
        const environmentResourceGroupId: string = results.resourceGroupId ? results.resourceGroupId : 'undefined';
        tl.setVariable('environmentResourceId', environmentResourceId);
        tl.setVariable('environmentResourceGroupId', environmentResourceGroupId);
    }

    console.log(`Finished creating Lab Environment '${environmentName}'.`);
}

async function testRun(envName: string = 'lv-env-1') {
    try {
        const subscriptionId = 'e605a3bc-ee4e-4c7a-9709-1868a28b1d4d';
        const labId = '/subscriptions/e605a3bc-ee4e-4c7a-9709-1868a28b1d4d/resourcegroups/lv-rg-sandbox/providers/microsoft.devtestlab/labs/lv-lab-sandbox';
        //const armTemplateId = '/subscriptions/e605a3bc-ee4e-4c7a-9709-1868a28b1d4d/resourceGroups/lv-rg-sandbox/providers/Microsoft.DevTestLab/labs/lv-lab-sandbox/artifactSources/public environment repo/armTemplates/WebApp';
        const armTemplateId = '/subscriptions/e605a3bc-ee4e-4c7a-9709-1868a28b1d4d/resourceGroups/lv-rg-sandbox/providers/Microsoft.DevTestLab/labs/lv-lab-sandbox/artifactSources/privaterepo523/armTemplates/rbest-template';
        const parameterFile = '';
        const parameterOverrides = '';

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId, true);
        const armClient: ResourceManagementClient = await resutil.getArmClient(subscriptionId, true);

        //await createEnvironment(client, armClient, labId, envName, armTemplateId, parameterFile, parameterOverrides);

        const envRgId = '/subscriptions/e605a3bc-ee4e-4c7a-9709-1868a28b1d4d/resourcegroups/lv-lab-sandbox-lv-env-3-153680'; // tl.getVariable('environmentResourceGroupId'); //'/subscriptions/e605a3bc-ee4e-4c7a-9709-1868a28b1d4d/resourcegroups/lv-lab-sandbox-lv-env-1-940652'
        if (envRgId) {
            //console.log(envRgId);
            const envRgName = resutil.getResourceName(envRgId, 'resourcegroups');

            const deploymentOutput = await resutil.getDeploymentOutput(armClient, envRgName);
            deploymentOutput.forEach((element: any[]) => {
                tl.setVariable(element[0], element[1], false);
            });

            // TODO: Store the template, if requested.
        }

        tl.setResult(tl.TaskResult.Succeeded, `Lab Environment '${envName}' was successfully created.`);
    }
    catch (error) {
        console.log(error);
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
        const parameterFile: string = tl.getInput('ParameterFile', false)
        const parameterOverrides: string = tl.getInput('ParameterOverrides', false);

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId);
        const armClient: ResourceManagementClient = await resutil.getArmClient(subscriptionId);

        await createEnvironment(client, armClient, labId, envName, armTemplateId, parameterFile, parameterOverrides);

        const templateOutputVariables = tl.getBoolInput('TemplateOutputVariables');
        if (templateOutputVariables) {
            const envRgId = tl.getVariable('environmentResourceGroupId');
            if (envRgId) {
                const envRgName = resutil.getResourceName(envRgId, 'resourcegroups');
    
                const deploymentOutput = await resutil.getDeploymentOutput(armClient, envRgName);
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
    testRun(args.envName);
}
else {
    run();
}