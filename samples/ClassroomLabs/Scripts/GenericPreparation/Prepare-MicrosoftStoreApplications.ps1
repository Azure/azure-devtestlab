<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script prepares computer for class by aiding in the deletion of unneeded Microsoft Store applications.  Remaining Microsoft Store applications are updated.
#>

[CmdletBinding()]
param( )

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Hide any progress bars, due to downloads and installs of remote components.
$ProgressPreference = "SilentlyContinue"

# Ensure we set the working directory to that of the script.
Push-Location $PSScriptRoot

# Discard any collected errors from a previous execution.
$Error.Clear()

# Configure strict debugging.
Set-PSDebug -Strict

###################################################################################################
#
# Handle all errors in this script.
#

trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message) {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe script failed to run.`n" -ForegroundColor Red

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################
#
# Functions used in this script.
#             

<#
.SYNOPSIS
Returns true if script is running with administrator privileges and false otherwise.
#>
function Get-RunningAsAdministrator {
    [CmdletBinding()]
    param()
    
    $isAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    $null = @(
        Write-Verbose "Running with$(if(-not $isAdministrator) {"out"}) Administrator privileges."
    )
    return $isAdministrator
}


<#
.SYNOPSIS
Removes selected Microsoft Store applications.  Uninstallable applications are not shown.
#>
function Remove-MicrosoftStoreApps{

    $options =  $(New-Object -Type 'System.Management.Automation.Host.ChoiceDescription' -ArgumentList @('&Select specific applications', 'Select specific applications to delete from a grid.')), `
                $(New-Object -Type 'System.Management.Automation.Host.ChoiceDescription' -ArgumentList @('&None','Do not remove any Microsoft Store applications.'))
                
    $response = $Host.UI.PromptForChoice("Remove Microsoft Store applications", 'Which Microsoft Store applications should be removed?', $options, 0)

    if ($response -eq 0){
        
        $microsoftStoreAppsToRemove= Get-AppxPackage | Where {$_.NonRemovable -eq $false} | Sort-Object -Property Name  | Out-Gridview -Title "Select which Microsoft Store applications to delete" -PassThru
        $appsThatAreDependencies = @(Get-AppxPackage | Select -expand Dependencies | select -expand PackageFullName)  
        #Remove Microsoft Store application, as long as it is not a dependency of another application.         
        $microsoftStoreAppsToRemove | `
            %{
                if ($appsThatAreDependencies -contains $_.PackageFullName){
                    $currentPackageFullName = $_.PackageFullName
                    $appsWithDependencyOnCurrentPackageList =  @(Get-AppxPackage | where {$($_.Dependencies | select -expand PackageFullName) -eq $currentPackageFullName} | select -expand Name)
                    Write-Host "Can't remove '$($_.Name)' as it is a dependency for $($appsWithDependencyOnCurrentPackageList -join ', ')."
                }else{
                    %{Write-Host "Removing '$($_.Name)'."; $_ | Remove-AppxPackage }
                }
            }
    }else{
        Write-Host "No Microsoft Store applications removed."
    }
}

<#
.SYNOPSIS
Updates Microsoft Store applications.  
#>
function Update-MicrosoftStoreApps{
    Write-Host "Updating Microsoft Store applications."
    (Get-WmiObject -Namespace "root\cimv2\mdm\dmmap" -Class "MDM_EnterpriseModernAppManagement_AppManagement01").UpdateScanMethod() | Out-Null
}

###################################################################################################
#
# Main execution block.
#

try {
    Write-Host "Verifying running as administrator."
    if (-not (Get-RunningAsAdministrator)) { 
        Write-Error "Please re-run this script as Administrator." 
    }

    Remove-MicrosoftStoreApps

    Update-MicrosoftStoreApps
  
    Write-Host -Object "Script completed successfully." -ForegroundColor Green
}
finally {
    # Restore system to state prior to execution of this script.
    Pop-Location
}
