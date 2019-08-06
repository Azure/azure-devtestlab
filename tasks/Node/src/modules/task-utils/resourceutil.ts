import * as tl from 'azure-pipelines-task-lib/task';
import * as msRestNodeAuth from '@azure/ms-rest-nodeauth';

import { DevTestLabsClient } from '@azure/arm-devtestlabs';
import { DeploymentsListByResourceGroupResponse } from '@azure/arm-resources/esm/models';
import { ResourceManagementClient, ResourceManagementModels, ResourceManagementMappers } from '@azure/arm-resources';

function getIdParts(resourceId: string): string[] {
    // Resource Id should not be escaped.
    resourceId = unescape(resourceId);

    // Return the list, removing any empty values.
    return resourceId.split('/').filter((value) => value && 0 < value.length);
}

export function getResourceName(resourceId: string, resourceTypePlural: string, parts: string[] | null = null): string {
    // Determine if we should break the resourceId into its parts.
    if (!parts) {
        // Get all parts of the resource ID. This call will NOT affect casing, but it will remove
        // any trailing '/'.
        parts = getIdParts(resourceId);
    }

    // Determine if there's an error while parsing the resource ID.
    if (!parts || 4 > parts.length) {
        throw `ResourceUtil: Failed to parse string or too few resource type parts in resource ID '${resourceId}'.`;
    }
    
    // Ensure we have key/value pairs.
    if (parts.length % 2 != 0) {
        throw `ResourceUtil: Invalid resource ID '${resourceId}'.`;
    }

    // Determine if the requested resource type is present in the resource ID.
    const matchingPart = `/${resourceTypePlural}/`;
    const index = resourceId.toLowerCase().indexOf(matchingPart.toLowerCase());
    if (index == -1) {
        throw `ResourceUtil: Resource type '${resourceTypePlural}' is not present in resource ID '${resourceId}'.`;
    }

    // Traverse through the resource ID parts in reverse order, looking for the requested
    // resource type and extract its corresponding value.
    for (let i = parts.length - 2; i >= 0; i -= 2) {
        const key = parts[i];
        const value = parts[i + 1];
        if (key.toLowerCase() === resourceTypePlural.toLowerCase()) {
            return value;
        }
    }

    // Nothing found.
    throw `ResourceUtil: Unable to find value for requested resource type '${resourceTypePlural}'.`;
}

export function getLabResourceName(resourceId: string, resourceTypePlural: string): string {
    // Get all parts of the resource ID. This call will NOT affect casing, but it will remove
    // any trailing '/'.
    const parts = getIdParts(resourceId);

    // Determine if there's an error while parsing the resource ID.
    if (!parts || 6 > parts.length) {
        throw `ResourceUtil: Failed to parse string or too few resource type parts in lab resource ID '${resourceId}'.`;
    }

    // Ensure that the resource ID is that of a lab ("labs" is present where expected) or one
    // of it's child-resources. Also, do a sanity check that we have proper key/value pairs.
    if ('labs' !== parts[6].toLowerCase() || parts.length % 2 != 0) {
        throw `ResourceUtil: Invalid lab resource ID '${resourceId}'.`;
    }

    return getResourceName(resourceId, resourceTypePlural);
}

async function getCredentials(subscriptionId: string, forTesting?: boolean): Promise<any> {
    let credentials: any;

    if (forTesting) {
        const options: msRestNodeAuth.LoginWithAuthFileOptions = {
            filePath: 'authfile.json'
        }

        tl.debug(`ResourceUtil: Login using ${options.filePath}.`);
        const response: msRestNodeAuth.AuthResponse = await msRestNodeAuth.loginWithAuthFileWithAuthResponse(options);

        credentials = response.credentials;
    }
    else {
        const connectedServiceName: string = tl.getInput('ConnectedServiceName', true);
        const spId = tl.getEndpointAuthorizationParameter(connectedServiceName, 'ServicePrincipalId', false);
        const spKey = tl.getEndpointAuthorizationParameter(connectedServiceName, 'ServicePrincipalKey', false);
        const tenantId = tl.getEndpointAuthorizationParameter(connectedServiceName, 'TenantId', false);

        tl.debug(`ResourceUtil: Login using ConnectedServiceName '${connectedServiceName}'.`);
        credentials = await msRestNodeAuth.loginWithServicePrincipalSecret(spId, spKey, tenantId);
    }

    return credentials;
}

