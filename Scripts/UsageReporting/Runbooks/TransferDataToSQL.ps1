Import-Module GenerateMasterSQLTable


$StorageAccountName = Get-AutomationVariable -Name 'StorageAccountName'
$StorageKey = Get-AutomationVariable -Name 'StorageKey'
$ContainerName = Get-AutomationVariable -Name 'ContainerName'
$sqlConnection = Get-AutomationVariable -Name 'SQLConnection'

Trap {
        $err = $_.Exception
        while ( $err.InnerException )
        {
            $err = $err.InnerException
            write-output $err.Message
        };
        continue
    }

#Generate structure to pull data from storage ==================================================================================================================================

$Ctx = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageKey 

$localStore = Join-Path -Path $env:APPData -ChildPath $ContainerName

If(!(Test-Path -LiteralPath $localStore))
{
    New-Item -ItemType Directory -Force -Path $localStore | out-null
}

Write-Output "Created $localStore for download."

$blobs = Get-AzureStorageBlob -Container $ContainerName -Context $Ctx 

#Only need to download the latest blobs to the local store to be pushed to SQL

 foreach ($b in $blobs) {
    
     if ($b.LastModified.Date -eq $(Get-Date).Date) {
         $b | Get-AzureStorageBlobContent -Destination $localStore -Force 
     }

 }


#SQL Connection =============================================================================================================================

$sqlConn = New-Object System.Data.SqlClient.SqlConnection
$sqlConn.ConnectionString = $sqlConnection

#SQL Create table VMs ===========================================================================================================================

$datafiles = Get-ChildItem -LiteralPath $localStore -File -Filter "virtualmachines.csv" -Recurse

Write-Output "Starting MasterVMData, file count: $($datafiles.Count.ToString())"

foreach ($indFile in $datafiles)
{
    Write-Output "Generating table using file $($indFile.FullName)"
    Write-Output $(Test-Path -Path $indFile.FullName)
    GenerateMasterSQLTable -datafile $indFile -sqlConn $sqlConn -tableName "MasterVMData"
    

    #Remove temp files
    $indfile.Delete()
}

Write-Output "Ending MasterVMData"

#SQL Create table Disks ===========================================================================================================================

$datafiles = Get-ChildItem -LiteralPath $localStore -File -Filter "disks.csv" -Recurse

Write-Output "MasterDiskData: LocalStore: $($localStore)"

foreach ($indFile in $datafiles)
{
    Write-Output "Generating table using file $(Join-Path -Path $localStore -ChildPath $indFile)"
    GenerateMasterSQLTable -datafile $indFile -sqlConn $sqlConn -tableName "MasterDiskData"
    
    #Remove temp files
    $indfile.Delete()
}

Write-Output "Ending MasterDiskData"

# Remove files from storage to avoid duplication
Remove-AzureStorageBlob -Container $ContainerName -Context $Ctx

Remove-Item -Path $localStore -Recurse



