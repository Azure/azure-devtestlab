import '../../modules/task-utils/polyfill';

import tl = require('azure-pipelines-task-lib/task');
import * as msRestNodeAuth from "@azure/ms-rest-nodeauth";
import fs from 'fs';
import { DevTestLabsClient, DevTestLabsModels, DevTestLabsMappers } from "@azure/arm-devtestlabs";
import { ResourceManagementClient, ResourceManagementModels, ResourceManagementMappers } from "@azure/arm-resources";
import util = require('./operations/resourceutil');

async function run() {
    try {
        
        const ConnectedServiceName: string = tl.getInput('ConnectedServiceName', true);
        const LabId: string = tl.getInput('LabId', false);
        const EnvironmentId: string = tl.getInput('EnvironmentId',false);
        const SourceTemplateFile: string = tl.getInput('SourceTemplate',true);
        const SourceParameterFile: string = tl.getInput('SourceTemplateParameterFile',false);
        const SourceParameterOverrides: string = tl.getInput('SourceTemplateParameterOverrides', false);
        const ExportEnvironmentTemplate: boolean = tl.getBoolInput('ExportEnvironmentTemplate', false);
        const ExportEnvironmentTemplateLocation: string = tl.getInput('ExportEnvironmentTemplateLocation', false);
        // Get connection information

        const subscriptionId = tl.getEndpointDataParameter(ConnectedServiceName,'SubscriptionId', true);
        const spId = tl.getEndpointAuthorizationParameter(ConnectedServiceName, "ServicePrincipalId",false);
        const spKey = tl.getEndpointAuthorizationParameter(ConnectedServiceName, "ServicePrincipalKey",false);
        const tenantId = tl.getEndpointAuthorizationParameter(ConnectedServiceName, "TenantId",false);

        // Create Azure Clients
        var client : DevTestLabsClient;
        var armClient : ResourceManagementClient;

        //Connect to DTL client
        msRestNodeAuth.loginWithServicePrincipalSecret(
            spId, spKey, tenantId, (err : Error, credentials : any ) => {
            if (err) {
                console.log(err);
                return;
            }
            // New Clients
            client = new DevTestLabsClient(credentials, subscriptionId);
            armClient = new ResourceManagementClient(credentials,subscriptionId);
            

            let labname = util.getResourceNamesFromResourceURI(LabId,'labs');
            let labrg = util.getResourceNamesFromResourceURI(LabId,'resourceGroups');
            let envRg = '';
            let envName = util.getResourceNamesFromResourceURI(EnvironmentId,'environments');
            //console.log('EnvID: ', EnvironmentId);
            console.log("Updating Environment ", envName);


            let envDeployProp: ResourceManagementModels.DeploymentProperties = Object.create(ResourceManagementMappers.DeploymentProperties);
            let envDeploy: ResourceManagementModels.Deployment = Object.create(ResourceManagementMappers.Deployment);

            var getEnvironPromise = client.environments.list(labrg,labname, '@all').then((result) =>{

                result.forEach(element => {
                    if (element.name != undefined) {
                        if (element.name.toLocaleLowerCase() == envName) {
                            if (element.resourceGroupId != undefined) {
                                envRg = util.getResourceNamesFromResourceURI(element.resourceGroupId, 'resourcegroups');
                            }
                        }
                    }
                });

                fs.stat(SourceParameterFile,(err, stats) => {
                    if (err) console.log('Failed on the Source Parameter file', err);
                    if (stats.isFile()) {
                        var promiseParams = util.fromParametersFile(SourceParameterFile).then(value => {
                            if (SourceParameterOverrides == null ||
                                SourceParameterOverrides == undefined ||
                                SourceParameterOverrides.length == 0 ){
                                    envDeployProp.parameters = value;
                                    util.deployResource(SourceTemplateFile,envDeployProp.parameters,armClient,envRg, ExportEnvironmentTemplate,ExportEnvironmentTemplateLocation).then((result) =>{
                                        if (result.properties.provisioningState == 'Succeeded') {
                                            tl.setResult(tl.TaskResult.Succeeded, result.id);
                                        }else {
                                            tl.setResult(tl.TaskResult.Failed, result);
                                        }
                                    });
                            } else {
                                envDeployProp.parameters = util.addOverrideParameters(SourceParameterOverrides,value);
                                util.deployResource(SourceTemplateFile,envDeployProp.parameters,armClient,envRg, ExportEnvironmentTemplate,ExportEnvironmentTemplateLocation).then((result) =>{
                                    if (result.properties.provisioningState == 'Succeeded') {
                                        tl.setResult(tl.TaskResult.Succeeded, result.id);
                                    }else {
                                        tl.setResult(tl.TaskResult.Failed, result);
                                    }
                                });
                            }
                        });
                    }
                    else {
                        envDeployProp.parameters = util.newOverrideParameters(SourceParameterOverrides);
                        util.deployResource(SourceTemplateFile,envDeployProp.parameters,armClient,envRg, ExportEnvironmentTemplate,ExportEnvironmentTemplateLocation).then((result) =>{
                            if (result.properties.provisioningState == 'Succeeded') {
                                tl.setResult(tl.TaskResult.Succeeded, result.id);
                            }else {
                                tl.setResult(tl.TaskResult.Failed, result);
                            }
                        });

                    }
                }); //fs.stat
            }); //get env list
        });

                
    }

    catch (err) {
        tl.setResult(tl.TaskResult.Failed, err.message);
    }
}


run();
