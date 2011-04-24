# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Mike Shepard, Bernd Kriszio
### </Author>
### <Description>
### Defines functions for executing Ado.net queries
### </Description>
### <Usage>
### import-module sqlitelib
###  </Usage>
### </Script>
# ---------------------------------------------------------------------------

# !!!! the following is a workaround because currently installation into GAC is buggy
# !!!! The path must be adapted to your installation

if (! $sqlitedll)
{
    $sqlitedll = [System.Reflection.Assembly]::LoadFrom("C:\Program Files\System.Data.SQLite\bin\System.Data.SQLite.dll") 
    
}

<#
	.SYNOPSIS
		Tests to see if a value is a SQL NULL or not

	.DESCRIPTION
		Returns $true if the value is a SQL NULL.

	.PARAMETER  value
		The value to test

	

	.EXAMPLE
		PS C:\> Is-NULL $row.columnname

	
    .INPUTS
        None.
        You cannot pipe objects to New-SqliteConnection

	.OUTPUTS
		Boolean

#>
function Is-NULL{
  param([Parameter(Position=0, Mandatory=$true)]$value)
  return  [System.DBNull]::Value.Equals($value)
}


<#
	.SYNOPSIS
		Create a SQLConnection object with the given parameters

	.DESCRIPTION
		This function creates a SQLConnection object, using the parameters provided to construct the connection string.  You may optionally provide the initial database, and SQL credentials (to use instead of NT Authentication).

	.PARAMETER  File
		The File for the connection.
	
	.PARAMETER  Password
		The password for the user specified by the User parameter.

	.PARAMETER  rest_of_connectstring
		There are about 20 parameters which can be set by connection string. Here is a hoc to supply the seldom used ones .

	.EXAMPLE
		PS C:\> New-SqliteConnection -file test.db

    .INPUTS
        None.
        You cannot pipe objects to New-SqliteConnection

	.OUTPUTS
		System.Data.SQLite.SQLiteConnection

#>
function New-SqliteConnection{
param([Parameter(Position=0, Mandatory=$true)][string]$file, 
      [Parameter(Position=1, Mandatory=$false)][string]$password='',
      [Parameter(Position=2, Mandatory=$false)][string]$rest_of_connectstring='',
      [switch]$readonly
      )

	$conn = new-object System.Data.SQLite.SQLiteConnection
    
    if ($readonly) { $RO = 'Read Only=True;' } else { $RO = '' }
	if ($password -ne ''){ $PW = "Password=$Password;" } else { $Pw = '' }
    if ($rest_of_connectstring -ne '' -and $rest_of_connectstring[0] -ne ';')
    {
        $rest_of_connectstring = ';' + $rest_of_connectstring
    }

    $conn.ConnectionString="Data Source=$file;$PW$RO$rest_of_connectstring"
    
#    Write-Host "connection String:  $($conn.ConnectionString)"
#    Write-Host "RO $RO"
	$conn.Open()
    write-debug $conn.ConnectionString
	return $conn
}

function Get-SQLiteConnection{
param([System.Data.SQLite.SQLiteConnection]$conn,
      [string]$file, 
      [string]$password='',
      [string]$rest_of_connectstring='',
      [switch]$readonly
      )
	if (-not $conn){
		if ($file){
			$conn = New-SqliteConnection -file $file -password $password -rest_of_connectstring $rest_of_connectstring -readonly:$readonly
		} else {
		    throw "No connection or connection information supplied"
		}
	}
	return $conn
}

# function Put-OutputParameters{
# param([Parameter(Position=0, Mandatory=$true)][System.Data.SQLite.SQLiteCommand]$cmd, 
#       [Parameter(Position=1, Mandatory=$false)][hashtable]$outparams)
#     if ($outparams){
#     	foreach($outp in $outparams.Keys){
#             $paramtype=get-paramtype $outparams[$outp]
#             $p=$cmd.Parameters.Add("@$outp",$paramtype)
#     		$p.Direction=[System.Data.ParameterDirection]::Output
#             if ($paramtype -like '*char*'){
#                $p.Size=[int]$outparams[$outp].Replace($paramtype.ToString().ToLower(),'').Replace('(','').Replace(')','')
#             }
#     	}
#     }
# }

