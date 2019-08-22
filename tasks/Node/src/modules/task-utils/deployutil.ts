import fs from 'fs';
import uuidv4 from 'uuid/v4';

import * as tl from 'azure-pipelines-task-lib/task';

import { DevTestLabsModels, DevTestLabsMappers } from "@azure/arm-devtestlabs";
import { DeploymentsListByResourceGroupResponse, DeploymentOperationsListResponse } from '@azure/arm-resources/esm/models';
import { ResourceManagementClient } from '@azure/arm-resources';

function addParameterOverrides(parameterOverrides: string, existingParameters: DevTestLabsModels.ArmTemplateParameterProperties[]): DevTestLabsModels.ArmTemplateParameterProperties[] {
    if (parameterOverrides == null ||
        parameterOverrides == undefined ||
        parameterOverrides.length == 0) {
        return existingParameters;
    }

    let newParameter: DevTestLabsModels.ArmTemplateParameterProperties = Object.create(DevTestLabsMappers.ArmTemplateParameterProperties);

    const parsedParameterOverrides = parameterOverrides.split(' ');

    parsedParameterOverrides.forEach(parameterOverride => {
        if (parameterOverride.startsWith('-')) {
            if (newParameter.name == undefined) {
                newParameter.name = parameterOverride.slice(1).toString().replace(/^"(.+(?="$))"$/, '$1');
            }
            else {
                existingParameters = checkParamArray(newParameter, existingParameters);
                newParameter = Object.create(DevTestLabsMappers.ArmTemplateParameterProperties);
                newParameter.name = parameterOverride.slice(1).toString().replace(/^"(.+(?="$))"$/, '$1');
            }
        }
        else {
            if (newParameter.value == undefined) {
                // Remove double quotes.
                newParameter.value = parameterOverride.replace(/^"(.+(?="$))"$/, '$1');
                // Remove single quotes.
                newParameter.value = newParameter.value.replace(/["']{1}/gi, "");
            } else {
                // newParameter.value +=  (" " + value.replace(/^"(.+(?="$))"$/, '$1'));
                newParameter.value += (" " + parameterOverride);
                // Remove single quotes.
                newParameter.value = newParameter.value.replace(/^"(.+(?="$))"$/, '$1');
                // Remove double quotes.
                newParameter.value = newParameter.value.replace(/["']{1}/gi, "");
            }
        }
    });

    existingParameters = checkParamArray(newParameter, existingParameters);

    return existingParameters;
}

function checkParamArray(newParameter: DevTestLabsModels.ArmTemplateParameterProperties, existingParameters: DevTestLabsModels.ArmTemplateParameterProperties[]): DevTestLabsModels.ArmTemplateParameterProperties[] {
    let addParameter = true;

    existingParameters.forEach(property => {
        if (property.name == newParameter.name) {
            property.value = newParameter.value;
            addParameter = false;
        }
    });

    if (addParameter) {
        existingParameters.push(newParameter);
    }

    return existingParameters;
}

function fromParametersFile(parametersFile: string): DevTestLabsModels.ArmTemplateParameterProperties[] {
    const parameters: DevTestLabsModels.ArmTemplateParameterProperties[] = [];

    if (!parametersFile) {
        tl.warning(`DeployUtil: Ignoring invalid parameters file '${parametersFile}'.`);
        return parameters;
    }

    if (!fs.existsSync(parametersFile)) {
        tl.warning(`DeployUtil: Ignoring. Unable to locate parameters file '${parametersFile}'.`);
        return parameters;
    }

    const stats = fs.statSync(parametersFile);
    if (stats.isFile()) {
        const data = fs.readFileSync(parametersFile, 'utf8');
        const params = JSON.parse(data);
        const props = Object.keys(params.parameters);
        const resArray = new Array(props.length);

        let i = props.length;
        while (i--) {
            resArray[i] = [props[i], params.parameters[props[i]]];
            const parameter = Object.create(DevTestLabsMappers.ArmTemplateParameterProperties);
            parameter.name = props[i];
            parameter.value = params.parameters[props[i]].value.toString();
            parameters.push(parameter);
        }
    }
    else {
        tl.debug(`DeployUtil: Ignoring. Provided parameters file is not valid: '${parametersFile}'.`)
    }

    return parameters;
}

