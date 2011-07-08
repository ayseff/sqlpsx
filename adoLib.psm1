# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Mike Shepard
### </Author>
### <Description>
### Defines functions for executing Ado.net queries with the SQLClient provider
### </Description>
### <Usage>
### import-module adolib
###  </Usage>
### </Script>
# ---------------------------------------------------------------------------

import-module adonetlib -args System.Data.SqlClient -Prefix SQL -force



<#
	.SYNOPSIS
		Uses the .NET SQLBulkCopy class to quickly copy rows into a destination table.

	.DESCRIPTION
        
		Also, the invoke-SQLBulkcopy function allows you to pass a command object instead of a set of records in order to "stream" the records
        into the destination in cases where there are a lot of records and you don't want to allocate memory to hold the entire result set.

	.PARAMETER  records
		Either a datatable (like one returned from invoke-query or invoke-storedprocedure) or
        A command object (e.g. new-sqlcommand), or a datareader object.  Note that the command object or datareader object 
        can come from any class that inherits from System.Data.Common.DbCommand or System.Data.Common.DataReader, so this will work
        with most ADO.NET client libraries (not just SQL Server).

	.PARAMETER  Server
		The destination server to connect to.  

	.PARAMETER  Database
		The initial database for the connection.  

	.PARAMETER  User
		The sql user to use for the connection.  If user is not passed, NT Authentication is used.

	.PARAMETER  Password
		The password for the sql user named by the User parameter.

	.PARAMETER  Table
		The destination table for the bulk copy operation.

	.PARAMETER  Mapping
		A dictionary of column mappings of the form DestColumn=SourceColumn

	.PARAMETER  BatchSize
		The batch size for the bulk copy operation.

	.PARAMETER  Transaction
		A transaction to execute the bulk copy operation in.

	.PARAMETER  NotifyAfter
		The number of rows to fire the notification event after transferring.  0 means don't notify.
        Ex: 1000 means to fire the notify event after each 1000 rows are transferred.
        
    .PARAMETER  NotifyFunction
        A scriptblock to be executed after each $notifyAfter records has been copied.  The second parameter ($param[1]) 
        is a SqlRowsCopiedEventArgs object, which has a RowsCopied property.  The default value for this parameter echoes the
        number of rows copied to the console
        
    .PARAMETER  Options
        An object containing special options to modify the bulk copy operation.
        See http://msdn.microsoft.com/en-us/library/system.data.sqlclient.sqlbulkcopyoptions.aspx for values.


	.EXAMPLE
		PS C:\> $cmd=new-sqlcommand -server MyServer -sql "Select * from MyTable"
        PS C:\> invoke-sqlbulkcopy -records $cmd -server MyOtherServer -table CopyOfMyTable

	.EXAMPLE
		PS C:\> $rows=invoke-query -server MyServer -sql "Select * from MyTable"
        PS C:\> invoke-sqlbulkcopy -records $rows -server MyOtherServer -table CopyOfMyTable

    .INPUTS
        None.
        You cannot pipe objects to invoke-bulkcopy

	.OUTPUTS
		System.Data.SqlClient.SqlCommand

#>
function Invoke-SQLBulkcopy{
  param([Parameter(Position=0, Mandatory=$true)]$records,
        [Parameter(Position=1, Mandatory=$true)]$server,
        [Parameter(Position=2, Mandatory=$false)]$database,
        [Parameter(Position=3, Mandatory=$false)][string]$user,
        [Parameter(Position=4, Mandatory=$false)][string]$password,
        [Parameter(Position=5, Mandatory=$true)][string]$table,
        [Parameter(Position=6, Mandatory=$false)]$mapping=@{},
        [Parameter(Position=7, Mandatory=$false)]$batchsize=0,
        [Parameter(Position=8, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$null,
        [Parameter(Position=9, Mandatory=$false)]$notifyAfter=0,
        [Parameter(Position=10, Mandatory=$false)][scriptblock]$notifyFunction={Write-Host "$($args[1].RowsCopied) rows copied."},
        [Parameter(Position=11, Mandatory=$false)][System.Data.SqlClient.SqlBulkCopyOptions]$options=[System.Data.SqlClient.SqlBulkCopyOptions]::Default)


	$connectionString =New-SQLConnectionString -server $server -database $Database -User $user -password $password


	#Use a transaction if one was specified
	if ($transaction -is [System.Data.SqlClient.SqlTransaction]){
		$bulkCopy=new-object "Data.SqlClient.SqlBulkCopy" $connectionString $options  $transaction
	} else {
		$bulkCopy = new-object "Data.SqlClient.SqlBulkCopy" $connectionString
	}
	$bulkCopy.BatchSize=$batchSize
	$bulkCopy.DestinationTableName = $table
	$bulkCopy.BulkCopyTimeout=10000000
	if ($notifyAfter -gt 0){
		$bulkCopy.NotifyAfter=$notifyafter
		$bulkCopy.Add_SQlRowscopied($notifyFunction)
	}

	#Add column mappings if they were supplied
	foreach ($key in $mapping.Keys){
	    $bulkCopy.ColumnMappings.Add($mapping[$key],$key) | out-null
	}
	
	write-debug "Bulk copy starting at $(get-date)"
	if ($records -is [System.Data.Common.DBCommand]){
		#if passed a command object (rather than a datatable), ask it for a datareader to stream the records
		$bulkCopy.WriteToServer($records.ExecuteReader())
    } elseif ($records -is [System.Data.Common.DbDataReader]){
		#if passed a Datareader object use it to stream the records
		$bulkCopy.WriteToServer($records)
	} else {
		$bulkCopy.WriteToServer($records)
	}
	write-debug "Bulk copy finished at $(get-date)"
}


#define aliases for backwards compatibility 
#New-Alias new-Connection new-sqlconnection
#New-Alias new-Command New-SQLCommand
#New-Alias invoke-query invoke-sqlquery
#New-Alias invoke-Command invoke-sqlcommand
#New-Alias invoke-StoredProcedure invoke-sqlstoredprocedure


#export-modulemember new-connection
export-modulemember *-sql*
#Export-ModuleMember -Alias *