###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = "Stop"

# Hide any progress bars, due to downloads and installs of remote components.
$ProgressPreference = "SilentlyContinue"

# Discard any collected errors from a previous execution.
$Error.Clear()

# Allow certian operations, like downloading files, to execute.
Set-ExecutionPolicy Bypass -Scope Process -Force

###################################################################################################
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

if ([Environment]::OSVersion.Version.Major -gt 6) {
    Write-Host "`nRemoving Appx Packages for current user`n"

    Get-AppxPackage | Remove-AppxPackage -ErrorAction SilentlyContinue 

    Write-Host "`nRemoving All users Appx Packages for current user`n"
    Get-AppxPackage -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue

    Write-Host "`nRemoving removable apps from provisioned apps list so they don't reinstall on new users`n"
    Get-AppxProvisionedPackage -Online  | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

    Write-Host "`nRemoving all removable apps for all users`n"
    $allPackageNames = Get-AppxPackage -AllUsers | Select-Object -Expand Name
    $allPackageNames = $allPackageNames | ForEach-Object {"*$_*"}
    ForEach($app in $allPackageNames){
        Try{
            Get-AppxPackage -Allusers -Name $app | Remove-AppxPackage -Allusers -ErrorAction SilentlyContinue
        }
        Catch{
        }
    }

    

    Write-Host "`nDone Removing Appx Packages`n"
}
else {
    Write-Host "`nOS Major version is older than 7. Skipping...`n"
}

Write-Host "`nThe artifact was applied successfully.`n"
