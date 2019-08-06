import { DevTestLabsClient, DevTestLabsModels, DevTestLabsMappers } from "@azure/arm-devtestlabs";
import { ResourceManagementClient, ResourceManagementModels, ResourceManagementMappers } from "@azure/arm-resources";
const fs = require('fs');

export function fromParametersFile(parametersFile: string): Promise<DevTestLabsModels.ArmTemplateParameterProperties[]> {

    return new Promise(function(resolve,reject){
        let envDeployParams : DevTestLabsModels.ArmTemplateParameterProperties[] = [];
        
        console.log('Parsing parameters file ', parametersFile);

        try {
            fs.stat(parametersFile,(err, stats) => {
                if (err) reject(err);
                if (stats.isFile()) {
                    fs.readFile(parametersFile,'utf8', function(err2, data){
                        if (err2) reject(err2);
                        let testparam = JSON.parse(data);
                        // @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
                        // Not supported in Node 6.x
                        // for (let [key, value] of Object.entries(testparam.parameters)) {

                        //     console.log('key,value', key, value);
                        //     let envDeployParam = Object.create(DevTestLabsMappers.ArmTemplateParameterProperties);
                        //     envDeployParam.name = key;
                        //     envDeployParam.value = value['value'].toString();
                        //     console.log('parameters: ', envDeployParam.name, ' : ', envDeployParam.value);
                        //     envDeployParams.push(envDeployParam);
            
                        // }
                        //@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
                        var props = Object.keys(testparam.parameters), i = props.length, resArray = new Array(i);
                        while(i--) {
                            resArray[i] = [props[i], testparam.parameters[props[i]]];
                            let envDeployParam = Object.create(DevTestLabsMappers.ArmTemplateParameterProperties);
                            envDeployParam.name = props[i];
                            envDeployParam.value = testparam.parameters[props[i]].value.toString();
                            envDeployParams.push(envDeployParam);
                        }

                        resolve(envDeployParams);
                    });
                }
                else {
                    resolve(envDeployParams);
                }
            }, reject);
        } catch (ex) {
            reject(ex);
        }
            
    })
   
}

export function addOverrideParameters(overrideParameters: string, existingParameters: DevTestLabsModels.ArmTemplateParameterProperties[] ) : DevTestLabsModels.ArmTemplateParameterProperties[] {

    let tempParam: DevTestLabsModels.ArmTemplateParameterProperties = Object.create(DevTestLabsMappers.ArmTemplateParameterProperties);
    
    if (overrideParameters.length === 0 ) {
        return existingParameters;
    }
    else {
        var parsedParam = overrideParameters.split(' ');
        parsedParam.forEach(value => {

            if (value.startsWith('-')) {
        
                if (tempParam.name == undefined) {                
                    tempParam.name = value.slice(1).toString().replace(/^"(.+(?="$))"$/, '$1');
                } else {
                    existingParameters = checkParamArray(tempParam,existingParameters);
                    tempParam = Object.create(DevTestLabsMappers.ArmTemplateParameterProperties);
                    tempParam.name = value.slice(1).toString().replace(/^"(.+(?="$))"$/, '$1');
                }                                

            } else {

                if (tempParam.value == undefined) {                
                    // remove double quote
                    tempParam.value = value.replace(/^"(.+(?="$))"$/, '$1');
                    // remove single quote
                    tempParam.value = tempParam.value.replace(/["']{1}/gi,"");

                } else {                
                    
                    //tempParam.value +=  (" " + value.replace(/^"(.+(?="$))"$/, '$1'));
                    tempParam.value +=  (" " + value);
                    // remove single quote
                    tempParam.value = tempParam.value.replace(/^"(.+(?="$))"$/, '$1');
                    // remove double quote
                    tempParam.value = tempParam.value.replace(/["']{1}/gi,"");
                }
            }
        })

        existingParameters = checkParamArray(tempParam,existingParameters);
    }
    return existingParameters;

}

export function getResourceNamesFromResourceURI(ResourceURI: string, ResourceName: string) : string {

    let first = ResourceURI.indexOf(ResourceName) + (ResourceName.length + 1);
    let last = ResourceURI.indexOf('/',first);

    if (last == -1) {
        last = ResourceURI.length;
    }
    
    let returnValue = ResourceURI.substring(first,last);

    return returnValue;
}

export function getDeploymentOutput(DeployResourceGroup: string, armClient: ResourceManagementClient): Promise<any[]> {

    return new Promise(function(resolve,reject) {
        
        armClient.deployments.listByResourceGroup(DeployResourceGroup).then((deployName)=>{
            if (deployName._response.parsedBody[0].name != undefined){
                armClient.deployments.get(DeployResourceGroup, deployName._response.parsedBody[0].name).then(deployResults =>{
                    if (deployResults.properties != undefined){
                        if (deployResults.properties.outputs != undefined){
                            var props = Object.keys(deployResults.properties.outputs), i = props.length, resArray = new Array(i);
                            while(i--) {
                                resArray[i] = [props[i], deployResults.properties.outputs[props[i]].value];
                            }
                            resolve(resArray);
                        }
                    }
                });
            }
        }).catch((err) =>{
            reject(err);
        });
    })
    
}

// A helper method used to read a Node.js readable stream into string
export function streamToString(readableStream) {
  return new Promise((resolve, reject) => {
    const chunks: any = [];
    readableStream.on("data", data => {
      chunks.push(data.toString());
    });
    readableStream.on("end", () => {
      resolve(chunks.join(""));
    });
    readableStream.on("error", reject);
  });
}

function checkParamArray(newParam: DevTestLabsModels.ArmTemplateParameterProperties, existingParameters: DevTestLabsModels.ArmTemplateParameterProperties[] ) : DevTestLabsModels.ArmTemplateParameterProperties[] {

    let addParam = true;

    existingParameters.forEach( property => {
        if (property.name == newParam.name) {
            property.value = newParam.value;
            addParam = false;
        } 
    });

    if (addParam) {
        existingParameters.push(newParam);
    }
    return existingParameters;
}