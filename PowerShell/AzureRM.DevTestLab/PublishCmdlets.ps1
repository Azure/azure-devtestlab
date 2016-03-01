###################################################################################################

function UpdateRMTemplates
{
    # Ensure that the RM templates folder  exists.
    $srcRMTemplatesFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\..\RM Templates" -Resolve -ErrorAction "Stop"

    # Ensure that the powershell cmdlets folder  exists.
    $destCmdletsFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\..\PowerShell\AzureRM.DevTestLab" -Resolve -ErrorAction "Stop"

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

function GenerateModuleManifest
{
        Param(
        [ValidateNotNullOrEmpty()]
        [string]
        $ModuleVersion
    )

    # Ensure that the powershell cmdlets folder  exists.
    $srcCmdletsFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\..\PowerShell\AzureRM.DevTestLab" -Resolve -ErrorAction "Stop"

    # Ensure that the module script file exists.
    $srcModuleScriptFile = Join-Path -Path $PSScriptRoot -ChildPath "..\..\PowerShell\AzureRM.DevTestLab\AzureRM.DevTestLab.psm1" -Resolve -ErrorAction "Stop"

    # Ensure that the RM template files exist in the cmdlets folder.
    $srcRMTemplateFiles = Get-ChildItem -Path $srcCmdletsFolder -Recurse -Filter "*azuredeploy.json" 
    if ($null -eq $srcRMTemplateFiles -or 0 -eq $srcRMTemplateFiles.Count)
    {
        throw $("No RM template files were found in location '" + $srcCmdletsFolder + "'.")
    }

    # Compute the list of files to package with this module
    $moduleFileList = @()
    foreach ($srcFile in $srcRMTemplateFiles)
    {
        $moduleFileList += $srcFile.Name
    }

    # Here's the rest of the module attributes
    $moduleRoot = "AzureRM.DevTestLab"
    $moduleGuid = "895e6365-43ef-4ef2-a33c-c3bfdf2d0e3e"
    $moduleAuthor = "Azure DevTest Lab"
    $moduleCompanyName = "Azure DevTest Lab"
    $moduleCopyright = "(c) 2016 Azure DevTest Labs. All rights reserved."
    $moduleDescription = "PowerShell module for Azure DevTest Labs (Preview)"

    # Compute the destination path of the module manifest file.
    $destModuleManifestFilepath = $(Join-Path -Path $PSScriptRoot -ChildPath "..\..\PowerShell\AzureRM.DevTestLab\AzureRM.DevTestLab.psd1")

    # Nuke any existing file with same name
    if ($true -eq (Test-Path -Path $destModuleManifestFilepath))
    {
        Remove-Item -Path $destModuleManifestFilepath -Force -ErrorAction "Stop"
    }

    Write-Host "Generating the module manifest file..."

    # Generate the module manifest file.
    New-ModuleManifest -Path $destModuleManifestFilepath `
        -RootModule $moduleRoot `
        -ModuleVersion $ModuleVersion `
        -FileList $moduleFileList `
        -Guid $moduleGuid `
        -Author $moduleAuthor `
        -CompanyName $moduleCompanyName `
        -Copyright $moduleCopyright `
        -Description $moduleDescription `
        -ErrorAction "Stop"

    # Check if the file was actually generated
    if ($false -eq (Test-Path -Path $destModuleManifestFilepath))
    {
        throw $("The module manifest file '" + $destModuleManifestFilepath + "' could not be generated.")
    }
    else
    {
        Write-Host "The module manifest file was successfully generated."
    }
}

###################################################################################################

function PublishModule
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