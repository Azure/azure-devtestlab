<#
    .SYNOPSIS
        This script creates a task inside Windows Task Scheduler getting a file script from a blob storage.

    .DESCRIPTION
        This script creates a task inside Windows Task Scheduler getting the Task scheduler configuration from the xml file.

    .PARAMETER StorageAccountName
        Optional. The name of the storage account

    .PARAMETER containerName
        Optional. The name of the container

    .PARAMETER SASToken
        Optional. The name of the SAS token.

    .PARAMETER folder
        Optional. The name of the destination folder for the XML file

    .PARAMETER filename
        Optional. The name of the XML file containing the definition of the task

    .PARAMETER scriptName
        Optional. The name of the script file

    .EXAMPLE
        PS C:\> LoadIdleScript

    .EXAMPLE
        PS C:\> LoadIdleScript -StorageAccountName university -containerName universityContent
#>

param
(
    [Parameter(Mandatory=$false, HelpMessage="The name of the storage account")]
    [string] $StorageAccountName="vlabresources",

    [Parameter(Mandatory=$false, HelpMessage="The name of the container")]
    [string] $containerName="content",

    [Parameter(Mandatory=$true, HelpMessage="The name of the SAS token")]
    [string] $SASToken,

    [Parameter(Mandatory=$false, HelpMessage="The name of the destination folder for the XML file")]
    [string] $folder = "C:\Users\SuperUser\Documents\WindowsPowerShell",

    [Parameter(Mandatory=$false, HelpMessage="The name of the XML file containing the definition of the task")]
    [string] $filename = "ShutdownOnIdleV2.xml",

    [Parameter(Mandatory=$false, HelpMessage="The name of the script file")]
    [string] $scriptName = "ShutdownOnIdleV2.ps1"
)

$ErrorActionPreference = "Stop"

$Ctx = New-AzureStorageContext $StorageAccountName -SasToken $SASToken
    
Get-AzureStorageBlobContent -Container $containerName -Blob $filename -Destination $folder -Context $Ctx -Force -ErrorAction Stop

Get-AzureStorageBlobContent -Container $containerName -Blob $scriptName -Destination $folder -Context $Ctx -Force -ErrorAction Stop

$filepath = $folder +"\"+ $filename
$taskname = $filename.Split('.')[0]

schtasks.exe /delete /TN $taskname /f
schtasks.exe /create /TN $taskname /XML $filepath
