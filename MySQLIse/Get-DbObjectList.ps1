function Get-DbObjectList
{
    $db = @"
SELECT DATABASE() AS 'Database';
"@

    $pk = @"
SELECT kcu.TABLE_NAME AS 'Table', 
       kcu.COLUMN_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS kcu
ON kcu.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
AND kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
AND kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA
AND kcu.TABLE_NAME = tc.TABLE_NAME
WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
AND tc.TABLE_SCHEMA = DATABASE()
ORDER BY kcu.COLUMN_NAME;
"@

    $fk = @"
SELECT DISTINCT C.TABLE_NAME AS 'Table',
                RC.REFERENCED_TABLE_NAME AS 'Relation'
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS C
INNER JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS RC 
ON C.CONSTRAINT_SCHEMA = RC.CONSTRAINT_SCHEMA 
AND C.CONSTRAINT_NAME = RC.CONSTRAINT_NAME 
WHERE  C.CONSTRAINT_TYPE = 'FOREIGN KEY'
AND C.TABLE_SCHEMA = DATABASE();
"@

    $col = @"
SELECT  TABLE_NAME AS 'Table', 
        CONCAT (COLUMN_NAME, ' (',
CASE WHEN CHARACTER_MAXIMUM_LENGTH > 0 THEN CONCAT(DATA_TYPE, '(',  TRIM(CAST(CHARACTER_MAXIMUM_LENGTH AS CHAR(4))), ')')
ELSE DATA_TYPE END, ',',
CASE IS_NULLABLE
WHEN 'YES' THEN 'null'
WHEN 'NO' THEN 'not null'
END, ')' ) AS 'Column'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;
"@

    $tbl = @"
SELECT TABLE_SCHEMA AS 'Database',
       TABLE_NAME AS 'Table'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
AND TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_SCHEMA, TABLE_NAME;
"@

# Todo Trigger & Index
    $op = @"
SELECT TABLE_NAME AS 'Table',
       CONCAT(CONSTRAINT_NAME, '(', CONSTRAINT_TYPE , ')') AS operation
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA IS NOT NULL
AND TABLE_SCHEMA = DATABASE()
UNION
SELECT EVENT_OBJECT_TABLE AS 'Table', 
CONCAT(TRIGGER_NAME, '(Trigger)')
FROM INFORMATION_SCHEMA.TRIGGERS
WHERE TRIGGER_SCHEMA = DATABASE()
UNION
SELECT TABLE_NAME AS 'Table', 
CONCAT(INDEX_NAME, '(Index)')
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY 2;
"@

    $vw = @"
SELECT TABLE_SCHEMA AS 'Database',   
       TABLE_NAME AS 'Table'
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_SCHEMA, TABLE_NAME;
"@

    $rtn = @'
SET sql_mode='ansi';
SELECT  ROUTINE_NAME,
        ROUTINE_SCHEMA AS 'Database',
        CONCAT(ROUTINE_NAME, ' (',
CASE ROUTINE_TYPE
WHEN 'PROCEDURE' THEN 'P'
ELSE 'F'
END, ')') AS 'Routine'
FROM INFORMATION_SCHEMA.ROUTINES
ORDER BY ROUTINE_TYPE, ROUTINE_SCHEMA, ROUTINE_NAME;
'@

    $prm = @"
SELECT SPECIFIC_NAME AS 'ROUTINE_NAME',
       CONCAT(PARAMETER_NAME, ' (', 
CASE 
WHEN CHARACTER_MAXIMUM_LENGTH > 0 THEN CONCAT(DATA_TYPE, '(', TRIM(CAST(CHARACTER_MAXIMUM_LENGTH AS CHAR(4))), ')')
ELSE DATA_TYPE END, ',',
CASE PARAMETER_MODE
WHEN 'IN' THEN 'Input'
WHEN 'OUT' THEN 'Output'
WHEN 'INOUT' THEN 'Input/Output'
END, ')') AS 'Parameter'
FROM INFORMATION_SCHEMA.PARAMETERS
WHERE PARAMETER_NAME IS NOT NULL AND PARAMETER_NAME != ''
AND SPECIFIC_SCHEMA = DATABASE()
ORDER BY SPECIFIC_SCHEMA, SPECIFIC_NAME, ORDINAL_POSITION;
"@

    $cmd = @"
$db
$tbl
$col
$pk
$fk
$op
$vw
$rtn
$prm
"@

    $ds = New-Object system.Data.DataSet
    $da = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($cmd,$conn)

    [void]$da.TableMappings.Add("Table", "Database")
    [void]$da.TableMappings.Add("Table1", "Table")
    [void]$da.TableMappings.Add("Table2", "Column")
    [void]$da.TableMappings.Add("Table3", "Keys")
    [void]$da.TableMappings.Add("Table4", "Relations")
    [void]$da.TableMappings.Add("Table5", "Operations")
    [void]$da.TableMappings.Add("Table6", "View")
    [void]$da.TableMappings.Add("Table7", "Routine")
    [void]$da.TableMappings.Add("Table8", "Parameter")

    [void]$da.Fill($ds)

    $database = $ds.Tables["Database"]
    $table = $ds.Tables["Table"]
    $column = $ds.Tables["Column"]
    $keys = $ds.Tables["Keys"]
    $relations = $ds.Tables["Relations"]
    $operations = $ds.Tables["Operations"]
    $view = $ds.Tables["View"]
    $routine = $ds.Tables["Routine"]
    $parameter = $ds.Tables["Parameter"]

    $database2Table = new-object System.Data.DataRelation -ArgumentList "Database2Table",$database.Columns["Database"],$table.Columns["Database"],$false
    $ds.Relations.Add($database2Table)

    $table2Column = new-object System.Data.DataRelation -ArgumentList "Table2Column",$table.Columns["Table"],$column.Columns["Table"],$false
    $ds.Relations.Add($table2Column)

    $table2Keys = new-object System.Data.DataRelation -ArgumentList "Table2Keys",$table.Columns["Table"],$keys.Columns["Table"],$false
    $ds.Relations.Add($table2Keys)

    $table2Relations = new-object System.Data.DataRelation -ArgumentList "Table2Relations",$table.Columns["Table"],$relations.Columns["Table"],$false
    $ds.Relations.Add($table2Relations)

    $table2Operations = new-object System.Data.DataRelation -ArgumentList "Table2Operations",$table.Columns["Table"],$operations.Columns["Table"],$false
    $ds.Relations.Add($table2Operations)

    $database2View = new-object System.Data.DataRelation -ArgumentList "Database2View",$database.Columns["Database"],$view.Columns["Database"],$false
    $ds.Relations.Add($database2View)

    $view2Column = new-object System.Data.DataRelation -ArgumentList "View2Column",$view.Columns["Table"],$column.Columns["Table"],$false
    $ds.Relations.Add($view2Column)

    $database2Routine = new-object System.Data.DataRelation -ArgumentList "Database2Routine",$database.Columns["Database"],$routine.Columns["Database"],$false
    $ds.Relations.Add($database2Routine)

    $routine2Parameter = new-object System.Data.DataRelation -ArgumentList "Routine2Parameter",$routine.Columns["ROUTINE_NAME"],$Parameter.Columns["ROUTINE_NAME"],$false
    $ds.Relations.Add($routine2Parameter)

    $ds
}