import { ResourceManagementClient, ResourceManagementModels, ResourceManagementMappers } from "@azure/arm-resources";
import { DevTestLabsClient, DevTestLabsModels, DevTestLabsMappers } from "@azure/arm-devtestlabs";
import tl = require('azure-pipelines-task-lib/task');
const fs = require('fs');
const vmNameParameter = 'newVMName';

// Get the individual resource information from the URI based on the preceding resource type name ie ResourceGroup
export function getResourceNamesFromResourceURI(ResourceURI: string, ResourceName: string) : string {

    let first = ResourceURI.indexOf(ResourceName) + (ResourceName.length + 1);
    let last = ResourceURI.indexOf('/',first);

    if (last == -1) {
        last = ResourceURI.length;
    }
    
    let returnValue = ResourceURI.substring(first,last);

    return returnValue;
}

// Get the resource output
export function getDeploymentOutput(DeployResourceGroup: string, armClient: ResourceManagementClient): Promise<any[]> {

    return new Promise(function(resolve,reject) {
        
        armClient.deployments.listByResourceGroup(DeployResourceGroup).then((deployName)=>{
            if (deployName._response.parsedBody[0].name != undefined){
                armClient.deployments.get(DeployResourceGroup, deployName._response.parsedBody[0].name).then(deployResults =>{
                    if (deployResults.properties != undefined){
                        if (deployResults.properties.outputs != undefined){
                            var props = Object.keys(deployResults.properties.outputs), i = props.length, resArray = new Array(i);
                            while(i--) {
                                resArray[i] = [props[i], deployResults.properties.outputs[props[i]].Value];
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

// core deploy VM function which calls itself to handle the retry logic.
function deployVM(dtlClient: DevTestLabsClient, armClient: ResourceManagementClient, labRg: string, labName: string, deploymentName:string, vmDeploy: ResourceManagementModels.Deployment, RetryOnFailure: boolean, FailOnArtifactError: boolean, DeleteFailedDeploymentBeforeRetry: boolean, currentRetryCount: number, RetryCount: number, DeleteFailedLabVMBeforeRetry : boolean, AppendRetryNumberToVMName: boolean): Promise<any>{
    return new Promise(function(resolve,reject){
        
        console.log('Current # of VM creations / Maximum retries: ' + currentRetryCount.toString() + '/' + RetryCount.toString());
        if (currentRetryCount > RetryCount){
            if (RetryCount == 1) {
                reject('Unable to create VM.');
            } else {
                reject('Maximum number to retries exceeded.');
            }

        } else {
            armClient.deployments.createOrUpdate(labRg,deploymentName,vmDeploy).then((resultsCU) =>{
                currentRetryCount++;
                // Get the results from the creation.
                if (resultsCU._response != undefined){
                    // If the creation succeeds.
                    if (resultsCU._response.status === 200) {

                        console.log('DevTest Lab VM created, checking artifacts.');
                        
                        if (resultsCU.properties != undefined) {
                            // Check the artifacts status
                            if (FailOnArtifactError) {
                                
                                // Parse the text to the artifact status
                                var responseBody = JSON.parse(resultsCU._response.bodyAsText);
                                let responseStatus = JSON.stringify(responseBody.properties.outputResources).slice(8,-3);
                                checkVMArtifact(dtlClient,labRg,labName, getResourceNamesFromResourceURI(responseStatus,'virtualmachines')).then((resultVMArt) =>{
                                    console.log('VM Artifact results: ', resultVMArt);
                                    // If the artifacts failed...
                                    if (!resultVMArt) {
                                        // and the we have retires
                                        if (currentRetryCount <= RetryCount){
                                            console.log('VM Artifacts failed to deploy.');

                                            // Clean up the deployment and VM resources 
                                            cleanupExistingResources (dtlClient, armClient, labRg, labName, deploymentName, vmDeploy.properties.parameters[vmNameParameter].Value, DeleteFailedDeploymentBeforeRetry, DeleteFailedLabVMBeforeRetry).then((cleanupResult) =>{
                                                // Append count to vm name is user has set AppendRetryNumberToVMName to true.
                                                vmDeploy.properties.parameters[vmNameParameter].Value = appendRetryCountToVmName(AppendRetryNumberToVMName,vmDeploy.properties.parameters[vmNameParameter].Value, currentRetryCount);
                                                // call the function again to retry VM deploy
                                                console.log('VM failed to deploy, retrying ', currentRetryCount.toString());
                                                deployVM(dtlClient, armClient,labRg,labName,deploymentName,vmDeploy,RetryOnFailure, FailOnArtifactError, DeleteFailedDeploymentBeforeRetry,currentRetryCount,RetryCount, DeleteFailedLabVMBeforeRetry, AppendRetryNumberToVMName).then((resultIDVm)=>{
                                                    if (resultIDVm._response != undefined) {
                                                        if (resultIDVm._response.status === 200) {
                                                            resolve(resultIDVm);
                                                        } else
                                                        {
                                                            reject(resultIDVm);
                                                        }
                                                    }
                                                    else {
                                                        if (resultIDVm)
                                                        reject(resultIDVm);
                                                    }
                                                }).catch((err) =>{
                                                    reject('Unknown deployment error: ' + err);
                                                });
                                            });
                                        } else {
                                            // Exceeded retry count.
                                            reject(resultsCU);
                                        }
                                    } else {
                                        // Passed create and artifacts.
                                        resolve(resultsCU);
                                    }
                                }).catch((err) =>{
                                    reject('Unknown artifact checking error: ' + err);
                                });                            

                            } else {
                                // Passed create and don't need to check artifacts.
                                resolve(resultsCU);
                            }
                        }
                    } else {
                        console.log('DevTest Lab VM failed creation: retrying ' + currentRetryCount.toString());
                        // Clean up the deployment and VM resources 
                        cleanupExistingResources (dtlClient, armClient, labRg, labName, deploymentName, vmDeploy.properties.parameters[vmNameParameter].Value, DeleteFailedDeploymentBeforeRetry, DeleteFailedLabVMBeforeRetry).then((cleanupResult) =>{
                            vmDeploy.properties.parameters[vmNameParameter].Value = appendRetryCountToVmName(AppendRetryNumberToVMName,vmDeploy.properties.parameters[vmNameParameter].Value, currentRetryCount);
                            console.log('VM failed to deploy, retrying ', currentRetryCount.toString());
                            deployVM(dtlClient, armClient,labRg,labName,deploymentName,vmDeploy,RetryOnFailure, FailOnArtifactError, DeleteFailedDeploymentBeforeRetry,currentRetryCount,RetryCount, DeleteFailedLabVMBeforeRetry, AppendRetryNumberToVMName).then((resultRDvm)=>{
                                if (resultRDvm._response != undefined) {
                                    if (resultRDvm._response.status === 200) {
                                        resolve(resultRDvm);
                                    } else
                                    {
                                        reject(resultRDvm);
                                    }
                                } else {
                                    reject(resultRDvm);
                                }
                            }).catch((err) =>{
                                reject('Unknown deployment error:' + err);
                            });
                        });
                    }
                } else {
                     reject('Missing deployment results.');
                }
            }).catch((err) =>{
                console.log('Unable to create VM: ', err.bodyAsText);

                currentRetryCount++;
                cleanupExistingResources (dtlClient, armClient, labRg, labName, deploymentName, vmDeploy.properties.parameters[vmNameParameter].Value, DeleteFailedDeploymentBeforeRetry, DeleteFailedLabVMBeforeRetry).then((cleanupResult) =>{
                    vmDeploy.properties.parameters[vmNameParameter].Value = appendRetryCountToVmName(AppendRetryNumberToVMName,vmDeploy.properties.parameters[vmNameParameter].Value, currentRetryCount);
                    console.log('VM failed to deploy, retrying ', currentRetryCount.toString());
                    deployVM(dtlClient, armClient,labRg,labName,deploymentName,vmDeploy,RetryOnFailure, FailOnArtifactError, DeleteFailedDeploymentBeforeRetry,currentRetryCount,RetryCount, DeleteFailedLabVMBeforeRetry, AppendRetryNumberToVMName).then((resultEDvm)=>{
                        if (resultEDvm._response != undefined) {
                            if (resultEDvm._response.status === 200) {
                                resolve(resultEDvm);
                            } else
                            {
                                reject(resultEDvm);
                            }
                        } else {
                            reject(resultEDvm);
                        }
                    }).catch((err) =>{
                        reject('Failed to create VM: ' + err);
                    });
                });
            });
        }
    })

}
// Check if the VM artifacts were deployed 
function checkVMArtifact(dtlClient: DevTestLabsClient, labRg: string, labName: string, vmName: string ): Promise<any> {
    return new Promise(function(resolve,reject){
        console.log('Getting VM results.');
        dtlClient.virtualMachines.get(labRg, labName, vmName).then((returnedVM) =>{
            if (returnedVM.artifactDeploymentStatus != undefined) {
                console.log('VM Artifact state: ', returnedVM.artifactDeploymentStatus.deploymentStatus);
                if (returnedVM.artifactDeploymentStatus.deploymentStatus == 'Succeeded') {
                    resolve(true);
                } else
                {
                    resolve(false);
                }
            } else {
                console.log('No VM Artifacts defined.');
                resolve(true);
            }
        }).catch((err) =>{
            reject(err);
        });
    });
}
// Remove DTL VM, always returns true.
function deleteVM(dtlClient: DevTestLabsClient, labRg: string, labName: string, vmName: string ): Promise<any> {
    return new Promise(function(resolve,reject){
        dtlClient.virtualMachines.deleteMethod(labRg, labName, vmName).then((returnedVM) =>{
            if (returnedVM.status == 'Succeeded') {
                resolve('VM ' + vmName + ' successfully removed.');
            } else {
                resolve('VM ' + vmName + ' failed to be removed.');
            }
        }).catch((err) =>{
            reject(err);
        });
    });
}
// Remove the deployment and the VM based on the parameters passed in.
function cleanupExistingResources (dtlClient: DevTestLabsClient, armClient: ResourceManagementClient, labRg: string, labName: string, deploymentName:string, vmName: string, DeleteFailedDeploymentBeforeRetry: boolean, DeleteFailedLabVMBeforeRetry : boolean): Promise<any>{
    return new Promise(function(resolve){
        console.log('Removing failed resources.');
            if (DeleteFailedDeploymentBeforeRetry) {
                console.log('Removing failed deployment ', deploymentName);
                armClient.deployments.deleteMethod(labRg,deploymentName).then((deleteDeployResult) =>{
                    console.log('Removed failed deployment ', deploymentName);
                    resolve(true);
                }).catch((err) =>{
                    console.log('Unable to remove failed deployment: ', err);
                    resolve(true);
                });
            }
            if (DeleteFailedLabVMBeforeRetry) {
                console.log('Removing failed VM creation ', vmName);
                deleteVM(dtlClient, labRg, labName,vmName).then((delVMResult) =>{
                    console.log('Removed failed VM creation ', vmName);
                    resolve(true);
                }).catch((err) =>{
                    resolve(true);
                });
            }
    });
}

// Append retry number to the VMName
function appendRetryCountToVmName(AppendRetryNumberToVMName: boolean, currentVmName: string, currentRetryCount: number): string {
    let tempName: string = currentVmName;

    if (AppendRetryNumberToVMName) {
        if (currentVmName.endsWith((currentRetryCount - 1).toString())) {
            tempName = currentVmName.slice(0,-1);
        } 
        tempName += currentRetryCount.toString();
    }
    console.log('New VM Name: ', tempName);
    return tempName;
}