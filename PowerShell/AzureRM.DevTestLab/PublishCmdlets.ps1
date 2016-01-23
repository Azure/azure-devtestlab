###################################################################################################

<#
    .SYNOPSIS
    Creates a local copy of the Azure RM Templates for Azure DevTestLabs. If local copies already
    exist, they are simply updated.
#>

function UpdateRMTemplate
{
    # Ensure that the RM templates folder  exists.
    $srcRMTemplatesFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\..\RM Templates" -Resolve -ErrorAction "Stop"

    $destCmdletsFolder = $PSScriptRoot 

    # Ensure that the RM template files exists.
    $srcRMTemplateFiles = Get-ChildItem -Path $srcRMTemplatesFolder -Recurse -Filter "azuredeploy.json" 
    if ($null -eq $srcRMTemplateFiles -or 0 -eq $srcRMTemplateFiles.Count)
    {
        throw $("No RM template files were found in location '" + $srcRMTemplatesFolder + "'.")
    }

    Write-Host "Updating RM templates..."

    # copy the RM templates file to the cmdlets folder
    foreach ($srcFile in $srcRMTemplateFiles)
    {
        $destFileName = Join-Path -Path $DestCmdletsFolder -ChildPath $($srcFile.Directory.Name + "-" + $srcFile.Name)
        
        Write-Host "Copying file:"
        Write-Host $(" Source: " + $srcFile.FullName)
        Write-Host $(" Destination: " + $destFileName)
           
        Copy-Item -Path $srcFile.FullName -Destination $destFileName -Force 
        if ($false -eq $?)
        {
            throw $("An error occurred while copying file from source '" + $srcFile.FullName + "' to destination '" + $destFileName + "'.")
        }
        else
        {
            Write-Host "OK."
        }
    } 

    Write-Host "All RM templates were successfully updated."
}

###################################################################################################

<#
    .SYNOPSIS
    Publishes the AzureRM.DevTestLab module to the PowerShell gallery.
#>

function PublishModuleToGallery
{
    Param(
        [ValidateNotNullOrEmpty()]
        [string]
        $NugetApiKey
    )

    # Ensure that the module manifest file exists.
    $moduleManifestFile = Join-Path -Path $PSScriptRoot -ChildPath "..\..\PowerShell\AzureRM.DevTestLab\AzureRM.DevTestLab.psd1" -Resolve -ErrorAction "Stop"

    # First we'll test the module manifest
    Write-Host "Testing module manifest..."

    $manifest = Test-ModuleManifest -Path $moduleManifestFile
    if ($false -eq $? -or $null -eq $manifest)
    {
        throw $("An error was encountered while testing the module manifest '" + $moduleManifestFile + "'.")    
    }

    Write-Host $(" Module Name: " + $manifest.Name)
    Write-Host $(" Module Version: " + $manifest.Version)
    Write-Host "OK."

    # Now we're ready to publish the module
    Write-Host "Publishing module:"

    Publish-Module -Name $moduleManifestFile -NuGetApiKey $NugetApiKey
    if ($false -eq $?)
    {
        throw "An error was encountered while publishing the module."
    }
    else
    {
        Write-Host "The module was successfully published."
    }
}

###################################################################################################