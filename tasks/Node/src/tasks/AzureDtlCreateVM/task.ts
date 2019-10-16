import '../../modules/task-utils/polyfill';
import { equalsIgnoreCase } from '../../modules/task-utils/polyfill';

import * as tl from 'azure-pipelines-task-lib/task';
import * as deployutil from '../../modules/task-utils/deployutil';
import * as resutil from '../../modules/task-utils/resourceutil';
import * as testutil from '../../modules/task-utils/testutil';

import { CreateVmTaskInputData, TaskClients } from '../../modules/task-models/models';

import { DevTestLabsClient, DevTestLabsModels } from '@azure/arm-devtestlabs';
import { ResourceManagementClient, ResourceManagementMappers, ResourceManagementModels } from '@azure/arm-resources';

function areArtifactsInstalling(artifacts?: DevTestLabsModels.ArtifactInstallProperties[]): boolean {
    if (!artifacts) {
        return false;
    }

    const installingArtifacts: boolean = artifacts.some(a => equalsIgnoreCase(a.status, 'Installing'));
    const pendingArtifacts: boolean = artifacts.some(a => equalsIgnoreCase(a.status, 'Pending'));

    return installingArtifacts || pendingArtifacts;
}

async function checkArtifactsStatus(client: DevTestLabsClient, labVmId: string, templateFile: string, failOnArtifactError: boolean): Promise<void> {
    if (!failOnArtifactError) {
        tl.debug(`Fail on artifact error is ${failOnArtifactError}. Nothing to check. Ignoring.`);
        return;
    }

    const expectedArtifactsCount: number = getExpectedArtifactsCount(templateFile);
    if (expectedArtifactsCount <= 0) {
        tl.debug(`Expected artifact count is ${expectedArtifactsCount}. Nothing to check. Ignoring.`);
        return;
    }

    const vm: DevTestLabsModels.VirtualMachinesGetResponse = await getLabVm(client, labVmId);

    const artifacts: DevTestLabsModels.ArtifactInstallProperties[] = vm.artifacts ? vm.artifacts : [];
    const failedArtifacts: DevTestLabsModels.ArtifactInstallProperties[] = artifacts.filter(a => a && equalsIgnoreCase(a.status, 'Failed'));
    const succeededArtifacts: DevTestLabsModels.ArtifactInstallProperties[] = artifacts.filter(a => a && equalsIgnoreCase(a.status, 'Succeeded'));

    console.log(`Number of Artifacts Expected: ${expectedArtifactsCount}, Reported: ${artifacts.length}, Succeeded: ${succeededArtifacts.length}, Failed: ${failedArtifacts.length}`);

    if (failedArtifacts.length > 0 || succeededArtifacts.length < expectedArtifactsCount) {
        failedArtifacts.forEach(failedArtifact => {
            tl.warning(`Failed to apply artifact '${getArtifactName(failedArtifact)}'.`);

            if (failedArtifact.deploymentStatusMessage) {
                let deploymentStatusMessage: string = failedArtifact.deploymentStatusMessage;
                try {
                    deploymentStatusMessage = JSON.parse(failedArtifact.deploymentStatusMessage).error.details.message;
                }
                catch {
                    // Use the default.
                }
                console.log(`deploymentStatusMessage = ${deploymentStatusMessage}`);
            }

            if (failedArtifact.vmExtensionStatusMessage) {
                let vmExtensionStatusMessage: string = failedArtifact.vmExtensionStatusMessage;
                try {
                    vmExtensionStatusMessage = JSON.parse(failedArtifact.vmExtensionStatusMessage)[1].message;
                }
                catch {
                    // Use the default.
                }
                console.log(`vmExtensionStatusMessage = ${vmExtensionStatusMessage.replace(/\\n/gi, '')}`);
            }
        });

        throw 'At least one artifact failed to apply. Review the lab virtual machine artifact results blade for full details.';
    }
}

function convertToMinutesString(minutes: number): string {
    return `${minutes} minute${minutes !== 1 ? 's' : ''}`;
}

