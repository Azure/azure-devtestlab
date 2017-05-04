import * as request from 'superagent';

const baseUrl = 'https://management.azure.com';
const dtlApiVersion = '2016-05-15';
const computeApiVersion = '2016-03-30';
const jwtKey = 'access_token';
const subscriptionsApiVersion = '2015-11-01';
    
const labUri = (lab: Dtl.Lab) => {
    return `/subscriptions/${lab.subscriptionId}/resourcegroups/${lab.resourceGroupName}` +
           `/providers/Microsoft.DevTestLab/labs/${lab.name}`;
};

export module Dtl {

    async function getRequest(url: string, apiVersion: string): Promise<request.Response> {
        return await request
            .get(url)
            .query({ 'api-version': apiVersion })
            .set('Authorization', `Bearer ${sessionStorage.getItem(jwtKey)}`);
    }

    async function postRequest(url: string, apiVersion: string, data?: Object): Promise<request.Response> {
        return await request
            .post(url)
            .send(data)
            .query({ 'api-version': apiVersion })
            .set('Authorization', `Bearer ${sessionStorage.getItem(jwtKey)}`);
    }

    export async function addVmAsync(lab: Dtl.Lab, vm: Dtl.LabVirtualMachine): Promise<boolean> {
        const url = `${baseUrl}${labUri(lab)}/createEnvironment`;
        const res = await postRequest(url, dtlApiVersion, vm);

        return res.status < 400;
    }

    export async function getUserIdAsync(lab: Dtl.Lab): Promise<string> {
        const url = `${baseUrl}${labUri(lab)}/users/@me`;
        const res = await getRequest(url, dtlApiVersion);
        return res.body.name;
    }

    export async function getVirtualNetworksAsync(lab: Dtl.Lab): Promise<Array<LabVirtualNetwork>> {
        const url = `${baseUrl}${labUri(lab)}/virtualnetworks`;
        const res = await getRequest(url, dtlApiVersion);
        let networks = Array<LabVirtualNetwork>();
        for (const network of res.body.value) {
            networks.push({
                allowedSubnets: network.properties.allowedSubnets,
                id: network.id,
                name: network.name
            });
        }

        return networks;
    }

    export async function getVmsAsync(lab: Dtl.Lab, ownerObjectId?: string): Promise<Array<Dtl.Vm>> {
        const url = `${baseUrl}${labUri(lab)}/virtualmachines`;
        let req = request
            .get(url)
            .query(`api-version=${dtlApiVersion}&$expand=Properties($expand=ComputeVm,NetworkInterface)`)
            .set('Authorization', `Bearer ${sessionStorage.getItem(jwtKey)}`);
        if (ownerObjectId ) {
            req.query(`$filter=tolower(Properties/OwnerObjectId)%20eq%20tolower('${ownerObjectId}')`);
        }

        const res = await req;
        let vms: Array<Vm> = [];
        for (const vm of res.body.value) {
            let state: string = vm.properties.provisioningState;
            if (state === 'Succeeded') {
                const powerState = vm.properties
                    .computeVm
                    .statuses
                    .find(status => status.code.startsWith('PowerState'));

                if (powerState) {
                    state = powerState.displayStatus.replace('VM ', '');
                }
            }
            // Some labs do not have fqdn set. 
            const networkInterface = vm.properties.networkInterface;
            const address = vm.properties.fqdn || networkInterface.publicIpAddress
                            || networkInterface.privateIpAddress;

            vms.push({
                fqdn: address,
                name: vm.name,
                os: vm.properties.osType,
                id: vm.id,
                createdByUser: vm.properties.createdByUser,
                computeId: vm.properties.computeId,
                state: state
            });
        }

        return vms;
    }

    export async function getClaimableVmsAsync(lab: Dtl.Lab): Promise<Array<Dtl.Vm>> {
        const url = `${baseUrl}${labUri(lab)}/virtualmachines`;
        let req = request
            .get(url)
            .query(`api-version=${dtlApiVersion}&$expand=Properties($expand=ComputeVm,NetworkInterface,` +
                   `ApplicableSchedule)&$filter=properties/allowClaim`)
            .set('Authorization', `Bearer ${sessionStorage.getItem(jwtKey)}`);

        const res = await req;
        let vms: Array<Vm> = [];
        for (const vm of res.body.value) {
            let state: string = vm.properties.provisioningState;
            if (state === 'Succeeded') {
                const powerState = vm.properties
                    .computeVm
                    .statuses
                    .find(status => status.code.startsWith('PowerState'));

                if (powerState) {
                    state = powerState.displayStatus.replace('VM ', '');
                }
            }
            const networkInterface = vm.properties.networkInterface;
            const address = vm.properties.fqdn || networkInterface.publicIpAddress
                            || networkInterface.privateIpAddress;

            vms.push({
                fqdn: address,
                name: vm.name,
                os: vm.properties.osType,
                id: vm.id,
                createdByUser: vm.properties.createdByUser,
                computeId: vm.properties.computeId,
                state: state
            });
        }
        return vms;      
    }

