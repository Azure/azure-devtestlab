<##################################################################################################

    Description
    ===========

    - This script uploads a user-specified VHD to a Dev/Test lab:  
        - Authenticates user against Azure-AD.
        - Copies VHD to a local staging area.
        - Extract the storage account and container details associated with the Dev/Test lab instance.
        - Uploads VHD to the storage container associated with the lab instance.
        - Deletes the local copy of the VHD from the staging area. 

    - The logs are generated at : %USERPROFILE%\UploadVHDToDTL\Logs\{TimeStamp}.log


    Usage examples
    ==============
    
    Powershell -executionpolicy bypass -file UploadVHDToDTL.ps1 -LabName <lab name> -AzureSubscriptionId <subscription id> -VHDFullPath <full-path to vhd>


    Pre-Requisites
    ==============

    - Please ensure that the latest Azure Powershell has been installed on the machine on which 
      this script will be executed. 
      More details: https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/
    - Please ensure that the powershell execution policy is set to unrestricted or bypass.


    Known issues / Caveats
    ======================
    
    - No known issues.


    Coming soon / planned work
    ==========================
    
    - Make the authentication scenario (via Add-AzureAccount cmdlet) more robust. Handle user-cancellation, 2FA pin 
      etc more robustly.
    - Automatically detect and convert .VHDX files into .VHD files (assuming HyperV cmdlets are 
      available).
    - Support service principal for automation:
        - Point to MSDN docs for details on creating service principal.
        - Use parameter sets. 
    - Support copying of VHDs from azure blob container and azure file shares.
    - Support auto-creation of VM templates. 

##################################################################################################>

#
# Mandatory parameters to this script file.
#

Param(
    # Name of Dev/Test lab instance.
    [ValidateNotNullOrEmpty()]
    [string]
    $LabName,

    # Azure subscription ID associated with the Dev/Test lab instance.
    [ValidateNotNullOrEmpty()]
    [string]
    $AzureSubscriptionId,

    # Full path to the VHD file (that'll be uploaded to the Dev/Test lab instance).
    # Note: Currently we only support VHDs that are available from:
    # - local drives (e.g. c:\somefolder\somefile.ext)
    # - UNC shares (e.g. \\someshare\somefolder\somefile.ext).
    # - Network mapped drives (e.g. net use z: \\someshare\somefolder && z:\somefile.ext). 
    [ValidateNotNullOrEmpty()]
    [string]
    $VHDFullPath,

    # [Optional] The name that will be assigned to VHD once uploded to the Dev/Test lab instance.
    # The name should be in a "<filename>.vhd" format (E.g. "WinServer2012-VS2015.VHD"). 
    [string]
    $VHDFriendlyName,

    # [Optional] If this switch is specified, then any VHDs copied to the staging area (if any) 
    # will NOT be deleted.
    # Note: The default behavior is to delete all VHDs from the staging area.
    [switch]
    $KeepStagingVHD = $false
)

##################################################################################################

#
# Powershell Configurations
#

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
$ErrorActionPreference = "stop"

###################################################################################################

#
# Custom Configurations
#

$UploadVHDToDTLFolder = Join-Path $env:USERPROFILE -ChildPath "UploadVHDToDTL"