async function createVm(clients: TaskClients, inputData: CreateVmTaskInputData): Promise<void> {
    let labVmId: string | undefined = undefined;

    const labName: string = resutil.getLabResourceName(inputData.labId, 'labs');
    const labRgName: string = resutil.getLabResourceName(inputData.labId, 'resourcegroups');

    console.log(`Creating Virtual Machine in Lab '${labName}' under Resource Group '${labRgName}'.`);

    const baseVmName: string = inputData.vmName;
    const count: number = 1 + inputData.retryCount;

    for (let i = 1; i <= count; i++) {
        const deploymentName: string = deployutil.getDeploymentName();

        resutil.testVmName(inputData.vmName);

        try {
            const deployment: ResourceManagementModels.Deployment = getDeployment(labName, inputData.vmName, inputData.templateFile, inputData.parametersFile, inputData.parameterOverrides);

            console.log('Invoking deployment with the following parameters:');
            console.log(`  DeploymentName = ${deploymentName}`);
            console.log(`  ResourceGroupName = ${labRgName}`);
            console.log(`  LabName = ${labName}`);
            console.log(`  VmName = ${inputData.vmName}`);
            console.log(`  TemplateFile = ${inputData.templateFile}`);

            const results: ResourceManagementModels.DeploymentsCreateOrUpdateResponse = await clients.arm.deployments.createOrUpdate(labRgName, deploymentName, deployment);

            if (results && results.properties) {
                const properties: any = results.properties;

                if (properties.provisioningState !== 'Succeeded') {
                    throw results._response.parsedBody;
                }

                if (properties.outputResources) {
                    const outputs: any = properties.outputResources[0];
                    if (outputs.id) {
                        labVmId = outputs.id;
                    }
                }
            }

            if (labVmId) {
                await waitForApplyArtifacts(clients.dtl, labVmId, inputData.waitMinutes);
                await checkArtifactsStatus(clients.dtl, labVmId, inputData.templateFile, inputData.failOnArtifactError);
                break;
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
                tl.debug('Deployment failed with error:');
                tl.debug(JSON.stringify(error, null, 2));

                await removeFailedResources(clients.arm, labRgName, deploymentName, inputData.deleteLabVm, inputData.deleteDeployment);

                if (inputData.appendRetryNumberToVmName) {
                    inputData.vmName = `${baseVmName}-${i}`;
                }
            }
        }
    }

    if (labVmId) {
        tl.setVariable('labVmId', labVmId);
    }

    console.log(`Finished creating Lab Virtual Machine '${inputData.vmName}'.`);
}

function getArtifactName(artifact: DevTestLabsModels.ArtifactInstallProperties): string {
    let artifactName: string | undefined = artifact.artifactTitle;

    if (!artifactName && artifact.artifactId) {
        const artifactIdParts: string[] = artifact.artifactId.split('/');
        artifactName = artifactIdParts.length > 0 ? artifactIdParts[artifactIdParts.length - 1] : '';
    }

    return artifactName ? artifactName : '';
}

function getDeploymentParameters(labName: string, vmName: string, parametersFile: string, parameterOverrides: string): any {
    const parameters = {};

    const deploymentParameters: DevTestLabsModels.ArmTemplateParameterProperties[] = deployutil.getDeploymentParameters(parametersFile, parameterOverrides);

    deployutil.replaceParameter(deploymentParameters, 'labName', labName);
    deployutil.replaceParameter(deploymentParameters, 'newVMName', vmName);

    deploymentParameters.forEach((p) => parameters[`${p.name}`] = { value: p.value });

    return parameters;
}

function getDeployment(labName: string, vmName: string, templateFile: string, parametersFile: string, parameterOverrides: string): ResourceManagementModels.Deployment {
    const deployment = Object.create(ResourceManagementMappers.Deployment);
    const deploymentProperties = Object.create(ResourceManagementMappers.DeploymentProperties);

    deploymentProperties.mode = 'Incremental';
    deploymentProperties.template = deployutil.getDeploymentTemplate(templateFile);
    deploymentProperties.parameters = getDeploymentParameters(labName, vmName, parametersFile, parameterOverrides);

    deployment.properties = deploymentProperties;

    return deployment;
}

