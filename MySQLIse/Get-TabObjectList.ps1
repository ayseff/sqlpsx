function Get-TabObjectList
{
    $db = @"
SELECT DATABASE() AS 'Database';
"@
    $col = @"
SELECT TABLE_SCHEMA AS 'Database',
       TABLE_SCHEMA AS 'Schema', 
       TABLE_NAME AS 'Object',
       COLUMN_NAME AS 'Column'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME;
"@

    $tbl = @"
SELECT TABLE_SCHEMA AS 'Database',
       TABLE_SCHEMA AS 'Schema',
       TABLE_NAME AS 'Object'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
AND TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_SCHEMA, TABLE_NAME;
"@

    $rtn = @"
SELECT ROUTINE_SCHEMA AS 'Database', 
       ROUTINE_SCHEMA AS 'Schema', 
       ROUTINE_NAME AS 'Object'
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = DATABASE()
AND ROUTINE_TYPE =  'PROCEDURE'
ORDER BY ROUTINE_SCHEMA, ROUTINE_NAME;
"@

    $prm = @"
SELECT SPECIFIC_SCHEMA AS 'Database', 
       SPECIFIC_SCHEMA AS 'Schema', 
       SPECIFIC_NAME AS 'Object',
       PARAMETER_NAME AS 'Parameter'
FROM INFORMATION_SCHEMA.PARAMETERS
WHERE SPECIFIC_SCHEMA = DATABASE()
AND PARAMETER_NAME IS NOT NULL AND PARAMETER_NAME != ''
ORDER BY SPECIFIC_CATALOG, SPECIFIC_SCHEMA, SPECIFIC_NAME, PARAMETER_NAME;
"@

    $sch = @"
SELECT SCHEMA_NAME AS 'Database', 
    SCHEMA_NAME AS 'Schema'
FROM INFORMATION_SCHEMA.SCHEMATA 
WHERE SCHEMA_NAME = DATABASE()
ORDER BY SCHEMA_NAME
"@    
    $cmd = @"
$db
$tbl
$col
$rtn
$prm
$sch
"@

    $global:dsDbObjects = New-Object system.Data.DataSet
    $da = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($cmd,$conn)

    [void]$da.TableMappings.Add("Table", "Database")
    [void]$da.TableMappings.Add("Table1", "Table")
    [void]$da.TableMappings.Add("Table2", "Column")
    [void]$da.TableMappings.Add("Table3", "Routine")
    [void]$da.TableMappings.Add("Table4", "Parameter")
    [void]$da.TableMappings.Add("Table5", "Schema")

    [void]$da.Fill($global:dsDbObjects)

}
