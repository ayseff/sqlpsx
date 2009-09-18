function get-outputparameters($cmd,$outparams,[switch]$help){
    if ($help)   {
        $msg = @"
Helper function to get the values of output parameters from the results of a stored procedure or parameterized sql call.
cmd is a command object containing a reference to the sql or stored procedure. 
outparams is a dictionary of parameter names and their values.

Usage: get-outputparameters cmd outparams [-help]
"@
        Write-Host $msg
        return
    }
    foreach($p in $cmd.Parameters){
        if ($p.Direction -eq [System.Data.ParameterDirection]::Output){
        $outparams[$p.ParameterName.Replace("@","")]=$p.Value
        }
    }
}

function HandleReturn($ds, $outparams,[switch]$help)   {
    if ($help){
        $msg = @"
Helper function figure out what kind of returned object to build from the results of a sql call (ds).
Options are:
    1.  Dataset   (multiple lists of rows)
    2.  Datatable (list of datarows)
    3.  Nothing (no rows and no output variables
    4.  Dataset with output parameter dictionary
    5.  Datatable with output parameter dictionary
    6.  A dictionary of output parameters
   
Usage: HandleReturn ds outparams [-help]
"@
        Write-Host $msg
        return
    }
    if ($ds.tables.count -eq 1){
        $retval= $ds.Tables[0]
    }
    elseif ($ds.tables.count -eq 0){
        $retval=$null
    }
    else {
        [system.Data.DataSet]$retval= $ds
    }
    if ($outparams.Count -gt 0){
        if ($retval){
            return @{Output=$retval; OutputParameters=$outparams}
        } else
        {
            return $outparams
        }
    }
    else{
        return $retval
    }
}

function get-paramtype($typename,[switch]$help){
    if ($help){
        $msg = @"
Helper function to map the name of a sql datatype to a variable of that type.

Usage: get-paramtype typename [-help]
"@
        Write-Host $msg
        return
    }
    switch ($typename){
        'uniqueidentifier' {[System.Data.SqlDbType]::UniqueIdentifier}
        default {[System.Data.SqlDbType]::Varchar}
    }
}

function exec-query( $sql,$parameters=@{},$outparams=@{},$conn,$timeout=30,[switch]$help){
    if ($help){
        $msg = @"
Execute a sql statement.  Parameters are allowed. 
Input parameters should be a dictionary of parameter names and values.
Output parameters should be a dictionary of parameter names and types.
Return value will usually be a list of datarows.

Usage: exec-query sql [inputparameters] [outputparameters] [conn] [-help]
"@
        Write-Host $msg
        return
    }
  
    $cmd=new-object system.Data.SqlClient.SqlCommand($sql,$conn)
    $cmd.CommandTimeout=$timeout
    foreach($p in $parameters.Keys){
               $cmd.Parameters.AddWithValue("@$p",$parameters[$p]) | Out-Null
    }
    put-outputparameters $cmd $outparams
    $ds=New-Object system.Data.DataSet
    $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
    $da.fill($ds) | Out-Null
 

    get-outputparameters $cmd $outparams
   
    return HandleReturn $ds $outparams
}