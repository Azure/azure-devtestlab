<##################################################################################################

    Description
    ===========

    Create a Lab VM using the provided ARM template.

    Pre-Requisites
    ==============

    - Ensure the provided ARM template has a parameter named "labName".

    Coming soon / planned work
    ==========================

    - N/A.

##################################################################################################>
#
# Parameters to this script file.
#

[CmdletBinding()]
param(
    [string] $ConnectedServiceName,
    [string] $LabId,
    [string] $TemplateName,
    [string] $TemplateParameters,
    [string] $OutputResourceId,
    [string] $FailOnArtifactError,
    [string] $RetryOnFailure,
    [string] $RetryCount,
    [string] $DeleteFailedLabVMBeforeRetry,
    [string] $DeleteFailedDeploymentBeforeRetry,
    [string] $AppendRetryNumberToVMName,
    [string] $WaitMinutesForApplyArtifacts
)

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

###################################################################################################
#
# Functions used in this script.
#

.".\task-funcs.ps1"

###################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Error "`n$message"
    }
}

###################################################################################################
#
# Main execution block.
#

# Preparing variable that will hold the resource identifier of the lab virtual machine.
[string] $resourceId = ''

try
{
    Write-Host 'Starting Azure DevTest Labs Create VM Task'

    Show-InputParameters

    $lab = Get-DtlLab -LabId "$LabId"
    $resourceGroupName = $lab.ResourceGroupName
    if (-not $TemplateParameters.Contains('-labName'))
    {
        $TemplateParameters = "-labName '$($Lab.Name)' $TemplateParameters"
    }
    $templateParameterObject = ConvertTo-TemplateParameterObject -TemplateParameters "$TemplateParameters"
    $baseVmName = $templateParameterObject.Item('newVMName')

    $retry = ConvertTo-Bool -Value $RetryOnFailure
    if (-not $retry)
    {
        $RetryCount = '0'
    }

    [int] $count = 1 + (ConvertTo-Int -Value $RetryCount)
    for ($i = 1; $i -le $count; $i++)
    {
        Test-InputParameters -TemplateParameterObject $templateParameterObject

        try
        {
            $deploymentName = "Dtl$([Guid]::NewGuid().ToString().Replace('-', ''))"

            $result = Invoke-AzureDtlTask -DeploymentName $deploymentName -ResourceGroupName $resourceGroupName -TemplateName "$TemplateName" -TemplateParameterObject $templateParameterObject

            $resourceId = Get-DeploymentTargetResourceId -DeploymentName $result.DeploymentName -ResourceGroupName $result.ResourceGroupName

            Wait-ApplyArtifacts -ResourceId $resourceId -WaitMinutes $WaitMinutesForApplyArtifacts

            Test-ArtifactStatus -ResourceId $resourceId -TemplateName "$TemplateName" -Fail $FailOnArtifactError

            break
        }
        catch
        {
            if ($i -eq $count)
            {
                throw $Error[0]
            }
            else
            {
                # Reset $resourceId to ensure we don't mistakenly return a previously invalid value in case of a subsequent retry error.
                $resourceId = ''

                Write-Host "##vso[task.logissue type=warning;]A deployment failure occured. Retrying deployment (attempt $i of $($count - 1))"
                Remove-FailedResourcesBeforeRetry -DeploymentName $deploymentName -ResourceGroupName $resourceGroupName -DeleteLabVM $DeleteFailedLabVMBeforeRetry -DeleteDeployment $DeleteFailedDeploymentBeforeRetry
                $appendSuffix = ConvertTo-Bool -Value $AppendRetryNumberToVMName
                if ($appendSuffix)
                {
                    $templateParameterObject.newVMName = "$baseVmName-$i"
                }
            }
        }
    }
}
finally
{
    if ($OutputResourceId -and -not [string]::IsNullOrWhiteSpace($resourceId))
    {
        # Capture the resource ID in the output variable.
        Write-Host "Creating variable '$OutputResourceId' with value '$resourceId'"
        Write-Host "##vso[task.setvariable variable=$OutputResourceId;]$resourceId"
    }

    Write-Host 'Completing Azure DevTest Labs Create VM Task'
    Pop-Location
}
