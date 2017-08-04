Import-Module "C:\Repos\azure-devtestlab-usage\Scripts\UsageReporting\Runbooks\GenerateMasterSQLTable.psm1"

$StorageAccountName = "rbcazstoracct" #Get-AutomationVariable -Name 'StorageAccountName'
$StorageKey = "WybiL3yQqVS3/BuP1At4erCurC5a+P2pFOSylZBzQNscr8U+k2IST4Nk3HWIwrDUs0mp6HlYjLPfowH8LvjF9w==" #Get-AutomationVariable -Name 'StorageKey'
$ContainerName = "labresourceusage" #Get-AutomationVariable -Name 'ContainerName'
$sqlConnection = "Server=tcp:rbcazsqlsrv.database.windows.net,1433;Initial Catalog=rbbusagedb;Persist Security Info=False;User ID=roger;Password=ode#1ode;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;" #Get-AutomationVariable -Name 'SQLConnection'

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
    Write-Output "Generating table using file $(Join-Path -Path $localStore -ChildPath $indFile)"
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



