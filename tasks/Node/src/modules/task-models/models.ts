import { DevTestLabsClient } from "@azure/arm-devtestlabs";
import { ResourceManagementClient } from "@azure/arm-resources";

export interface CreateEnvTaskInputData {
    armTemplateId: string,
    connectedServiceName: string,
    envName: string,
    envTemplateLocationVariable: string,
    envTemplateSasTokenVariable: string,
    exportEnvTemplate: boolean,
    exportEnvTemplateLocation: string,
    labId: string,
    parametersFile: string,
    parameterOverrides: string,
    subscriptionId: string,
    templateOutputVariables: boolean
}

export interface CreateVmTaskInputData {
    appendRetryNumberToVmName: boolean;
    connectedServiceName: string;
    deleteDeployment: boolean;
    deleteLabVm: boolean;
    failOnArtifactError: boolean;
    labId: string;
    parameterOverrides: string;
    parametersFile: string;
    retryCount: number;
    retryOnFailure: boolean;
    subscriptionId: string;
    templateFile: string;
    vmName: string;
    waitMinutes: number;
}

export interface TaskClients {
    arm: ResourceManagementClient;
    dtl: DevTestLabsClient;
}