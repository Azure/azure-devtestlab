function GenerateMasterSQLTable {

param(
    [object] $dataFile,
    [object] $sqlConn,
    [string] $tableName)

    [Reflection.Assembly]::LoadWithPartialName("System.Data") | Out-Null
    [Reflection.Assembly]::LoadWithPartialName("System.Data.SqlClient") | Out-Null
    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Types") | Out-Null
    [Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null

    Trap {
        $err = $_.Exception
        while ( $err.InnerException )
        {
            $err = $err.InnerException
            write-output $err.Message
        };
        continue
    }

    
    $csvdelimiter = "," 
    $datatable = New-Object System.Data.DataTable
    $currFile = $dataFile.FullName
    
    Write-Output "Helper: using $currFile"

    If (Test-Path -Path $currFile) {
        Write-Output "$currFile exists."
    }
    else
    {
        Write-Output "$currFile gone!!!!!."
    }
         
    # SQL Connection with table work  ===============================================================================================================

    $srv = New-Object Microsoft.SqlServer.Management.Smo.Server $sqlConn.DataSource
    $srv.ConnectionContext.LoginSecure = $false
    $srv.ConnectionContext.ConnectionString = $sqlConn.ConnectionString
    
    Write-Output "Helper: Server objects set."

    $db = New-Object Microsoft.SqlServer.Management.Smo.Database 
    $db = $srv.Databases.Item($sqlConn.Database)

    Write-Output "Helper: Database objects set."
         
    $tb = new-object Microsoft.SqlServer.Management.Smo.Table -ArgumentList $db, $tableName

    Write-Output "Helper: Table object set."

    # Add columns to the datatable and the table object  ===============================================================================================================

    $createTable = $false
    $alterTable = $false

    # Get the columns from the first row of the file
    $reader = New-Object System.IO.StreamReader($currFile) 
    $columns = (Get-Content $currFile -First 1).Split($csvdelimiter) 
    $null = $reader.ReadLine()

    #Check if existing table and has same # columns
    if (!$db.Tables.Contains($tableName, "dbo"))
    {
        Write-Output "Helper: Create new Table."
        $createTable = $true        
    }
    else {

         if ($db.Tables[$tableName].Columns.Count -ne $columns.Count)
         {
            Write-Output "Helper: Alter existing table."
            #Different number of columns!!!!
            $tb = $db.Tables[$tableName]
            $alterTable = $true
         }
    }

    $dt = new-object Microsoft.SqlServer.Management.Smo.DataType([Microsoft.SqlServer.Management.Smo.SqlDataType]::NVarChar,240)

    # Determine if table needs to be created or exists and needs an update  ===============================================================================================================

    foreach ($column in $columns) {  
        $tempcol = new-object Microsoft.SqlServer.Management.Smo.Column($tb, $column, $dt)
        $datatable.Columns.Add().ColumnName = $column

        if ($createTable -or (($alterTable) -and (!$tb.Columns.Contains($column)))) {
            $tb.Columns.Add($tempcol)
        }
    }
    
    if ($createTable) {
        $tb.Create()
    }

    if ($alterTable) {
        $tb.Alter()
    }

    
                  
    # Insert CSV into tables ===============================================================================================================
    $batchsize = 50000
    $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($sqlConn.ConnectionString, [System.Data.SqlClient.SqlBulkCopyOptions]::TableLock) 
    $bulkcopy.DestinationTableName = $tableName
    $bulkcopy.bulkcopyTimeout = 0 
    $bulkcopy.BatchSize = $batchsize
    $datacsvdelimiter = '","'
    $i = 0

    while (($line = $reader.ReadLine()) -ne $null)  { 
    
        
        $row = $datatable.NewRow()
        #Custom delimiter as a comma may be used in the names.
        $row = $line -split $datacsvdelimiter
        
        #Trim off beginning and ending quotes
        $row[0] = $row[0].Trim('"')
        $row[($row.Length) - 1] = $row[($row.Length) - 1].Trim('"')

        $null = $datatable.Rows.Add($row) 
       
        $i++;
        if (($i % $batchsize) -eq 0) {  
            $bulkcopy.WriteToServer($datatable)  
            Write-Output "Helper: $($i.ToString()) rows have been inserted." 
            $datatable.Clear()  
        }  
 
    }  
  
    if($datatable.Rows.Count -gt 0) { 
        $bulkcopy.WriteToServer($datatable)
        Write-Output "Helper: Last $($datatable.Rows.Count.ToString()) rows inserted." 
        $datatable.Clear() 
    } 
       
    Write-Output "Helper: $tableName loaded."
       
    # Clean Up ==============================================================================================================================
    $tb.Dispose()
    $reader.Close(); $reader.Dispose() 
    $bulkcopy.Close(); $bulkcopy.Dispose() 
    $datatable.Dispose()

    Write-Output "End of SQLHelper."
      
    

}

Export-ModuleMember -Function GenerateMasterSQLTable