function getExpectedArtifactsCount(templateFile: string): number {
    let expectedArtifactCount: number = 0;

    const template: any = deployutil.getDeploymentTemplate(templateFile);
    if (template && template.resources) {
        const vmTemplate = template.resources.find((r: any) => r && equalsIgnoreCase(r.type, 'Microsoft.DevTestLab/labs/virtualmachines'));
        expectedArtifactCount = vmTemplate && vmTemplate.properties && vmTemplate.properties.artifacts && vmTemplate.properties.artifacts.length ? vmTemplate.properties.artifacts.length : 0;
    }

    return expectedArtifactCount;
}

function getInputData(vmName?: string, test?: boolean): CreateVmTaskInputData {
    let inputData: CreateVmTaskInputData;

    if (test) {
        const data: any = testutil.getTestData();
        const retryOnFailure: boolean = data.retryOnFailure ? Boolean(data.retryOnFailure) : false;

        inputData = {
            appendRetryNumberToVmName: data.appendRetryNumberToVmName ? Boolean(data.appendRetryNumberToVmName) : false,
            connectedServiceName: 'local',
            deleteDeployment: data.deleteDeployment ? Boolean(data.deleteDeployment) : false,
            deleteLabVm: data.deleteLabVm ? Boolean(data.deleteLabVm) : false,
            failOnArtifactError: data.failOnArtifactError ? Boolean(data.failOnArtifactError) : false,
            labId: data.labId,
            parameterOverrides: data.parameterOverrides,
            parametersFile: data.parametersFile,
            retryOnFailure: retryOnFailure,
            retryCount: retryOnFailure && data.retryCount ? +data.retryCount : 0,
            subscriptionId: data.subscriptionId,
            templateFile: data.templateFile,
            vmName: vmName ? vmName : data.vmName,
            waitMinutes: data.waitMinutes ? +data.waitMinutes : 0
        };
    } else {
        const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);
        const retryOnFailure: boolean = tl.getBoolInput('RetryOnFailure', false);

        inputData = {
            appendRetryNumberToVmName: tl.getBoolInput('AppendRetryNumberToVmName', false),
            connectedServiceName: connectedServiceName,
            deleteDeployment: tl.getBoolInput('DeleteFailedDeploymentBeforeRetry', false),
            deleteLabVm: tl.getBoolInput('DeleteFailedLabVMBeforeRetry', false),
            failOnArtifactError: tl.getBoolInput('FailOnArtifactError', false),
            labId: tl.getInput('LabId', true),
            parameterOverrides: tl.getInput('ParameterOverrides', false),
            parametersFile: tl.getInput('ParametersFile', false),
            retryOnFailure: retryOnFailure,
            retryCount: retryOnFailure ? +tl.getInput('RetryCount', false) : 0,
            subscriptionId: tl.getEndpointDataParameter(connectedServiceName, 'SubscriptionId', true),
            templateFile: tl.getInput('TemplateFile', true),
            vmName: tl.getInput('VirtualMachineName', true),
            waitMinutes: +tl.getInput('WaitMinutesForApplyArtifacts', false)
        };
    }

    return inputData;
}

async function getLabVm(client: DevTestLabsClient, labVmId: string): Promise<DevTestLabsModels.VirtualMachinesGetResponse> {
    const labName: string = resutil.getLabResourceName(labVmId, 'labs');
    const labRgName: string = resutil.getLabResourceName(labVmId, 'resourcegroups');
    const vmName: string = resutil.getLabResourceName(labVmId, 'virtualmachines');
    const vmGetParams: DevTestLabsModels.VirtualMachinesGetOptionalParams = { expand: 'properties($expand=artifacts)' };

    const vm: DevTestLabsModels.VirtualMachinesGetResponse = await client.virtualMachines.get(labRgName, labName, vmName, vmGetParams);
    if (!vm) {
        throw `Unable to get details for VM '${vmName}' under lab '${labName}' and resource group '${labRgName}'.`;
    }

    return vm;
}

