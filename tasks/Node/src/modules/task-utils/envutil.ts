import fs from 'fs';

import * as tl from 'azure-pipelines-task-lib/task';
import * as deployutil from '../../modules/task-utils/deployutil';
import * as resutil from '../../modules/task-utils/resourceutil';

import { Aborter, AnonymousCredential, BlobURL, Models, StorageURL } from "@azure/storage-blob";
import { ResourceManagementClient } from "@azure/arm-resources";

export async function exportEnvironmentTemplate(exportEnvTemplateLocation: string, envTemplateLocation: string, envTemplateSasToken: string): Promise<any> {
    if (!envTemplateLocation || !envTemplateSasToken) {
        throw 'Missing Environment Location or Environment SAS Token as outputs variables.';
    }

    console.log('Exporting environment template.');

    const templateFileName = 'azuredeploy.json';
    const credential = new AnonymousCredential();
    const pipeline = StorageURL.newPipeline(credential);

    const blobUrl = new BlobURL(`${envTemplateLocation}/${templateFileName}${envTemplateSasToken}`, pipeline);
    const response: Models.BlobDownloadResponse = await blobUrl.download(Aborter.none, 0);

    if (response && response.readableStreamBody) {
        tl.mkdirP(exportEnvTemplateLocation);
        const templateFileLocation = `${exportEnvTemplateLocation}/${templateFileName}`;
        const data = response.readableStreamBody.read().toString();
        fs.writeFileSync(templateFileLocation, data, 'utf8');
        console.log(`Environment template has been exported to file: ${templateFileLocation}`);
    }
    
    console.log('Environment template has been exported successfully.');
}

export async function setOutputVariables(armClient: ResourceManagementClient, envRgId: string, template: any): Promise<any> {
    if (template && template.properties && template.properties.contents && template.properties.contents.outputs) {
        const envRgName: string = resutil.getResourceName(envRgId, 'resourcegroups');
        const templateOutputs: any = template.properties.contents.outputs;
        const deploymentOutput: any[] = await deployutil.getDeploymentOutput(armClient, envRgName);
        deploymentOutput.forEach((element: any[]) => {
            const name: string = element[0];
            const value: string = element[1];
            const key = Object.keys(templateOutputs).find(key => key.toLowerCase() === name.toLowerCase());
            if (key) {
                const type: string = templateOutputs[key].type;
                if (type) {
                    const secret: boolean = type.toLowerCase().indexOf('secure') !== -1;
                    tl.setVariable(name, value, secret);
                }
            }
        });
    }
}