function getDeploymentErrorDetailMessage(detail: any): string {
    let code = detail.code;
    let message = detail.message;

    try {
        const innerError = JSON.parse(detail.message);

        code = innerError.error.code;
        message = innerError.error.message;

        const innerDetails = innerError.error.details;
        innerDetails.forEach(innerDetail => {
            message += getDeploymentErrorDetailMessage(innerDetail);
        });
    }
    catch (error) {
        // Ignore. Failed to parse JSON string. Assuming it is a relugar string.
    }

    return ` InnerError => code: '${code}'; message: '${message}'`;
}

export function getDeploymentError(deploymentError: any): string {
    let message: string = deploymentError;

    if (deploymentError.message) {
        message = `Error => code: '${deploymentError.code}'; message = '${deploymentError.message}'`
    }

    if (deploymentError.body) {
        if (deploymentError.body.message) {
            message = `Error => code: '${deploymentError.body.code}'; message = '${deploymentError.body.message}'`;
        }
        if (deploymentError.body.error) {
            if (deploymentError.body.error.message) {
                message = deploymentError.body.error.message;
            }
            if (deploymentError.body.error.details) {
                const deploymentErrorDetails = deploymentError.body.error.details;
                deploymentErrorDetails.forEach(detail => {
                    message += getDeploymentErrorDetailMessage(detail);
                });
            }
        }
    }

    return message;
}

export function getDeploymentName(prefix: string = 'Dtl'): string {
    const guid: string = uuidv4().replace(/-/gi, '');
    return `${prefix}${guid}`;
}

export async function getDeploymentOutput(armClient: ResourceManagementClient, resourceGroupName: string): Promise<any[]> {
    let deploymentOutput: any[] = new Array(0);

    tl.debug(`DeployUtil: Getting deployment output for resource group '${resourceGroupName}'.`);

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

    tl.debug(`DeployUtil: Completed getting deployment output for resource group '${resourceGroupName}'.`);

    return deploymentOutput;
}

export function getDeploymentParameters(parametersFile: string, parameterOverrides: string): DevTestLabsModels.ArmTemplateParameterProperties[] {
    const parameters = fromParametersFile(parametersFile);
    return addParameterOverrides(parameterOverrides, parameters);
}

export async function getDeploymentTargetResourceId(armClient: ResourceManagementClient, resourceGroupName: string, deploymentName: string): Promise<string> {
    let targetResourceId: string | undefined = undefined;

    const operations: DeploymentOperationsListResponse = await armClient.deploymentOperations.list(resourceGroupName, deploymentName);
    if (operations) {
        for (const op of operations) {
            if (op && op.properties && op.properties.targetResource && op.properties.targetResource.id) {
                targetResourceId = op.properties.targetResource.id;
                break;
            }
        }
    }

    if (!targetResourceId) {
        tl.warning(`Dumping resource group deployment operation details for deployment '${deploymentName}' in resource group '${resourceGroupName}':`);
        console.log(JSON.stringify(operations, null, 2));
        throw `Unable to extract the target resource from operations for deployment '${deploymentName}' in resource group '${resourceGroupName}'.`;
    }

    return targetResourceId;
}

export function getDeploymentTemplate(templateFile: string): any {
    let template: any = null;

    const stats = fs.statSync(templateFile);
    if (stats.isFile()) {
        const contents = fs.readFileSync(templateFile, 'utf8');
        template = JSON.parse(contents);
    }

    return template;
}

export function replaceParameter(parameters: DevTestLabsModels.ArmTemplateParameterProperties[], name: string, value: string): void {
    const newParameter: DevTestLabsModels.ArmTemplateParameterProperties = { name: name, value: value };
    const index = parameters.findIndex(p => p.name === name);
    if (index > -1) {
        // Replace inplace.
        parameters.splice(index, 1, newParameter);
    }
    else {
        // Insert at the begining.
        parameters.splice(0, 0, newParameter);
    }
}

export function sleep(ms: number): Promise<any> {
    return new Promise(resolve => setTimeout(resolve, ms));
}