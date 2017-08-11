function GenerateMasterSQLTable {

param(
    [Parameter(Mandatory=$true)]
    [object] $dataFile,
    [Parameter(Mandatory=$true)]
    [object] $sqlConn,
    [Parameter(Mandatory=$true)]
    [string] $tableName
    )

   $existingTable = $null

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
   
    $primaryConn = New-Object System.Data.SqlClient.SqlConnection($sqlConn.ConnectionString)
    $primaryConn.Open()
    
    Write-Output "pConn: $($primaryConn.ConnectionString)"

    $checkTable = "Select * from $tableName"
    $sqlCmd = New-Object System.Data.SqlClient.SqlCommand($checkTable,$primaryConn)
    $existingTable = $sqlCmd.ExecuteReader()

    if ($existingTable -eq $null) {
        Write-Output "Creating new table: $tableName"
        $tableCmd = "CREATE TABLE $tableName ("
    
        # Get the columns from the first row of the file
        $reader = New-Object System.IO.StreamReader($currFile) 
        $columns = (Get-Content $currFile -First 1).Split($csvdelimiter) 
        $null = $reader.ReadLine()
        
        foreach ($column in $columns) {  
            $tableCmd += "[$column] [nvarchar] (250) NULL"
            $datatable.Columns.Add().ColumnName = $column

            if ($columns.IndexOf($column) -lt ($columns.Count -1)) {
                $tableCmd += ","
            }
            else {
                $tableCmd += ")"
            }

        }

        $sqlCmd = New-Object System.Data.SqlClient.SqlCommand($tableCmd,$primaryConn)    
        $null = $sqlCmd.BeginExecuteNonQuery()
    }
    
 
                      
    # # Insert CSV into tables ===============================================================================================================
    $batchsize = 50000
    $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($sqlConn.ConnectionString, [System.Data.SqlClient.SqlBulkCopyOptions]::TableLock) 
    $bulkcopy.DestinationTableName = $tableName
    $bulkcopy.bulkcopyTimeout = 0 
    $bulkcopy.BatchSize = $batchsize
    $datacsvdelimiter = '","'
    
    $i = 0;

    while (($line = $reader.ReadLine()) -ne $null)  { 
    
        Write-Output "Line: $line"
        $row = $datatable.NewRow()
        #Custom delimiter as a comma may be used in the names.
        $row = $line -split $datacsvdelimiter
        
        #Trim off beginning and ending quotes
        $row[0] = $row[0].Trim('"')
        $row[($row.Length) - 1] = $row[($row.Length) - 1].Trim('"')
        Write-Output "Row add"
        $xx = $datatable.Rows.Add($row) 
       
        $i++;
        if (($i % $batchsize) -eq 0) {  
            Write-Output "Before WriteToServer a"
            $bulkcopy.WriteToServer($datatable)  
            Write-Output "Helper: $($i.ToString()) rows have been inserted." 
            $datatable.Clear()  
        }  
 
    }  
  
    if($datatable.Rows.Count -gt 0) { 
        Write-Output "Before WriteToServer b"
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

