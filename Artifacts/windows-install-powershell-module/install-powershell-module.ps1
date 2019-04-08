<#
  Installs the specified PowerShell module using PowerShellGallery.
#>
[CmdletBinding()]
Param(
    [ValidateNotNullOrEmpty()]
    [string] $moduleName
)


##################################################################################################

#
# Powershell Configurations
#

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.  
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Ensure we set the working directory to that of the script.
pushd $PSScriptRoot

# Ensure that current process can run scripts. 
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

#
# Functions used in this script.
#

function Handle-LastError
{
    [CmdletBinding()]
    param(
    )

    $message = $error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "ERROR: $message" -ForegroundColor Red
    }
    
    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    Handle-LastError
}

###################################################################################################

#
# Main execution block.
#

try
{
    Write-Host "Installing module $moduleName"

    If(-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        #build up the deploy arguments
        $arguments = "-file `"{0}`"" -f $script:MyInvocation.MyCommand.Path
    
        # Start the new process
        Start-Process powershell.exe -Verb runas -ArgumentList $arguments
        exit
    }
    else
    {
		Install-Module $moduleName -AllowClobber -Force -Verbose
		Write-Host "Installed module $moduleName"

		Import-Module $moduleName -Verbose
		Write-Host "Imported module $moduleName"
    }

    Write-Host 'Done.'
}
finally
{
    popd
}