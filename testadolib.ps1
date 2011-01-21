ipmo adolib -Force 

function AssertEquals{
param($lhs,$rhs,$description)
if ($lhs -eq $rhs){ 
	Write-Host "$description PASSED" -BackgroundColor Green 
} else {
	Write-Host "$description FAILED" -BackgroundColor Red
}
}

$server = '.'
$db = 'AdventureWorks'
$sql = "SELECT * from Person.Contact"

#test simple query using ad hoc connection and NT authentication
$rows=invoke-query -sql $sql -server $server -database $db
AssertEquals $rows.Count 19972 "ad hoc connection with NT auth" 

#test simple query using ad hoc connection and SQL login
$rows=invoke-query -sql $sql -server $server -database $db -user test_login -password 12345
AssertEquals $rows.Count 19972 "ad hoc connection with SQL Login" 

#test parameterized query with ad hoc connection and sql login
$rows=@(invoke-query -sql 'select * from Person.Contact where EMailAddress like @add' -server $server -database $db -user test_login -password 12345 -parameters @{add='gustavo0@adventure-works.com'})
AssertEquals $rows.Count 1 "parameterized query with sql login" 

#test parameterized query with ad hoc connection and sql login
$rows=@(invoke-query -sql 'select * from Person.Contact where EMailAddress like @add' -server $server -database $db  -parameters @{add='gustavo0@adventure-works.com'})
AssertEquals $rows.Count 1 "parameterized query with NT Auth" 

Remove-Variable conn
$conn=new-connection  -server $server -database $db

#test simple query using shared connection and NT authentication
$rows=invoke-query -sql $sql -conn $conn 
AssertEquals $rows.Count 19972 "shared connection with NT auth" 

#test parameterized query with shared connection and NT Auth
$rows=@(invoke-query -sql 'select * from Person.Contact where EMailAddress like @add' -conn $conn  -parameters @{add='gustavo0@adventure-works.com'})
AssertEquals $rows.Count 1 "parameterized query with shared connection and NT Auth" 

$conn.Close()

remove-variable conn

$conn=new-connection  -server $server -database $db  -user test_login -password 12345


#test simple query using shared connection and SQL login
$rows=invoke-query -sql $sql -conn $conn 
AssertEquals $rows.Count 19972 "shared connection and SQL login" 

#test parameterized query with shared connection and sql login
$rows=@(invoke-query -sql 'select * from Person.Contact where EMailAddress like @add' -conn $conn  -parameters @{add='gustavo0@adventure-works.com'})
AssertEquals $rows.Count 1 "parameterized query with shared connection and sql login" 
 
#test stored procedure query with shared connection and sql login and IN parameters
$rows=@(invoke-storedprocedure  -storedProcName uspGetManagerEmployees  -conn $conn  -parameters @{ManagerID=51})
AssertEquals $rows.Count 8 "parameterized query (in) with shared connection and sql login" 

#test stored procedure query with shared connection and sql login and out parameters
$outRows=@(invoke-storedprocedure  -storedProcName stp_TestOutParam  -conn $conn  -parameters @{EMailAddress='gustavo0@adventure-works.com'} -outparameters @{ContactID='int'})
AssertEquals ($outRows[0].ContactID -is [Int]) $true "parameterized query (out) with shared connection and sql login" 

#test NULL parameters
$rows=invoke-query "SELECT * from Person.Contact where @parm is NULL" -conn $conn -parameters @{parm=[System.DBNull]::Value}
AssertEquals $rows.Count 19972 "shared connection null parameters" 

#test simple query using ad hoc connection and SQL Login with "-AsResult DataTable"
$rows=invoke-query -sql $sql -server $server -database $db -user test_login -password 12345 -AsResult DataTable
AssertEquals ($rows -is [Data.DataTable]) $true  "ad hoc connection with SQL Login as DataTable" 

#test simple query using ad hoc connection and SQL Login with "-AsResult DataSet"
$rows=invoke-query -sql $sql -server $server -database $db -user test_login -password 12345 -AsResult DataSet
AssertEquals ($rows -is [Data.DataSet]) $true  "ad hoc connection with SQL Login as DataSet" 


#test simple query using ad hoc connection and SQL Login with "-AsResult DataRow"
$rows=@(invoke-query -sql $sql -server $server -database $db -user test_login -password 12345 -AsResult DataRow)
AssertEquals ($rows[0] -is [Data.DataRow]) $true  "ad hoc connection with SQL Login as DataRow" 