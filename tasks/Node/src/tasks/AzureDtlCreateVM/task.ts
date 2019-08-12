import '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as deployutil from '../../modules/task-utils/deployutil';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { DevTestLabsClient, DevTestLabsMappers, DevTestLabsModels } from "@azure/arm-devtestlabs";
import { ResourceManagementClient, ResourceManagementMappers, ResourceManagementModels } from "@azure/arm-resources";

function replaceParameter(parameters: DevTestLabsModels.ArmTemplateParameterProperties[], name: string, value: string): void {
    let newParameter: DevTestLabsModels.ArmTemplateParameterProperties = { name: name, value: value };
    let index = parameters.findIndex(p => p.name === name);
    if (index > -1) {
        // Replace inplace.
        parameters.splice(index, 1, newParameter);
    }
    else {
        // Insert at the begining.
        parameters.splice(0, 0, newParameter);
    }
}

async function getDeploymentParameters(labName: string, vmName: string, parametersFile: string, parameterOverrides: string): Promise<any> {
    let parameters = {};

    let deploymentParameters: DevTestLabsModels.ArmTemplateParameterProperties[] = await deployutil.getDeploymentParameters(parametersFile, parameterOverrides);

    replaceParameter(deploymentParameters, 'labName', labName);
    replaceParameter(deploymentParameters, 'newVMName', vmName);

    deploymentParameters.forEach((p) => parameters[`${p.name}`] = { value: p.value });

    return parameters;
}

async function getDeployment(labName: string, vmName: string, templateFile: string, parametersFile: string, parameterOverrides: string): Promise<ResourceManagementModels.Deployment> {
    let deployment = Object.create(ResourceManagementMappers.Deployment);
    let deploymentProperties = Object.create(ResourceManagementMappers.DeploymentProperties);

    deploymentProperties.mode = 'Incremental';
    deploymentProperties.template = await deployutil.getDeploymentTemplate(templateFile);
    deploymentProperties.parameters = await getDeploymentParameters(labName, vmName, parametersFile, parameterOverrides);

    deployment.properties = deploymentProperties;

    return deployment;
}

function testVmName(vmName: string, maxNameLength: number = 15): boolean {
    if (!vmName) {
        throw `Invalid VM name '${vmName}'. Name must be specified.`;
    }

    if (vmName.length > maxNameLength) {
        throw `Invalid VM name '${vmName}'. Name must be between 1 and ${maxNameLength} characters.`;
    }

    // TODO: Get latest Regex from DTL UI code.
    const regex = new RegExp('^(?=.*[a-zA-Z/-]+)[0-9a-zA-Z/-]*$');
    if (!regex.test(vmName)) {
        throw `Invalid VM name '${vmName}'. Name cannot contain any spaces or special characters. The name may contain letters, numbers, or '-'. However, it must begin and end with a letter or number, and cannot be all numbers.`;
    }

    return true;
}

function convertToMinutesString(minutes: number) {
    return `${minutes} minute${minutes !== 1 ? 's' : ''}.`;
}

function sleep(ms: number): Promise<any> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForApplyArtifacts(client: DevTestLabsClient, labVmId: string, waitMinutes: number): Promise<any> {
    if (waitMinutes <= 0) {
        return;
    }

    console.log(`Waiting for a maximum of ${convertToMinutesString(waitMinutes)} for apply artifacts operation to complete.`);

    const labName: string = resutil.getLabResourceName(labVmId, 'labs');
    const labRgName: string = resutil.getLabResourceName(labVmId, 'resourcegroups');
    const vmName: string = resutil.getLabResourceName(labVmId, 'virtualmachines');
    const vmGetParams: DevTestLabsModels.VirtualMachinesGetOptionalParams = { expand: 'properties($expand=artifacts)' };

    const startWait: number = Date.now();
    let totalWaitMinutes: number = 0;
    let provisioningState: any;
    let continueWaiting: boolean = true;

    do {
        const waitSpanMinutes: number = new Date(Date.now() - startWait).getMinutes();
        totalWaitMinutes = Math.round(waitSpanMinutes);

        const expired: boolean = waitSpanMinutes >= waitMinutes;
        if (expired) {
            throw `Waited for more than ${convertToMinutesString(totalWaitMinutes)}. Failing the task.`;
        }

        const vm: DevTestLabsModels.VirtualMachinesGetResponse = await client.virtualMachines.get(labRgName, labName, vmName, vmGetParams);
        if (!vm) {
            throw `Unable to get details for VM '${vmName}' under lab '${labName}' and resource group '${labRgName}'.`;
        }

        provisioningState = vm.provisioningState;
        // TODO: Check for artifacts installing status.
        // continueWaiting = testArtifactsInstalling(vm.artifacts);

        if (continueWaiting) {
            // The only time we have seen we possibly need to wait is if the ARM deployment completed prematurely,
            // for some unknown error, and the virtual machine is still applying artifacts. So, it is reasonable to
            // recheck every 5 minutes.
            await sleep(1000); //300 * 1000);
            continueWaiting = false;
        }
    } while (continueWaiting);

    console.log(`Waited for a total of ${convertToMinutesString(totalWaitMinutes)}. Latest provisioning state is ${provisioningState}.`);
}