    export function claimAnyVm(lab: Dtl.Lab): void {
        const url = `${baseUrl}${labUri(lab)}/claimAnyVm`;
        postRequest(url, dtlApiVersion);
    }
    
    export function claimVm(vm: Dtl.Vm): void {
        const url = `${baseUrl}${vm.id}/claim`;
        postRequest(url, dtlApiVersion);
    }
    
    export function startVm(vm: Dtl.Vm): void {
        const url = `${baseUrl}${vm.id}/start`;
        postRequest(url, dtlApiVersion);
    }

    export function stopVm(vm: Dtl.Vm): void {
        const url = `${baseUrl}${vm.id}/stop`;
        postRequest(url, dtlApiVersion);
    }

    export function deleteVm(vm: Dtl.Vm): void {
        const url = `${baseUrl}${vm.id}`;
        request
            .delete(url)
            .query(`api-version=${dtlApiVersion}`)
            .set('Authorization', `Bearer ${sessionStorage.getItem(jwtKey)}`)
            .end();
    }

    export async function getCustomImagesAsync(lab: Dtl.Lab): Promise<Array<Dtl.Image>> {
        const url = `${baseUrl}${labUri(lab)}/customImages`;
        const res = await getRequest(url, dtlApiVersion);
        let images = Array<Dtl.Image>();
        for (const image of res.body.value) {
            images.push({
                name: image.name,
                author: image.properties.author,
                ostype: image.properties.vhd.osType,
                type: 'Custom image',
                customImageId: image.id,
                id: image.id
            });
        }

        return images;
    }

    export async function getGalleryImagesAsync(lab: Dtl.Lab): Promise<Array<Dtl.Image>> {
        const url = `${baseUrl}${labUri(lab)}/galleryImages`;
        const res = await getRequest(url, dtlApiVersion);
        let images = Array<Dtl.Image>();
        for (const image of res.body.value) {
            images.push({
                name: image.name,
                author: image.properties.author,
                ostype: image.properties.imageReference.osType,
                imageReference: image.properties.imageReference,
                type: 'Gallery image',
                id: image.id
            });
        }

        return images;
    }

    export async function getFormulasAsync(lab: Dtl.Lab): Promise<Array<Dtl.Image>> {
        const url = `${baseUrl}${labUri(lab)}/formulas`;
        const res = await getRequest(url, dtlApiVersion);
        let images = Array<Dtl.Image>();
    
        for (const image of res.body.value) {
             // Formula's will have either CustomImageId or GalleryReference set and the other has to be set null. 
             let customImageId;
             if (image.properties.formulaContent.properties.customImageId) {
                  customImageId = `${labUri(lab)}${image.properties.formulaContent.properties.customImageId}`;
             }
             
             let galleryImageReference = image.properties.formulaContent.properties.imageReference;

             let formulaContent = image.properties.formulaContent;
             if (!formulaContent || !formulaContent.properties) {
                 continue;
             }
            
             if (formulaContent.properties.artifacts) {
                for ( let artifact of formulaContent.properties.artifacts) {
                    artifact.artifactId = `${labUri(lab)}${artifact.artifactId}`;
                }
             }
             
             images.push({
                name: image.name,
                author: image.properties.author,
                ostype: image.properties.osType,
                formulaContent: formulaContent, 
                customImageId: customImageId,
                imageReference: galleryImageReference,
                type: 'Formula',
                id: image.id
            });
        }

        return images;
    }

    export async function getArtifactDetailsAndParametersAsync (artifact: Dtl.Artifact): Promise<Dtl.Artifact> {
        const url = `${baseUrl}${artifact.artifactId}`;
        const res = await getRequest(url, dtlApiVersion);
        const responseArtifact = res.body;
        let detailedArtifact: Dtl.Artifact = {
            artifactId: responseArtifact.id,
            name: responseArtifact.name,
            title: responseArtifact.properties.title
        };
        
        let parameters = Array<Parameter>();
        Object.keys(responseArtifact.properties.parameters).forEach((paramName) => {
            const val = responseArtifact.properties.parameters[paramName];
             // We need to overwrite the default values from Forumla
            const formulaParameter  = artifact.parameters.find(param => (param.name === paramName));
            
            parameters.push ({
                name: paramName,
                value: formulaParameter ? formulaParameter.value : val.defaultValue, 
                displayName: val.displayName,
                type: val.type,
                allowedValues: val.allowedValues,
                controlType: val.controlType,
                allowEmpty: val.allowEmpty || true
            });
        });

        detailedArtifact.parameters = parameters;
        return detailedArtifact;
    }
    
    export async function getLabsAsync(): Promise<Lab[]> {
        const subscriptionIds = await getSubscriptionsAsync();
        const labs = await Promise.all(subscriptionIds.map(id => {
            return getLabsForSubscriptionAsync(id);
        }));

        return [].concat.apply([], labs);
    }

