import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as deployutil from '../../modules/task-utils/deployutil';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { DevTestLabsClient, DevTestLabsMappers, DevTestLabsModels } from "@azure/arm-devtestlabs";
import { ResourceManagementClient, ResourceManagementMappers, ResourceManagementModels } from "@azure/arm-resources";

async function getDeployment(templateFile: string, parametersFile: string, parameterOverrides: string): Promise<ResourceManagementModels.Deployment> {
    let deployment = Object.create(ResourceManagementMappers.Deployment);
    let deploymentProperties = Object.create(ResourceManagementMappers.DeploymentProperties);

    deploymentProperties.mode = 'Incremental';
    deploymentProperties.template = await deployutil.getDeploymentTemplate(templateFile);
    //deploymentProperties.parameters = await deployutil.getDeploymentParameters(parametersFile, parameterOverrides);

    deployment.properties = deploymentProperties;

    return deployment;
}

async function createVm(client: DevTestLabsClient, armClient: ResourceManagementClient, labId: string, vmName: string, templateFile: string, parametersFile: string, parameterOverrides: string): Promise<any> {
    const labName = resutil.getLabResourceName(labId, 'labs');
    const labRgName = resutil.getLabResourceName(labId, 'resourcegroups');
    const deployment: ResourceManagementModels.Deployment = await getDeployment(templateFile, parametersFile, parameterOverrides);

    console.log(`Creating Virtual Machine '${vmName}' in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const results: ResourceManagementModels.DeploymentsCreateOrUpdateResponse = await deployVm(armClient, labRgName, deployment);
    
    if (results && results.properties) {
        const properties: any = results.properties;

        if (properties.provisioningState !== 'Succeeded') {
            throw results._response.parsedBody;
        }

        if (properties.outputResources) {
            const outputs = properties.outputResources;
            const vmId: string = outputs.id ? outputs.id : 'undefined';
            tl.setVariable('labVmId', vmId);
        }
    }

    console.log(`Finished creating Lab Virtual Machine '${vmName}'.`);
}

async function deployVm(armClient: ResourceManagementClient, rgName: string, deployment: ResourceManagementModels.Deployment): Promise<ResourceManagementModels.DeploymentsCreateOrUpdateResponse> {
    const deploymentName: string = deployutil.getDeploymentName();
    return await armClient.deployments.createOrUpdate(rgName, deploymentName, deployment);
}

async function testRun() {
/*
    const testlog = 'D:\\Repos\\GitHub\\leovms\\azure-devtestlab\\tasks\\Node\\out\\tasks\\AzureDtlCreateVM\\testlog.json';
    const error = await deployutil.getDeploymentTemplate(testlog);
    console.debug(deployutil.getDeploymentError(error));
*/
    try {
        const data: any = await testutil.getTestData();

        const client: DevTestLabsClient = await resutil.getDtlClient(data.subscriptionId, true);
        const armClient: ResourceManagementClient = await resutil.getArmClient(data.subscriptionId, true);

        await createVm(client, armClient, data.labId, data.vmName, data.templateFile, data.parametersFile, data.parameterOverrides);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Virtual Machine '${data.vmName}' was successfully created.`);
    }
    catch (error) {
        await testutil.writeTestLog(error);
        tl.setResult(tl.TaskResult.Failed, deployutil.getDeploymentError(error));
    }
}

async function run() {
    try {
        console.log('Starting Azure DevTest Labs Create VM Task');

        // TODO: showInputParameters

        const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);

        const subscriptionId: string = tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true);
        const labId: string = tl.getInput('LabId', true);
        const vmName: string = tl.getInput('VirtualMachineName', true);
        const templateFile: string = tl.getInput('TemplateFile', true);
        const parametersFile: string = tl.getInput('ParametersFile', false)
        const parameterOverrides: string = tl.getInput('ParameterOverrides', false);

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId);
        const armClient: ResourceManagementClient = await resutil.getArmClient(subscriptionId);

        await createVm(client, armClient, labId, vmName, templateFile, parametersFile, parameterOverrides);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Virtual Machine '${vmName}' was successfully created.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, deployutil.getDeploymentError(error));
    }
}

var args = require('minimist')(process.argv.slice(2));
if (args.test) {
    testRun();
}
else {
    run();
}