<#
	.SYNOPSIS
		Create a OracleConnection object with the given parameters

	.DESCRIPTION
		This function creates a Connection object, using the parameters provided to construct the connection string from SQL credentials.

	.PARAMETER  tns
		The tns name of the Database to connect to. 

    .PARAMETER  User
		The SQLUser you wish to use for the connection
        
	.PARAMETER  Password
		The password for the user specified by the User parameter.

	.EXAMPLE
		PS C:\> Get-Something -tns MYDATABASE -user sa -password sapassword

    .INPUTS
        None.
        You cannot pipe objects to New-connection

	.OUTPUTS
		Oracle.DataAccess.Client.OracleConnection

#>
function new-Oracle_connection{
param([Parameter(Position=0, Mandatory=$true)][string]$tns, 
      [Parameter(Position=1, Mandatory=$false)][string]$user='',
      [Parameter(Position=2, Mandatory=$false)][string]$password='')

#	$conn=new-object System.Data.OracleClient.OracleConnection
	$conn=new-object Oracle.DataAccess.Client.OracleConnection
	$conn.ConnectionString="Data Source=$tns;User ID=$user;Password=$password"
	$conn.Open()
    write-debug $conn.ConnectionString
	return $conn
}

function get-oracle_connection{
#param([System.Data.OracleClient.OracleConnection]$conn,
param([Oracle.DataAccess.Client.OracleConnection]$conn,
      [string]$tns, 
      [string]$user,
      [string]$password
      )

	if (-not $conn){
		if ($tns){
            $conn = new-oracle_connection -tns $tns -user $user -password $password
		} else {
		    throw "No connection or connection information supplied"
		}
	}
	return $conn
}