# Location of the log files
$ScriptLogFolder = Join-Path $UploadVHDToDTLFolder -ChildPath "Logs"
$ScriptLog = Join-Path -Path $ScriptLogFolder -ChildPath $([System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss") + ".log")

# Location of VHD staging area
$VHDStagingFolder = Join-Path $UploadVHDToDTLFolder -ChildPath "Staging"

# The name of the storage container associated with the Dev/Test lab instance (where the VHDs will be uploaded to).
$DTLDefaultContainerName = "uploads"

# Default exit code
$ExitCode = 0

##################################################################################################

# 
# Description:
#  - Displays the script argument values (default or user-supplied).
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - Please ensure that the Initialize() method has been called at least once before this 
#    method. Else this method can only write to console and not to log files. 
#

function DisplayArgValues
{
    WriteLog "========== User-specified parameters =========="
    WriteLog $("-LabName : " + $LabName)
    WriteLog $("-AzureSubscriptionId : " + $AzureSubscriptionId)
    WriteLog $("-VHDFullPath : " + $VHDFullPath)
    WriteLog $("-VHDFriendlyName : " + $VHDFriendlyName)
    WriteLog $("-KeepStagingVHD : " + $KeepStagingVHD)
    WriteLog "========== User-specified parameters =========="
    WriteLog "========== Custom configurations =============="
    WriteLog $("-UploadVHDToDTLFolder : " + $UploadVHDToDTLFolder)
    WriteLog $("-ScriptLogFolder : " + $ScriptLogFolder)
    WriteLog $("-ScriptLog : " + $ScriptLog)
    WriteLog $("-VHDStagingFolder : " + $VHDStagingFolder)
    WriteLog $("-DTLDefaultContainerName : " + $DTLDefaultContainerName)
    WriteLog "========== Custom configurations =============="
}

##################################################################################################

# 
# Description:
#  - Creates the folder structure which will be used for dumping logs and staging local copies of 
#    VHDs.
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function InitializeFolders
{
    if ($false -eq (Test-Path -Path $UploadVHDToDTLFolder))
    {
        New-Item -Path $UploadVHDToDTLFolder -ItemType directory | Out-Null
    }

    if ($false -eq (Test-Path -Path $ScriptLogFolder))
    {
        New-Item -Path $ScriptLogFolder -ItemType directory | Out-Null
    }

    if ($false -eq (Test-Path -Path $VHDStagingFolder))
    {
        New-Item -Path $VHDStagingFolder -ItemType directory | Out-Null
    }
}

##################################################################################################

# 
# Description:
#  - Writes specified string to the console as well as to the script log (indicated by $ScriptLog).
#
# Parameters:
#  - $message: The string to write.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function WriteLog
{
    Param(
        <# Can be null or empty #> $message
    )

    $timestampedMessage = $("[" + [System.DateTime]::Now + "] " + $message) | % {
        Write-Host -Object $_
        Out-File -InputObject $_ -FilePath $ScriptLog -Append
    }
}

##################################################################################################

# 
# Description:
#  - Verifies whether the user-specified VHD is accessible or not.
#
# Parameters:
#  - None.
#
# Return:
#  - If specified VHD is accessible, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - N/A.
#

function EnsureVHDAccessible
{
    WriteLog "Checking if the specified VHD is accessible..."
    WriteLog $(" - Specified VHD path : " + $VHDFullPath)

    if (Test-Path -Path $VHDFullPath)
    {
        WriteLog "Success. VHD is accessible."
    }
    else
    {
        Write-Error $("Error! Specified VHD is not accessible: " + $VHDFullPath)
    } 
}

##################################################################################################

# 
# Description:
#  - Authenticates against Azure-AD using credentials passed in by user.
#  - Also switches mode to AzureResourceManager and sets the current subscription.
#
# Parameters:
#  - None.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function AuthenticateToAzureAD
{
    WriteLog "Authenticating against Azure-AD..."
    $authenticated = Add-AzureAccount | Out-Null
    WriteLog "Successfully authenticated."

    # Switch mode to Azure RM and select the subscription ID specified by the user.
    Switch-AzureMode -Name AzureResourceManager | Out-Null
    Select-AzureSubscription -SubscriptionId $AzureSubscriptionId | Out-Null
}

##################################################################################################

# 
# Description:
#  - Checks whether the specified file path refers to a local or a remote (either a UNC share or 
#    a network-mapped drive) file.
#
# Parameters:
#  - $filePath: The full path a local or remote (available from a UNC share or a network
#    mapped drive) file.
#
# Return:
#  - True if the file is remote. False otherwise.
#
# Notes:
#  - Files that are served via http or https (e.g. files stored in azure storage blobs) are 
#    intentionally not supported.
#

function IsFileRemote
{
    Param(
        [ValidateNotNullOrEmpty()] [string] $filePath
    )

    # Poor man's check for UNC paths
    if ($filePath.StartsWith("\\"))
    {
        return $true
    }

    # A more formal check for UNC paths
    $uri = New-Object -TypeName System.Uri -ArgumentList @($filePath) 
    if (($null -ne $uri) -and ($true -eq $uri.IsUnc))
    {
        return $true
    }

    # Check for network-mapped drives
    $driveInfo = New-Object -TypeName System.IO.DriveInfo -ArgumentList @($filePath)
    if (($null -ne $driveInfo) -and ($driveInfo.DriveType -eq [System.IO.DriveType]::Network))
    {
        return $true
    }
            
    # else just assume it is local
    return $false
}

##################################################################################################

# 
# Description:
#  - If the user-specified VHD is a remote file, then this method copies the VHD to the 
#    local staging area (this enables faster uploads to Dev/test lab).
#
# Parameters:
#  - None.
#
# Return:
#  - If copied to the local staging area, then this method returns the full path to the 
#    copied VHD in the local staging folder.
#  - If not copied to staging area, then this method simply returns the original full path
#    to the local VHD. 
#
# Notes:
#  - N/A.
#

function CopyVHDToStagingIfNeeded
{
    $isRemoteVHD = IsFileRemote -filePath $VHDFullPath

    # if this is a local VHD, then don't copy it to the staging area
    if ($false -eq $isRemoteVHD)
    {
        return $VHDFullPath
    }
    else
    {
        $vhdFileName = Split-Path -Path $VHDFullPath -Leaf
        $vhdStagingPath = Join-Path -Path $VHDStagingFolder -ChildPath $vhdFileName

        WriteLog "Copying the VHD to the staging area (Note: This can take a while)..."
        WriteLog $(" - Source : " + $VHDFullPath)
        WriteLog $(" - Staging Destination : " + $vhdStagingPath)
        Copy-Item -Path $VHDFullPath -Destination $vhdStagingPath -Force | Out-Null
        WriteLog "Success."

        return $vhdStagingPath
    }
}

##################################################################################################

# 
# Description:
#  - Copies the VHD from the local staging area into the lab's storage container.
#
# Parameters:
#  - $vhdLocalPath: The full-path to the local copy of the VHD. 
#  - $labStorageAccountName: The name of the Dev/Test lab instance's default storage account.  
#  - $labStorageAccountKey: The access key to the Dev/Test lab instance's default storage account.
#  - $labResourceGroupName: The name of the resource group associated with the DTL lab instance.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function UploadVHDToDTL
{
    Param(
        [ValidateNotNullOrEmpty()] [string] $vhdLocalPath,
        [ValidateNotNullOrEmpty()] [string] $labStorageAccountName,
        [ValidateNotNullOrEmpty()] [string] $labStorageAccountKey,
        [ValidateNotNullOrEmpty()] [string] $labResourceGroupName
    )

    $context = New-AzureStorageContext –StorageAccountName $labStorageAccountName -StorageAccountKey $labStorageAccountKey

    # Compute the destination path. If the user has specified a 
    # friendly name for the VHD, let us use it. 
    if ([string]::IsNullOrEmpty($VHDFriendlyName))
    {
        $vhdFileName = Split-Path -Path $VHDFullPath -Leaf
    }
    else
    {
        $vhdFileName = $VHDFriendlyName
    }

    # extract the storage container endpoint URI
    WriteLog "Extracting the storage container endpoint URI..."
    $containerURI = (Get-AzureStorageContainer -Name $DTLDefaultContainerName -Context $context).CloudBlobContainer.Uri.AbsoluteUri.TrimEnd("/")
    WriteLog $(" - Endpoint URI : " + $containerURI)
    WriteLog "Success."
    
    # compute the final destination of the VHD
    $vhdDestinationPath = $($containerURI + "/" + $vhdFileName)

    # Now upload the VHD to lab's container
    WriteLog "Starting upload of VHD to lab (Note: This can take a while)..."
    WriteLog $(" - Source: " + $vhdLocalPath)
    WriteLog $(" - Destination: " + $vhdDestinationPath)
    Add-AzureVhd -Destination $vhdDestinationPath -LocalFilePath $vhdLocalPath -ResourceGroupName $lab.ResourceGroupName -OverWrite | Out-Null
    WriteLog "Success."
}

##################################################################################################

try
{
    # Create folders for output logs and VHD staging.
    InitializeFolders
    DisplayArgValues

    # Pre-condition check to verify that the user-specified VHD is accessible.
    EnsureVHDAccessible

    # Authenticate against Azure-AD.
    AuthenticateToAzureAD

    # Extract the details associated with the Dev/Test lab instance.
    WriteLog "Extracting Dev/Test Lab details..."
    $lab = Get-AzureResource -ResourceName $LabName -OutputObjectFormat New  
    WriteLog $(" - Lab Name : "  + $lab.Name)
    WriteLog $(" - Lab Resource Id : "  + $lab.ResourceId)
    WriteLog $(" - Lab Resource Group Name : "  + $lab.ResourceGroupName)
    WriteLog $(" - Lab Location : "  + $lab.Location)
    WriteLog "Success."

    WriteLog "Extracting Dev/Test Lab properties..."
    $labProperties = (Get-AzureResource -ResourceName $lab.ResourceName -ResourceType $lab.ResourceType -ResourceGroupName $lab.ResourceGroupName).Properties
    $labStorageAccountName = $labProperties['defaultStorageAccount']
    WriteLog $(" - Lab Storage Account Name : "  + $labStorageAccountName)
    WriteLog "Success."

    # Extract the storage account associated with the Dev/Test lab instance.
    WriteLog "Extracting the lab's storage account key..."
    $labStorageAccountKey = (Get-AzureStorageAccountKey -StorageAccountName $labStorageAccountName -ResourceGroupName $lab.ResourceGroupName).Key1 
    WriteLog "Success. Storage account key extracted."

    # Copy the VHD into the staging area if needed
    $vhdLocalPath = CopyVHDToStagingIfNeeded 

    # Finally upload the VHD to the lab's storage container. 
    UploadVHDToDTL -labStorageAccountName $labStorageAccountName -labStorageAccountKey $labStorageAccountKey -labResourceGroupName $lab.ResourceGroupName -vhdLocalPath $vhdLocalPath
}

catch
{
    if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
    {
        $errMsg = $Error[0].Exception.Message
        WriteLog $errMsg
        Write-Host $errMsg
    }

    # Important note: Throwing a terminating error (using $ErrorActionPreference = "stop") still returns exit 
    # code zero from the powershell script. The workaround is to use try/catch blocks and return a non-zero 
    # exit code from the catch block. 
    $ExitCode = -1
}

finally
{
    if ($false -eq $KeepStagingVHD)
    {
        # Delete everything from the VHD staging folder
        WriteLog "Deleting all contents from the VHD staging folder..."
        Remove-Item -Path $(Join-Path -Path $VHDStagingFolder -ChildPath "*") -Recurse -Force
        WriteLog "Success. Contents deleted."
    }

    WriteLog $("This output log has been saved to: " + $ScriptLog)

    WriteLog $("Exiting with " + $ExitCode)
    exit $ExitCode
}