# function Get-Outputparameters{
# param([Parameter(Position=0, Mandatory=$true)][System.Data.SQLite.SQLiteCommand]$cmd,
#       [Parameter(Position=1, Mandatory=$true)][hashtable]$outparams)
# 	foreach($p in $cmd.Parameters){
# 		if ($p.Direction -eq [System.Data.ParameterDirection]::Output){
# 		  $outparams[$p.ParameterName.Replace("@","")]=$p.Value
# 		}
# 	}
# }



# function Get-ParamType{
# param([string]$typename)
# 	$type=switch -wildcard ($typename.ToLower()) {
# 		'uniqueidentifier' {[System.Data.SqlDbType]::UniqueIdentifier}
# 		'int'  {[System.Data.SQLDbType]::Int}
# 		'datetime'  {[System.Data.SQLDbType]::Datetime}
# 		'tinyint'  {[System.Data.SQLDbType]::tinyInt}
# 		'smallint'  {[System.Data.SQLDbType]::smallInt}
# 		'bigint'  {[System.Data.SQLDbType]::BigInt}
# 		'bit'  {[System.Data.SQLDbType]::Bit}
# 		'char*'  {[System.Data.SQLDbType]::char}
# 		'nchar*'  {[System.Data.SQLDbType]::nchar}
# 		'date'  {[System.Data.SQLDbType]::date}
# 		'datetime'  {[System.Data.SQLDbType]::datetime}
#         'varchar*' {[System.Data.SqlDbType]::Varchar}
#         'nvarchar*' {[System.Data.SqlDbType]::nVarchar}
# 		default {[System.Data.SqlDbType]::Int}
# 	}
# 	return $type
# 	
# }
# 
function Copy-HashTable{
param([hashtable]$hash,
[String[]]$include,
[String[]]$exclude)

	if($include){
	   $newhash=@{}
	   foreach ($key in $include){
	    if ($hash.ContainsKey($key)){
	   		$newhash.Add($key,$hash[$key]) | Out-Null 
		}
	   }
	} else {
	   $newhash=$hash.Clone()
	   if ($exclude){
		   foreach ($key in $exclude){
		        if ($newhash.ContainsKey($key)) {
		   			$newhash.Remove($key) | Out-Null 
				}
		   }
	   }
	}
	return $newhash
}

