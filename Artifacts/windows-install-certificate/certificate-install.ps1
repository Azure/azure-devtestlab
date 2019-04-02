<#
Installs an existing certificate to the LocalMachine store.
Creates a self signed certificate and imports it into you Personal and Root stores. 
I used this when setting up a new development site on dev machine.
#>
[CmdletBinding()]
Param(
    [ValidateNotNullOrEmpty()]
    [string] $certificateName,
    [ValidateNotNullOrEmpty()]
    [string] $base64cert,
    [ValidateNotNullOrEmpty()]
    [string] $certificatePassword
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

##################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe artifact failed to apply.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################
#
# Main execution block.
#

try
{
    Write-Host "Installing certificate $certificateName"

    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        # Build up the deploy arguments.
        $arguments = "-file `"{0}`"" -f $script:MyInvocation.MyCommand.Path
    
        # Start the new process.
        Start-Process powershell.exe -Verb runas -ArgumentList $arguments -Wait
    }
    else
    {
        $securePassword = ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force
        $certificatePassword = "deleted"

        $tempFilePath = [System.IO.Path]::GetTempFileName()
        Write-Host "Temp file path '$tempFilePath'" 

        [System.IO.File]::WriteAllBytes($tempFilePath, [System.Convert]::FromBase64String($base64cert))
        Write-Host "Certificate saved"
        		
        Get-ChildItem -Path $tempFilePath | Import-PfxCertificate -CertStoreLocation Cert:\LocalMachine\My -Exportable -Password $securePassword
        Write-Host "Certificate $certificateName added to the LocalMachine\My store succesfully."

        Remove-Item -Path "$tempFilePath" -Force
        Write-Host "Deleted the temp file $tempFilePath"
    }

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    popd
}