async function removeFailedResources(armClient: ResourceManagementClient, labRgName: string, deploymentName: string, deleteLabVm: boolean, deleteDeployment: boolean): Promise<void> {
    try {
        // Delete the failed lab VM.
        if (deleteLabVm) {
            const resourceId: string = await deployutil.getDeploymentTargetResourceId(armClient, labRgName, deploymentName);
            if (resourceId) {
                console.log(`Removing previously created lab virtual machine with resource ID '${resourceId}'.`);
                await armClient.resources.deleteById(resourceId, '2018-10-15-preview');
            }
            else {
                console.log('Resource identifier is not available, will not attempt to remove corresponding resouce before retrying.');
            }
        }

        // Delete the failed deployment.
        if (deleteDeployment) {
            console.log(`Removing previously created deployment '${deploymentName}' in resource group '${labRgName}'.`);
            await armClient.deployments.deleteMethod(labRgName, deploymentName);
        }
    } catch (error) {
        tl.warning(`Unable to clean-up failed resources. Operation failed with error ${JSON.stringify(error)}`);
    }
}

function showInputData(inputData: CreateVmTaskInputData): void {
    console.log('Task called with the following parameters:');
    console.log(`  ConnectedServiceName = ${inputData.connectedServiceName}`);
    console.log(`  LabId = ${inputData.labId}`);
    console.log(`  VirtualMachineName = ${inputData.vmName}`);
    console.log(`  TemplateFile = ${inputData.templateFile}`);
    console.log(`  ParametersFile = ${inputData.parametersFile}`);
    console.log(`  FailOnArtifactError = ${inputData.failOnArtifactError}`);
    console.log(`  RetryOnFailure = ${inputData.retryOnFailure}`);
    console.log(`  RetryCount = ${inputData.retryCount}`);
    console.log(`  DeleteFailedLabVMBeforeRetry = ${inputData.deleteLabVm}`);
    console.log(`  DeleteFailedDeploymentBeforeRetry = ${inputData.deleteDeployment}`);
    console.log(`  AppendRetryNumberToVMName = ${inputData.appendRetryNumberToVmName}`);
    console.log(`  WaitMinutesForApplyArtifacts = ${inputData.waitMinutes}`);
}

async function waitForApplyArtifacts(client: DevTestLabsClient, labVmId: string, waitMinutes: number): Promise<void> {
    if (waitMinutes <= 0) {
        return;
    }

    console.log(`Waiting for a maximum of ${convertToMinutesString(waitMinutes)} for apply artifacts operation to complete.`);

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

        const vm: DevTestLabsModels.VirtualMachinesGetResponse = await getLabVm(client, labVmId);

        provisioningState = vm.provisioningState;
        continueWaiting = areArtifactsInstalling(vm.artifacts);

        if (continueWaiting) {
            // The only time we have seen we possibly need to wait is if the ARM deployment completed prematurely,
            // for some unknown error, and the virtual machine is still applying artifacts. So, it is reasonable to
            // recheck at a maximum every 5 minutes.
            const ms: number = 1000 * Math.min(waitMinutes * 60, 300);
            await deployutil.sleep(ms);
        }
    } while (continueWaiting);

    console.log(`Waited for a total of ${convertToMinutesString(totalWaitMinutes)}. Latest provisioning state is ${provisioningState}.`);
}

async function run(vmName?: string, test?: boolean): Promise<void> {
    try {
        console.log('Starting Azure DevTest Labs Create VM Task');

        const inputData: CreateVmTaskInputData = getInputData(vmName, test);

        const clients: TaskClients = {
            arm: await resutil.getArmClient(inputData.subscriptionId, test),
            dtl: await resutil.getDtlClient(inputData.subscriptionId, test)
        };

        showInputData(inputData);

        await createVm(clients, inputData);

        tl.setResult(tl.TaskResult.Succeeded, `Lab Virtual Machine '${inputData.vmName}' was successfully created.`);
    }
    catch (error) {
        test ? testutil.writeTestLog(error) : console.debug(error);
        tl.setResult(tl.TaskResult.Failed, deployutil.getDeploymentError(error));
    }
}

const args = require('minimist')(process.argv.slice(2));
run(args.name, args.test);