<#
Helper function figure out what kind of returned object to build from the results of a sql call (ds). 
Options are:
	1.  Dataset   (multiple lists of rows)
	2.  Datatable (list of datarows)
	3.  Nothing (no rows and no output variables
	4.  Dataset with output parameter dictionary
	5.  Datatable with output parameter dictionary
	6.  A dictionary of output parameters
	

#>
function Get-CommandResults{
param([Parameter(Position=0, Mandatory=$true)][System.Data.Dataset]$ds #, 
#      [Parameter(Position=1, Mandatory=$true)][HashTable]$outparams
      )   

	if ($ds.tables.count -eq 1){
		$retval= $ds.Tables[0]
	}
	elseif ($ds.tables.count -eq 0){
		$retval=$null
	} else {
		[system.Data.DataSet]$retval= $ds 
	}
# 	if ($outparams.Count -gt 0){
# 		if ($retval){
# 			return @{Results=$retval; OutputParameters=$outparams}
# 		} else {
# 			return $outparams
# 		}
# 	} else {
		return $retval
# 	}
}

# the following doesn't support all the possibilties for ad hoc connections
<#
	.SYNOPSIS
		Create a sql command object

	.DESCRIPTION
		This function uses the information contained in the parameters to create a sql command object.  In general, you will want to use the invoke- functions directly, 
        but if you need to manipulate a command object in ways that those functions don't allow, you will need this.  Also, the invoke-bulkcopy function allows you to pass 
        a command object instead of a set of records in order to "stream" the records into the destination in cases where there are a lot of records and you don't want to
        allocate memory to hold the entire result set.

	.PARAMETER  sql
		The sql to be executed by the command object (although it is not executed by this function).

	.PARAMETER  connection
		An existing connection to perform the sql statement with.  

	.PARAMETER  parameters
		A hashtable of input parameters to be supplied with the query.  See example 2. 
        
	.PARAMETER  timeout
		The commandtimeout value (in seconds).  The command will fail and be rolled back if it does not complete before the timeout occurs.

	.PARAMETER  File
		The file to connect to. 

	.PARAMETER  Password
		The password for the sql user named by the User parameter.

	.PARAMETER  Transaction
		A transaction to execute the sql statement in.

	.EXAMPLE
		PS C:\> $cmd=new-sqlcommand "ALTER DATABASE AdventureWorks Modify Name = Northwind" -server MyServer
        PS C:\> $cmd.ExecuteNonQuery()


	.EXAMPLE
		PS C:\> $cmd=new-sqlcommand -server MyServer -sql "Select * from MyTable"
        PS C:\> invoke-sqlbulkcopy -records $cmd -server MyOtherServer -table CopyOfMyTable

    .INPUTS
        None.
        You cannot pipe objects to new-sqlcommand

	.OUTPUTS
		System.Data.SQLite.SQLiteCommand

#>
function New-SQLiteCommand{
param([Parameter(Position=0, Mandatory=$true)][Alias('storedProcName')][string]$sql,
      [Parameter(ParameterSetName="SuppliedConnection",Position=1, Mandatory=$false)][System.Data.SQLite.SQLiteConnection]$connection,
      [Parameter(Position=2, Mandatory=$false)][hashtable]$parameters=@{},
      [Parameter(Position=3, Mandatory=$false)][int]$timeout=30,
      [Parameter(ParameterSetName="AdHocConnection",Position=4, Mandatory=$false)][string]$file,
      [Parameter(Position=5, Mandatory=$false)][string]$password,
      [Parameter(Position=6, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$null,
	  [Parameter(Position=7, Mandatory=$false)][hashtable]$outparameters=@{})
   
    $dbconn = Get-SqliteConnection -conn $connection -file $file -password $password
    $close = ($dbconn.State -eq [System.Data.ConnectionState]'Closed')
    if ($close) {
        $dbconn.Open()
    }	
    $cmd = new-object System.Data.SQLite.SQLiteCommand($sql,$dbconn)
    $cmd.CommandTimeout=$timeout
    foreach($p in $parameters.Keys){
	    $parm = $cmd.Parameters.AddWithValue("@$p",$parameters[$p])
        if (Is-NULL $parameters[$p]){
           $parm.Value=[DBNull]::Value
        }
    }
    #put-outputparameters $cmd $outparameters

    if ($transaction -is [ System.Data.SQLite.SqliteTransaction]){
	$cmd.Transaction = $transaction
    }
    return $cmd


}


# I do not need this for SqliteISE, but it could be adapted too (Bernd_k)

# <#
# 	.SYNOPSIS
# 		Execute a sql statement, ignoring the result set.  Returns the number of rows modified by the statement (or -1 if it was not a DML staement)
# 
# 	.DESCRIPTION
# 		This function executes a sql statement, using the parameters provided and returns the number of rows modified by the statement.  You may optionally 
#         provide a connection or sufficient information to create a connection, as well as input parameters, command timeout value, and a transaction to join.
# 
# 	.PARAMETER  sql
# 		The SQL Statement
# 
# 	.PARAMETER  connection
# 		An existing connection to perform the sql statement with.  
# 
# 	.PARAMETER  parameters
# 		A hashtable of input parameters to be supplied with the query.  See example 2. 
#         
# 	.PARAMETER  timeout
# 		The commandtimeout value (in seconds).  The command will fail and be rolled back if it does not complete before the timeout occurs.
# 
# 	.PARAMETER  Server
# 		The server to connect to.  If both Server and Connection are specified, Server is ignored.
# 
# 	.PARAMETER  Database
# 		The initial database for the connection.  If both Database and Connection are specified, Database is ignored.
# 
# 	.PARAMETER  User
# 		The sql user to use for the connection.  If both User and Connection are specified, User is ignored.
# 
# 	.PARAMETER  Password
# 		The password for the sql user named by the User parameter.
# 
# 	.PARAMETER  Transaction
# 		A transaction to execute the sql statement in.
# 
# 	.EXAMPLE
# 		PS C:\> invoke-sql "ALTER DATABASE AdventureWorks Modify Name = Northwind" -server MyServer
# 
# 
# 	.EXAMPLE
# 		PS C:\> $con=New-SqliteConnection MyServer
#         PS C:\> invoke-sql "Update Table1 set Col1=null where TableID=@ID" -parameters @{ID=5}
# 
#     .INPUTS
#         None.
#         You cannot pipe objects to invoke-sql
# 
# 	.OUTPUTS
# 		Integer
# 
# #>
# function Invoke-Sqlite{
# param([Parameter(Position=0, Mandatory=$true)][string]$sql,
#       [Parameter(ParameterSetName="SuppliedConnection",Position=1, Mandatory=$false)][System.Data.SqlClient.SQLConnection]$connection,
#       [Parameter(Position=2, Mandatory=$false)][hashtable]$parameters=@{},
#       [Parameter(Position=3, Mandatory=$false)][hashtable]$outparameters=@{},
#       [Parameter(Position=4, Mandatory=$false)][int]$timeout=30,
#       [Parameter(ParameterSetName="AdHocConnection",Position=5, Mandatory=$false)][string]$server,
#       [Parameter(ParameterSetName="AdHocConnection",Position=6, Mandatory=$false)][string]$database,
#       [Parameter(ParameterSetName="AdHocConnection",Position=7, Mandatory=$false)][string]$user,
#       [Parameter(ParameterSetName="AdHocConnection",Position=8, Mandatory=$false)][string]$password,
#       [Parameter(Position=9, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$null)
# 	
# 
#        $cmd=new-sqlcommand @PSBoundParameters
# 
#        #if it was an ad hoc connection, close it
#        if ($server){
#           $cmd.connection.close()
#        }	
# 
#        return $cmd.ExecuteNonQuery()
# 	
# }
<#
	.SYNOPSIS
		Execute a sql statement, returning the results of the query.  

	.DESCRIPTION
		This function executes a sql statement, using the parameters provided (both input and output) and returns the results of the query.  You may optionally 
        provide a connection or sufficient information to create a connection, as well as input and output parameters, command timeout value, and a transaction to join.

	.PARAMETER  sql
		The SQL Statement

	.PARAMETER  connection
		An existing connection to perform the sql statement with.  

	.PARAMETER  parameters
		A hashtable of input parameters to be supplied with the query.  See example 2. 

	.PARAMETER  outparameters
		A hashtable of input parameters to be supplied with the query.  Entries in the hashtable should have names that match the parameter names, and string values that are the type of the parameters. See example 3. 
        
	.PARAMETER  timeout
		The commandtimeout value (in seconds).  The command will fail and be rolled back if it does not complete before the timeout occurs.

	.PARAMETER  Server
		The server to connect to.  If both Server and Connection are specified, Server is ignored.

	.PARAMETER  Database
		The initial database for the connection.  If both Database and Connection are specified, Database is ignored.

	.PARAMETER  User
		The sql user to use for the connection.  If both User and Connection are specified, User is ignored.

	.PARAMETER  Password
		The password for the sql user named by the User parameter.

	.PARAMETER  Transaction
		A transaction to execute the sql statement in.
    .EXAMPLE
        This is an example of a query that returns a single result.  
        PS C:\> $c=New-SqliteConnection '.\sqlexpress'
        PS C:\> $res=invoke-query 'select * from master.dbo.sysdatabases' -conn $c
        PS C:\> $res 
   .EXAMPLE
        This is an example of a query that returns 2 distinct result sets.  
        PS C:\> $c=New-SqliteConnection '.\sqlexpress'
        PS C:\> $res=invoke-query 'select * from master.dbo.sysdatabases; select * from master.dbo.sysservers' -conn $c
        PS C:\> $res.Tables[1]
    .EXAMPLE
        This is an example of a query that returns a single result and uses a parameter.  It also generates its own (ad hoc) connection.
        PS C:\> invoke-query 'select * from master.dbo.sysdatabases where name=@dbname' -param  @{dbname='master'} -server '.\sqlexpress' -database 'master'

     .INPUTS
        None.
        You cannot pipe objects to invoke-query

   .OUTPUTS
        Several possibilities (depending on the structure of the query and the presence of output variables)
        1.  A list of rows 
        2.  A dataset (for multi-result set queries)
        3.  An object that contains a dictionary of ouptut parameters and their values and either 1 or 2 (for queries that contain output parameters)
#>
function Invoke-SqliteQuery{
param( [Parameter(Position=0, Mandatory=$true)][string]$sql,
       [Parameter(ParameterSetName="SuppliedConnection", Position=1, Mandatory=$false)][System.Data.SQLite.SQLiteConnection]$connection,
       [Parameter(Position=2, Mandatory=$false)][hashtable]$parameters=@{},
       [Parameter(Position=3, Mandatory=$false)][hashtable]$outparameters=@{},
       [Parameter(Position=4, Mandatory=$false)][int]$timeout=30,
       [Parameter(ParameterSetName="AdHocConnection",Position=5, Mandatory=$false)][string]$file,
       [Parameter(ParameterSetName="AdHocConnection",Position=6, Mandatory=$false)][string]$password,
       [Parameter(Position=7, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$null,
       [Parameter(Position=8, Mandatory=$false)] [ValidateSet("DataSet", "DataTable", "DataRow", "Dynamic")] [string]$AsResult="Dynamic"
       )
    
	$connectionparameters = copy-hashtable $PSBoundParameters -exclude AsResult
    $cmd = new-sqlitecommand @connectionparameters
    $ds = New-Object system.Data.DataSet
    $da = New-Object System.Data.SQLite.SqliteDataAdapter($cmd)
    $da.fill($ds) | Out-Null
    
    #if it was an ad hoc connection, close it
    if ($file){
       $cmd.connection.close()
    }
    #get-outputparameters $cmd $outparameters
    switch ($AsResult)
    {
        'DataSet'   { $result = $ds }
        'DataTable' { $result = $ds.Tables }
        'DataRow'   { $result = $ds.Tables[0] }
        'Dynamic'   { $result = get-commandresults $ds $outparameters } 
    }
    return $result
}


# SQLite doesn't support stored procedures

# <#
# 	.SYNOPSIS
# 		Execute a stored procedure, returning the results of the query.  
# 
# 	.DESCRIPTION
# 		This function executes a stored procedure, using the parameters provided (both input and output) and returns the results of the query.  You may optionally 
#         provide a connection or sufficient information to create a connection, as well as input and output parameters, command timeout value, and a transaction to join.
# 
# 	.PARAMETER  sql
# 		The SQL Statement
# 
# 	.PARAMETER  connection
# 		An existing connection to perform the sql statement with.  
# 
# 	.PARAMETER  parameters
# 		A hashtable of input parameters to be supplied with the query.  See example 2. 
# 
# 	.PARAMETER  outparameters
# 		A hashtable of input parameters to be supplied with the query.  Entries in the hashtable should have names that match the parameter names, and string values that are the type of the parameters. 
#         Note:  not all types are accounted for by the code. int, uniqueidentifier, varchar(n), and char(n) should all work, though.
#         
# 	.PARAMETER  timeout
# 		The commandtimeout value (in seconds).  The command will fail and be rolled back if it does not complete before the timeout occurs.
# 
# 	.PARAMETER  Server
# 		The server to connect to.  If both Server and Connection are specified, Server is ignored.
# 
# 	.PARAMETER  Database
# 		The initial database for the connection.  If both Database and Connection are specified, Database is ignored.
# 
# 	.PARAMETER  User
# 		The sql user to use for the connection.  If both User and Connection are specified, User is ignored.
# 
# 	.PARAMETER  Password
# 		The password for the sql user named by the User parameter.
# 
# 	.PARAMETER  Transaction
# 		A transaction to execute the sql statement in.
#     .EXAMPLE
#         #Calling a simple stored procedure with no parameters
#         PS C:\> $c=New-SqliteConnection -server '.\sqlexpress' 
#         PS C:\> invoke-storedprocedure 'sp_who2' -conn $c
#     .EXAMPLE 
#         #Calling a stored procedure that has an output parameter and multiple result sets
#         PS C:\> $c=New-SqliteConnection '.\sqlexpress'
#         PS C:\> $res=invoke-storedprocedure -storedProcName 'AdventureWorks2008.dbo.stp_test' -outparameters @{LogID='int'} -conne $c
#         PS C:\> $res.Results.Tables[1]
#         PS C:\> $res.OutputParameters
#         
#         For reference, here's the stored procedure:
#         CREATE procedure [dbo].[stp_test]
#             @LogID int output
#         as
#             set @LogID=5
#             select * from master.dbo.sysdatabases
#             select * from master.dbo.sysservers
#     .EXAMPLE 
#         #Calling a stored procedure that has an input parameter
#         PS C:\> invoke-storedprocedure 'sp_who2' -conn $c -parameters @{loginame='sa'}
#     .INPUTS
#         None.
#         You cannot pipe objects to invoke-storedprocedure
# 
#     .OUTPUTS
#         Several possibilities (depending on the structure of the query and the presence of output variables)
#         1.  A list of rows 
#         2.  A dataset (for multi-result set queries)
#         3.  An object that contains a hashtables of ouptut parameters and their values and either 1 or 2 (for queries that contain output parameters)
# #>
# function Invoke-StoredProcedure{
# param([Parameter(Position=0, Mandatory=$true)][string]$storedProcName,
#       [Parameter(ParameterSetName="SuppliedConnection",Position=1, Mandatory=$false)][System.Data.SqlClient.SqlConnection]$connection,
#       [Parameter(Position=2, Mandatory=$false)][hashtable] $parameters=@{},
#       [Parameter(Position=3, Mandatory=$false)][hashtable]$outparameters=@{},
#       [Parameter(Position=4, Mandatory=$false)][int]$timeout=30,
#       [Parameter(ParameterSetName="AdHocConnection",Position=5, Mandatory=$false)][string]$server,
#       [Parameter(ParameterSetName="AdHocConnection",Position=6, Mandatory=$false)][string]$database,
#       [Parameter(ParameterSetName="AdHocConnection",Position=7, Mandatory=$false)][string]$user,
#       [Parameter(ParameterSetName="AdHocConnection",Position=8, Mandatory=$false)][string]$password,
#       [Parameter(Position=9, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$null) 
# 
# 	$cmd=new-sqlcommand @PSBoundParameters
# 	$cmd.CommandType=[System.Data.CommandType]::StoredProcedure  
#     $ds=New-Object system.Data.DataSet
#     $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
#     $da.fill($ds) | out-null
# 
#     get-outputparameters $cmd $outparameters
# 
#     #if it was an ad hoc connection, close it
#     if ($server){
#        $cmd.connection.close()
#     }	
# 	
#     return (get-commandresults $ds $outparameters)
# }

# There is no sqliteSQLBulkCopy as part of the ADO.NET provider

# <#
# 	.SYNOPSIS
# 		Uses the .NET SQLBulkCopy class to quickly copy rows into a destination table.
# 
# 	.DESCRIPTION
#         
# 		Also, the invoke-bulkcopy function allows you to pass a command object instead of a set of records in order to "stream" the records
#         into the destination in cases where there are a lot of records and you don't want to allocate memory to hold the entire result set.
# 
# 	.PARAMETER  records
# 		Either a datatable (like one returned from invoke-query or invoke-storedprocedure) or
#         A command object (e.g. new-sqlcommand), or a datareader object.  Note that the command object or datareader object 
#         can come from any class that inherits from System.Data.Common.DbCommand or System.Data.Common.DataReader, so this will work
#         with most ADO.NET client libraries (not just SQL Server).
# 
# 	.PARAMETER  Server
# 		The destination server to connect to.  
# 
# 	.PARAMETER  Database
# 		The initial database for the connection.  
# 
# 	.PARAMETER  User
# 		The sql user to use for the connection.  If user is not passed, NT Authentication is used.
# 
# 	.PARAMETER  Password
# 		The password for the sql user named by the User parameter.
# 
# 	.PARAMETER  Table
# 		The destination table for the bulk copy operation.
# 
# 	.PARAMETER  Mapping
# 		A dictionary of column mappings of the form DestColumn=SourceColumn
# 
# 	.PARAMETER  BatchSize
# 		The batch size for the bulk copy operation.
# 
# 	.PARAMETER  Transaction
# 		A transaction to execute the bulk copy operation in.
# 
# 	.PARAMETER  NotifyAfter
# 		The number of rows to fire the notification event after transferring.  0 means don't notify.
#         Ex: 1000 means to fire the notify event after each 1000 rows are transferred.
#         
#     .PARAMETER  NotifyFunction
#         A scriptblock to be executed after each $notifyAfter records has been copied.  The second parameter ($param[1]) 
#         is a SqlRowsCopiedEventArgs object, which has a RowsCopied property.  The default value for this parameter echoes the
#         number of rows copied to the console
#         
#     .PARAMETER  Options
#         An object containing special options to modify the bulk copy operation.
#         See http://msdn.microsoft.com/en-us/library/system.data.sqlclient.sqlbulkcopyoptions.aspx for values.
# 
# 
# 	.EXAMPLE
# 		PS C:\> $cmd=new-sqlcommand -server MyServer -sql "Select * from MyTable"
#         PS C:\> invoke-sqlbulkcopy -records $cmd -server MyOtherServer -table CopyOfMyTable
# 
# 	.EXAMPLE
# 		PS C:\> $rows=invoke-query -server MyServer -sql "Select * from MyTable"
#         PS C:\> invoke-sqlbulkcopy -records $rows -server MyOtherServer -table CopyOfMyTable
# 
#     .INPUTS
#         None.
#         You cannot pipe objects to invoke-bulkcopy
# 
# 	.OUTPUTS
# 		System.Data.SqlClient.SqlCommand
# 
# #>
# function Invoke-Bulkcopy{
#   param([Parameter(Position=0, Mandatory=$true)]$records,
#         [Parameter(Position=1, Mandatory=$true)]$server,
#         [Parameter(Position=2, Mandatory=$false)]$database,
#         [Parameter(Position=3, Mandatory=$false)][string]$user,
#         [Parameter(Position=4, Mandatory=$false)][string]$password,
#         [Parameter(Position=5, Mandatory=$true)][string]$table,
#         [Parameter(Position=6, Mandatory=$false)]$mapping=@{},
#         [Parameter(Position=7, Mandatory=$false)]$batchsize=0,
#         [Parameter(Position=8, Mandatory=$false)][System.Data.SqlClient.SqlTransaction]$transaction=$null,
#         [Parameter(Position=9, Mandatory=$false)]$notifyAfter=0,
#         [Parameter(Position=10, Mandatory=$false)][scriptblock]$notifyFunction={Write-Host "$($args[1].RowsCopied) rows copied."},
#         [Parameter(Position=11, Mandatory=$false)][System.Data.SqlClient.SqlBulkCopyOptions]$options=[System.Data.SqlClient.SqlBulkCopyOptions]::Default)
# 
# 	#use existing "New-SqliteConnection" function to create a connection string.        
#     $connection=New-SqliteConnection -server $server -database $Database -User $user -password $password
# 	$connectionString = $connection.ConnectionString
# 	$connection.close()
# 
# 	#Use a transaction if one was specified
# 	if ($transaction -is [System.Data.SqlClient.SqlTransaction]){
# 		$bulkCopy=new-object "Data.SqlClient.SqlBulkCopy" $connectionString $options  $transaction
# 	} else {
# 		$bulkCopy = new-object "Data.SqlClient.SqlBulkCopy" $connectionString
# 	}
# 	$bulkCopy.BatchSize=$batchSize
# 	$bulkCopy.DestinationTableName = $table
# 	$bulkCopy.BulkCopyTimeout=10000000
# 	if ($notifyAfter -gt 0){
# 		$bulkCopy.NotifyAfter=$notifyafter
# 		$bulkCopy.Add_SQlRowscopied($notifyFunction)
# 	}
# 
# 	#Add column mappings if they were supplied
# 	foreach ($key in $mapping.Keys){
# 	    $bulkCopy.ColumnMappings.Add($mapping[$key],$key) | out-null
# 	}
# 	
# 	write-debug "Bulk copy starting at $(get-date)"
# 	if ($records -is [System.Data.Common.DBCommand]){
# 		#if passed a command object (rather than a datatable), ask it for a datareader to stream the records
# 		$bulkCopy.WriteToServer($records.ExecuteReader())
#     } elsif ($records -is [System.Data.Common.DbDataReader]){
# 		#if passed a Datareader object use it to stream the records
# 		$bulkCopy.WriteToServer($records)
# 	} else {
# 		$bulkCopy.WriteToServer($records)
# 	}
# 	write-debug "Bulk copy finished at $(get-date)"
# }



export-modulemember New-SqliteConnection
export-modulemember new-sqlitecommand
# export-modulemember invoke-sqlite
export-modulemember invoke-Sqlitequery
# export-modulemember invoke-storedprocedure
# export-modulemember invoke-bulkcopy