    export async function getLabsForSubscriptionAsync(subscriptionId: string): Promise<Lab[]> {
        const resGroupName = /^\/subscriptions\/.*\/resourcegroups\/(.*)\/providers\/microsoft\.devtestlab\/labs\/.*$/;
        const url = `${baseUrl}/subscriptions/${subscriptionId}/providers/Microsoft.DevTestLab/labs`;
        let res = await getRequest(url, dtlApiVersion);
        let labs: Lab[] = [];
        for (const lab of res.body.value) {
            labs.push({
                name: lab.name,
                resourceGroupName: lab.id.match(resGroupName)[1],
                subscriptionId: subscriptionId,
                location: lab.location
            });
        }

        return labs;
    }

    export async function getSubscriptionsAsync(): Promise<Array<string>> {
        const url = `${baseUrl}/subscriptions`;
        let res = await getRequest(url, subscriptionsApiVersion);
        let subscriptionIds: Array<string> = [];
        for (const subscription of res.body.value) {
            subscriptionIds.push(subscription.subscriptionId);
        }

        return subscriptionIds;
    }

    export async function getVmSizesAsync(lab: Dtl.Lab, ownerObjectId?: string): Promise<Array<string>> {
        let url = `${baseUrl}${labUri(lab)}/policySets/default/policies/AllowedVmSizesInLab`;
        let vmSizes = Array<string>();
        try {
            let res = await getRequest(url, dtlApiVersion);
            if (res.body.properties) {
                vmSizes = JSON.parse(res.body.properties.threshold);
            }
       } catch (err) {
           if (err.status === 404) {
                // This means that there is no Size policy and we have to fetch all sizes from compute. 
                url = `${baseUrl}/subscriptions/${lab.subscriptionId}/providers/Microsoft.Compute/locations/` +
                    `${lab.location}/vmSizes`;
                const res = await getRequest(url, computeApiVersion);
                for (const vmSize of res.body.value) {
                    vmSizes.push(vmSize.name);
                }
           }
       } finally {
           return vmSizes;
       }
    }

    export async function evaluatePoliciesAsync(lab: Dtl.Lab, policies: Dtl.Policy[]): Promise<PolicyResult> {
        const url = `${baseUrl}${labUri(lab)}/policySets/default/evaluatePolicies`;
        
        const policiesObject = {policies: policies};
        const res = await postRequest(url, dtlApiVersion, policiesObject);
        let results = res.body.results;
        for (const result of results) {
            if (result.hasError) {
                const policyResult: PolicyResult = {
                    isError: true,
                    errorMessage: result.policyViolations[0].message
                };
                return policyResult;
            }
        }
    }

    export interface Policy {
        factName: string;
        factData?: string;
        valueOffset?: string;
    }

    export interface PolicyResult {
        isError: boolean;
        errorMessage: string;
    }

   export interface Image {
        author: string;
        name: string;
        ostype: string;
        type: string;
        imageReference?: string;
        customImageId?: string;
        formulaContent?: FormulaContent;
        id?: string;
    }

    export interface Lab {
        name: string;
        resourceGroupName: string;
        subscriptionId: string;
        location: string;
    }

    export interface Artifact {
        artifactId?: string;
        id?: string;
        title?: string;
        name?: string;
        parameters?: Parameter[];
    }

    export interface Parameter {
        name?: string;
        value?: string;
        type?: string;
        controlType?: string;
        displayName?: string;
        defaultValue?: string;
        allowedValues?: string[];
        allowEmpty?: boolean;
    }

    export interface LabVirtualMachine {
        location: string;
        name: string;
        properties: LabVirtualMachineProperties;
    }

    export interface LabVirtualMachineProperties {
        allowClaim: boolean;
        customImageId?: string;
        galleryImageReference?: string;
        artifacts?: Artifact[];
        disallowPublicIpAddress: boolean;
        isAuthenticationWithSshKey: boolean;
        labSubnetName: string;
        labVirtualNetworkId: string;
        notes: string;
        password?: string;
        size: string;
        sshKey?: string;
        storageType: string;
        userName?: string;
    }

    export interface FormulaContent {
        properties: FormulaContentProperties;
        id: string;
        name: string;
    }

    export interface FormulaContentProperties {
        allowClaim?: boolean;
        notes?: string;
        osType?: string;
        size?: string;
        userName?: string;
        password?: string;
        sshKey?: string;
        isAuthenticationWithSshKey?: boolean;
        fqdn?: string;
        labSubnetName?: string;
        labVirtualNetworkId?: string;
        disallowPublicIpAddress?: boolean;
        artifacts?: Artifact[];
    }

    export interface LabVirtualNetwork {
        allowedSubnets: LabSubnet[];
        id: string;
        name: string;
    }

    export interface LabSubnet {
        labSubnetName: string;
        resourceId: string;
        allowPublicIp: string;
    }

    export interface Vm {
        fqdn: string;
        name: string;
        os: string;
        id: string;
        computeId: string;
        createdByUser: string;
        state: string;
    }
}
