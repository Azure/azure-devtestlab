import fs from 'fs';
import util from 'util';
import uuidv4 from 'uuid/v4';

import { DevTestLabsModels, DevTestLabsMappers } from "@azure/arm-devtestlabs";

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
        console.warn(`DeployUtil: Ignoring invalid parameter file '${parametersFile}'.`);
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

export function getDeploymentName(prefix: string = 'Dtl') {
    const guid = uuidv4().replace('-', '');
    return `${prefix}${guid}`;
}

export function getDeploymentError(deploymentError: any): string {
    let message = deploymentError.body.error.message;
    if (deploymentError.body && deploymentError.body.error && deploymentError.body.error.details) {
        const deploymentErrorDetails = deploymentError.body.error.details;
        deploymentErrorDetails.forEach(detail => {
            message += getDeploymentErrorDetailMessage(detail);
        });
    }
    return message;
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