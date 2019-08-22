import { DevTestLabsClient } from "@azure/arm-devtestlabs";
import { ResourceManagementClient } from "@azure/arm-resources";

export interface CreateCiTaskInputData {
    author: string,
    ciName: string,
    connectedServiceName: string,
    description: string,
    labId: string,
    labVmId: string,
    linuxOsState: string,
    osType: string,
    subscriptionId: string,
    windowsOsState: string
}

export interface CreateOrUpdateEnvTaskInputData {
    connectedServiceName: string,
    envId: string,
    envName: string,
    envTemplateLocationVariable: string,
    envTemplateSasTokenVariable: string,
    exportEnvTemplate: boolean,
    exportEnvTemplateLocation: string,
    labId: string,
    outputTemplateVariables: boolean,
    parametersFile: string,
    parameterOverrides: string,
    subscriptionId: string,
    templateFile: string,
    templateId: string
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