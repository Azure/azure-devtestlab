import * as tl from 'azure-pipelines-task-lib/task';
import * as msRestNodeAuth from '@azure/ms-rest-nodeauth';

import { DevTestLabsClient } from '@azure/arm-devtestlabs';
import { ResourceManagementClient } from '@azure/arm-resources';

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

async function getCredentials(forTesting?: boolean): Promise<any> {
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
    const credentials = await getCredentials(forTesting);
    return new ResourceManagementClient(credentials, subscriptionId)
}

export async function getDtlClient(subscriptionId: string, forTesting?: boolean): Promise<DevTestLabsClient> {
    tl.debug(`ResourceUtil: Getting DTL client instance.`);
    const credentials = await getCredentials(forTesting);
    return new DevTestLabsClient(credentials, subscriptionId);
}

export function testVmName(vmName: string, maxNameLength: number = 15): boolean {
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