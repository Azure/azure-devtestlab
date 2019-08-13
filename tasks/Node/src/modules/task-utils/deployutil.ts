import fs from 'fs';
import util from 'util';
import uuidv4 from 'uuid/v4';

import * as tl from 'azure-pipelines-task-lib/task';

import { DevTestLabsModels, DevTestLabsMappers } from "@azure/arm-devtestlabs";
import { DeploymentsListByResourceGroupResponse } from '@azure/arm-resources/esm/models';
import { ResourceManagementClient } from '@azure/arm-resources';

async function addParameterOverrides(parameterOverrides: string, existingParameters: DevTestLabsModels.ArmTemplateParameterProperties[]): Promise<DevTestLabsModels.ArmTemplateParameterProperties[]> {
    if (parameterOverrides == null ||
        parameterOverrides == undefined ||
        parameterOverrides.length == 0) {
        return existingParameters;
    }

    let newParameter: DevTestLabsModels.ArmTemplateParameterProperties = Object.create(DevTestLabsMappers.ArmTemplateParameterProperties);

    var parsedParameterOverrides = parameterOverrides.split(' ');

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

async function fromParametersFile(parametersFile: string): Promise<DevTestLabsModels.ArmTemplateParameterProperties[]> {
    let parameters: DevTestLabsModels.ArmTemplateParameterProperties[] = [];

    if (!parametersFile) {
        console.warn(`DeployUtil: Ignoring invalid parameters file '${parametersFile}'.`);
        return parameters;
    }

    const fsExists = util.promisify(fs.exists);

    if (!await fsExists(parametersFile)) {
        console.warn(`DeployUtil: Ignoring. Unable to locate parameters file '${parametersFile}'.`);
        return parameters;
    }

    const fsStat = util.promisify(fs.stat);
    const fsReadFile = util.promisify(fs.readFile);
    
    const stats = await fsStat(parametersFile);
    if (stats.isFile()) {
        const data = await fsReadFile(parametersFile, 'utf8');
        const params = JSON.parse(data);
        let props = Object.keys(params.parameters), i = props.length, resArray = new Array(i);
        while (i--) {
            resArray[i] = [props[i], params.parameters[props[i]]];
            let parameter = Object.create(DevTestLabsMappers.ArmTemplateParameterProperties);
            parameter.name = props[i];
            parameter.value = params.parameters[props[i]].value.toString();
            parameters.push(parameter);
        }
    }
    else {
        console.warn(`DeployUtil: Provided parameters file is not valid: '${parametersFile}'`)
    }

    return parameters;
}

function getDeploymentErrorDetailMessage(detail: any) {
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

export function getDeploymentName(prefix: string = 'Dtl') {
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
    tl.debug(JSON.stringify(deploymentOutput));

    return deploymentOutput;
}

export async function getDeploymentParameters(parametersFile: string, parameterOverrides: string): Promise<DevTestLabsModels.ArmTemplateParameterProperties[]> {
    let parameters = await fromParametersFile(parametersFile);
    return await addParameterOverrides(parameterOverrides, parameters);
}

export async function getDeploymentTemplate(templateFile: string): Promise<any> {
    let template: any = null;

    const fsStat = util.promisify(fs.stat);
    const fsReadFile = util.promisify(fs.readFile);

    const stats = await fsStat(templateFile);
    if (stats.isFile()) {
        const contents = await fsReadFile(templateFile, 'utf8');
        template = JSON.parse(contents);
    }

    return template;
}

export function replaceParameter(parameters: DevTestLabsModels.ArmTemplateParameterProperties[], name: string, value: string): void {
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

export function sleep(ms: number): Promise<any> {
    return new Promise(resolve => setTimeout(resolve, ms));
}