###################################################################################################

<#
    .SYNOPSIS
    - Updates AzureRM.DevTestLab module's dependencies (Azure RM template for DTL). 
    - This function creates local copies of the Azure RM Templates for the PS module. If local 
      copies already exist, they are simply updated.
#>

function Update-PSDependencies
{
    # Ensure that the src RM templates folder  exists.
    $srcRMTemplatesFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\..\RMTemplates" -Resolve -ErrorAction "Stop"

    # Ensure that the dest cmdlets folder exists.
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

<#
    .SYNOPSIS
    - Updates AzureRM.DevTestLab module's dependencies (DTL Azure RM templates, DTL PS module). 
    - This function creates local copies of the DTL Azure RM Templates and the DTL PS module. If 
      local copies already exist, they are simply updated.
#>

function Update-VSOTaskDependencies
{
    # Ensure that the src RM templates folder  exists.
    $srcRMTemplatesFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\..\RMTemplates" -Resolve -ErrorAction "Stop"

    # Ensure that the src PS module exists.
    $srcPSModuleFile = Join-Path -Path $PSScriptRoot -ChildPath "..\..\PowerShell\AzureRM.DevTestLab\AzureRM.DevTestLab.psm1" -Resolve -ErrorAction "Stop"

    # Ensure that the dest cmdlets folder exists.
    $destVSOAgentTasksFolder = Join-Path -Path $PSScriptRoot -ChildPath "..\..\VSOAgentTasks" -Resolve -ErrorAction "Stop"

    # Ensure that the RM template files exists.
    $srcRMTemplateFiles = Get-ChildItem -Path $srcRMTemplatesFolder -Recurse -Filter "azuredeploy.json" 
    if ($null -eq $srcRMTemplateFiles -or 0 -eq $srcRMTemplateFiles.Count)
    {
        throw $("No RM template files were found in location '" + $srcRMTemplatesFolder + "'.")
    }

    # Ensure that the sub-folders for individual tasks exist.
    $srcTasksSubFolders = Get-ChildItem -Path $destVSOAgentTasksFolder -Directory 
    if ($null -eq $srcTasksSubFolders -or 0 -eq $srcTasksSubFolders.Count)
    {
        throw $("No task folders were found in the location '" + $destVSOAgentTasksFolder + "'.")
    }

    Write-Host "Updating RM templates and PS module..."

    # copy the DTL RM templates file and DTL PS module to each task sub-folder
    foreach($subFolder in $srcTasksSubFolders)
    {
        # copy the DTL RM templates file to each task sub-folder
        foreach ($srcFile in $srcRMTemplateFiles)
        {
            $destFileName = Join-Path -Path $subFolder.FullName -ChildPath $($srcFile.Directory.Name + "-" + $srcFile.Name)
        
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

        # copy the DTL PS module to each task sub-folder
        Write-Host "Copying file:"
        Write-Host $(" Source: " + $srcPSModuleFile)
        Write-Host $(" Destination: " + $subFolder.FullName)

        Copy-Item -Path $srcPSModuleFile -Destination $subFolder.FullName -Force 
        if ($false -eq $?)
        {
            throw $("An error occurred while copying file from source '" + $srcPSModuleFile + "' to destination '" + $subFolder.FullName + "'.")
        }
        else
        {
            Write-Host "OK."
        }
    }

    Write-Host "The RM templates and PS module were successfully updated."

}

###################################################################################################

<#
    .SYNOPSIS
    Publishes the AzureRM.DevTestLab module to the PowerShell gallery.
#>

function Publish-PowerShellModule
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

<#
    .SYNOPSIS
    Publishes the AzureRM.DevTestLab module to the PowerShell gallery.
#>

function Publish-VSOAgentTasks
{
}

###################################################################################################