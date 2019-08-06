"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const arm_resources_1 = require("@azure/arm-resources");
const tl = require("azure-pipelines-task-lib/task");
const fs = require('fs');
function fromParametersFile(parametersFile) {
    return new Promise(function (resolve, reject) {
        console.log('Parsing parameters file ', parametersFile);
        try {
            fs.stat(parametersFile, (err, stats) => {
                if (err)
                    reject(err);
                if (stats.isFile()) {
                    fs.readFile(parametersFile, 'utf8', function (err2, data) {
                        if (err2)
                            reject(err2);
                        console.log('PARAMS: ', JSON.parse(data).parameters);
                        resolve(JSON.parse(data).parameters);
                    });
                }
                else {
                    reject('Missing file ' + parametersFile);
                }
            }, reject);
        }
        catch (ex) {
            reject(ex);
        }
    });
}
exports.fromParametersFile = fromParametersFile;
function deployResource(sourceFile, deploymentInfo, armClient, environRG, ExportEnvironmentTemplate, ExportEnvironmentTemplateLocation) {
    let envDeployPropB = Object.create(arm_resources_1.ResourceManagementMappers.DeploymentProperties);
    let envDeployB = Object.create(arm_resources_1.ResourceManagementMappers.Deployment);
    return new Promise(function (resolve, reject) {
        console.log('Deploying resource');
        try {
            if (sourceFile != undefined) {
                fs.readFile(sourceFile, 'utf8', function (err, contents) {
                    if (err) {
                        console.log('Unable to read template file. ', err);
                    }
                    envDeployPropB.template = JSON.parse(contents);
                    // Set deployment to not remove existing resources.
                    envDeployPropB.mode = 'Incremental';
                    envDeployPropB.parameters = deploymentInfo;
                    envDeployB.properties = envDeployPropB;
                    console.log('Start Environment update.');
                    var promiseUpdate = armClient.deployments.createOrUpdate(environRG, 'RandomDeployName', envDeployB).then((results) => {
                        if (results._response.status === 200) {
                            resolve(results);
                        }
                        else {
                            reject('Failed ' + results);
                        }
                        if (ExportEnvironmentTemplate) {
                            tl.mkdirP(ExportEnvironmentTemplateLocation);
                            fs.writeFile(ExportEnvironmentTemplateLocation + '/azuredeploy.json', contents, function (err) {
                                if (err)
                                    throw err;
                                console.log('Download Environment file: ' + ExportEnvironmentTemplateLocation + '/azuredeploy.json');
                            });
                        }
                    });
                    promiseUpdate.catch((err) => {
                        reject('Failed: ' + err);
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
    });
}
exports.deployResource = deployResource;
function addOverrideParameters(overrideParameters, existingParameters) {
    let tempParam = {};
    if (overrideParameters.length === 0) {
        return existingParameters;
    }
    else {
        let newParams = newOverrideParameters(overrideParameters);
        for (var newParam in newParams) {
            console.log('single: ', newParam);
            for (var exParam in existingParameters) {
                console.log('exist: ', exParam);
                if (exParam == newParam) {
                    console.log('EX ', existingParameters[exParam]);
                    console.log('New: ', newParams[newParam]);
                    existingParameters[exParam] = newParams[newParam];
                }
            }
        }
    }
    console.log('Updated parameters with overrides');
    return (existingParameters);
}
exports.addOverrideParameters = addOverrideParameters;
function newOverrideParameters(overrideParameters) {
    let overname = '';
    let overvalue = '';
    let valueJSON = {}; //new Array();
    let returnParameters = '{ ';
    var parsedParam = overrideParameters.split(' ');
    parsedParam.forEach(value => {
        if (value.startsWith('-')) {
            if (overname == '') {
                overname = value.slice(1).toString().replace(/^"(.+(?="$))"$/, '$1');
                console.log('Return : ', valueJSON);
            }
            else {
                if (overvalue == 'true' || overvalue == 'false') {
                    var boolParam = (overvalue == 'true');
                    valueJSON[overname] = { Value: boolParam };
                }
                else {
                    valueJSON[overname] = { Value: overvalue };
                }
                overvalue = '';
                overname = value.slice(1).toString().replace(/^"(.+(?="$))"$/, '$1');
            }
        }
        else {
            if (overvalue == '') {
                // remove quotes
                overvalue = value.replace(/^"(.+(?="$))"$/, '$1');
            }
            else {
                overvalue += (" " + value);
                // remove quotes
                overvalue = overvalue.replace(/^"(.+(?="$))"$/, '$1');
            }
            overvalue = overvalue.replace(/["']{1}/gi, "");
        }
    });
    if (overvalue == 'true' || overvalue == 'false') {
        var boolParam = (overvalue == 'true');
        valueJSON[overname] = { Value: boolParam };
    }
    else {
        valueJSON[overname] = { Value: overvalue };
    }
    return (valueJSON);
}
exports.newOverrideParameters = newOverrideParameters;
function getResourceNamesFromResourceURI(ResourceURI, ResourceName) {
    let first = ResourceURI.indexOf(ResourceName) + (ResourceName.length + 1);
    let last = ResourceURI.indexOf('/', first);
    if (last == -1) {
        last = ResourceURI.length;
    }
    let returnValue = ResourceURI.substring(first, last);
    return returnValue;
}
exports.getResourceNamesFromResourceURI = getResourceNamesFromResourceURI;
function getDeploymentOutput(DeployResourceGroup, armClient) {
    return new Promise(function (resolve, reject) {
        armClient.deployments.listByResourceGroup(DeployResourceGroup).then((deployName) => {
            if (deployName._response.parsedBody[0].name != undefined) {
                armClient.deployments.get(DeployResourceGroup, deployName._response.parsedBody[0].name).then(deployResults => {
                    if (deployResults.properties != undefined) {
                        if (deployResults.properties.outputs != undefined) {
                            var props = Object.keys(deployResults.properties.outputs), i = props.length, resArray = new Array(i);
                            while (i--) {
                                resArray[i] = [props[i], deployResults.properties.outputs[props[i]].value];
                            }
                            resolve(resArray);
                        }
                    }
                });
            }
        }).catch((err) => {
            reject(err);
        });
    });
}
exports.getDeploymentOutput = getDeploymentOutput;
// A helper method used to read a Node.js readable stream into string
function streamToString(readableStream) {
    return new Promise((resolve, reject) => {
        const chunks = [];
        readableStream.on("data", data => {
            chunks.push(data.toString());
        });
        readableStream.on("end", () => {
            resolve(chunks.join(""));
        });
        readableStream.on("error", reject);
    });
}
exports.streamToString = streamToString;
//# sourceMappingURL=resourceutil.js.map