async function createVm(client: DevTestLabsClient, armClient: ResourceManagementClient, labId: string, vmName: string, templateFile: string, parametersFile: string, parameterOverrides: string, retryCount: number, appendRetryNumberToVmName: boolean, waitMinutes: number): Promise<any> {
    let labVmId: string | undefined = undefined;

    const labName: string = resutil.getLabResourceName(labId, 'labs');
    const labRgName: string = resutil.getLabResourceName(labId, 'resourcegroups');

    console.log(`Creating Virtual Machine in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const baseVmName: string = vmName;
    const count: number = 1 + retryCount;

    for (let i = 1; i <= count; i++) {
        // TODO: Validate all input parameters.
        testVmName(vmName);

        try {
            const deploymentName: string = deployutil.getDeploymentName();
            const deployment: ResourceManagementModels.Deployment = await getDeployment(labName, vmName, templateFile, parametersFile, parameterOverrides);

            console.log('Invoking deployment with the following parameters:');
            console.log(`  DeploymentName = ${deploymentName}`);
            console.log(`  ResourceGroupName = ${labRgName}`);
            console.log(`  LabName = ${labName}`);
            console.log(`  VmName = ${vmName}`);
            console.log(`  TemplateFile = ${templateFile}`);

            const results: ResourceManagementModels.DeploymentsCreateOrUpdateResponse = await armClient.deployments.createOrUpdate(labRgName, deploymentName, deployment);

            if (results && results.properties) {
                const properties: any = results.properties;

                if (properties.provisioningState !== 'Succeeded') {
                    throw results._response.parsedBody;
                }

                if (properties.outputResources) {
                    const outputs = properties.outputResources[0];
                    if (outputs.id) {
                        labVmId = outputs.id;
                    }
                }
            }

            if (labVmId) {
                await waitForApplyArtifacts(client, labVmId, waitMinutes);
                // TODO: Check artifact status.
                // await testArtifactStatus(labVmId, templateFile, failOnArtifactError);
            }
        }
        catch (error) {
            if (i === count) {
                throw error;
            }
            else {
                // Reset labVmId to ensure we don't mistakenly return a previously invalid value in case of a subsequent retry error.
                labVmId = undefined;

                tl.warning(`A deployment failure occured. Retrying deployment (attempt ${i} of ${count - 1}).`);

                // TODO: Remove failed deployments.

                if (appendRetryNumberToVmName) {
                    vmName = `${baseVmName}-${i}`;
                }
            }
        }
    }

    if (labVmId) {
        tl.setVariable('labVmId', labVmId);
    }

    console.log(`Finished creating Lab Virtual Machine '${vmName}'.`);
}

async function testRun(vmName: string) {
    try {
        const data: any = await testutil.getTestData();
        const retryCount: number = data.retryCount ? +data.retryCount : 0;
        const appendRetryNumberToVmName: boolean = data.appendRetryNumberToVmName ? Boolean(data.appendRetryNumberToVmName) : false;
        const waitMinutes: number = data.waitMinutes ? +data.waitMinutes : 0;
        vmName = vmName ? vmName : data.vmName;

        const client: DevTestLabsClient = await resutil.getDtlClient(data.subscriptionId, true);
        const armClient: ResourceManagementClient = await resutil.getArmClient(data.subscriptionId, true);

        await createVm(client, armClient, data.labId, vmName, data.templateFile, data.parametersFile, data.parameterOverrides, retryCount, appendRetryNumberToVmName, waitMinutes);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Virtual Machine '${vmName}' was successfully created.`);
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
        const retryOnFailure: boolean = tl.getBoolInput('RetryOnFailure', false);
        const retryCount: number = retryOnFailure ? +tl.getInput('RetryCount', false) : 0;
        const appendRetryNumberToVmName: boolean = tl.getBoolInput('AppendRetryNumberToVmName', false);
        const waitMinutes: number = +tl.getInput('WaitMinutesForApplyArtifacts', false);

        const client: DevTestLabsClient = await resutil.getDtlClient(subscriptionId);
        const armClient: ResourceManagementClient = await resutil.getArmClient(subscriptionId);

        await createVm(client, armClient, labId, vmName, templateFile, parametersFile, parameterOverrides, retryCount, appendRetryNumberToVmName, waitMinutes);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Virtual Machine '${vmName}' was successfully created.`);
    }
    catch (error) {
        console.debug(error);
        tl.setResult(tl.TaskResult.Failed, deployutil.getDeploymentError(error));
    }
}

var args = require('minimist')(process.argv.slice(2));
if (args.test) {
    testRun(args.vmName);
}
else {
    run();
}