export async function getArmClient(subscriptionId: string, forTesting?: boolean): Promise<ResourceManagementClient> {
    tl.debug(`ResourceUtil: Getting ARM client instance.`);
    const credentials = await getCredentials(subscriptionId, forTesting);
    return new ResourceManagementClient(credentials, subscriptionId)
}

export async function getDtlClient(subscriptionId: string, forTesting?: boolean): Promise<DevTestLabsClient> {
    tl.debug(`ResourceUtil: Getting DTL client instance.`);
    const credentials = await getCredentials(subscriptionId, forTesting);
    return new DevTestLabsClient(credentials, subscriptionId);
}

export async function getDeploymentOutput(armClient: ResourceManagementClient, resourceGroupName: string): Promise<any[]> {
    let deploymentOutput: any[] = new Array(0);

    tl.debug(`ResourceUtil: Getting deployment output for resource group '${resourceGroupName}'.`);

    const results: DeploymentsListByResourceGroupResponse = await armClient.deployments.listByResourceGroup(resourceGroupName);
    if (results) {
        const deploymentName = results._response.parsedBody[0].name;
        if (deploymentName) {
            const deploymentResults = await armClient.deployments.get(resourceGroupName, deploymentName);
            if (deploymentResults && deploymentResults.properties && deploymentResults.properties.outputs) {
                const props = Object.keys(deploymentResults.properties.outputs)
                let i = props.length;
                deploymentOutput = new Array(i);
                while(i--) {
                    deploymentOutput[i] = [props[i], deploymentResults.properties.outputs[props[i]].value];
                }
            }
        }
    }

    tl.debug(`ResourceUtil: Completed getting deployment output for resource group '${resourceGroupName}'.`);
    tl.debug(JSON.stringify(deploymentOutput));

    return deploymentOutput;
}

/*
export function deployResource(sourceFile: string, deploymentInfo: any, dtlClient: DevTestLabsClient, armClient: ResourceManagementClient, labRg: string, labName: string, RetryOnFailure: boolean, RetryCount: number, DeleteFailedDeploymentBeforeRetry: boolean, FailOnArtifactError: boolean, DeleteFailedLabVMBeforeRetry: boolean, AppendRetryNumberToVMName: boolean): Promise<any> {
    const deploymentProperties: ResourceManagementModels.DeploymentProperties = Object.create(ResourceManagementMappers.DeploymentProperties);
    const deployment: ResourceManagementModels.Deployment = Object.create(ResourceManagementMappers.Deployment);

    // Generate random number for deployment name 
    let min = Math.ceil(999);
    let max = Math.floor(999999999);
    let randNum = Math.floor(Math.random() * (max - min)) + min;
    let deploymentName = 'DTLTaskDeploy' + randNum.toString();

    return new Promise(function(resolve,reject){
        console.log('Deploying DTL VM.');
        try {
            if (sourceFile != undefined) {
                fs.readFile(sourceFile, 'utf8', function(err,contents) {
                    if (err) { console.log('Unable to read template file. ', err);}
                    deploymentProperties.template = JSON.parse(contents);
                    deploymentProperties.mode = 'Incremental';
                    deploymentProperties.parameters = deploymentInfo;
                    deployment.properties = deploymentProperties;

                    console.log('Starting VM creation.');
                    let currentCount: number = 1;
                    if (!RetryOnFailure) {
                        RetryCount = 1;
                    }

                    console.log('Azure deployment name: ', deploymentName);
                    deployVM(dtlClient, armClient,labRg,labName, deploymentName,deployment,RetryOnFailure,FailOnArtifactError, DeleteFailedDeploymentBeforeRetry, currentCount, RetryCount, DeleteFailedLabVMBeforeRetry, AppendRetryNumberToVMName).then((results) =>{
                        resolve(results);
                    }).catch((err) =>{
                        reject(err);
                    });
                });
            }
            else {
                reject(sourceFile + ' does not exist.');
            }
        }
        catch (err) {
            reject(err);
        }
    })
}
*/
