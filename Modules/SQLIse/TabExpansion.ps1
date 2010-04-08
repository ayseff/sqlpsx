function tabexpansion
{
            param($line, $lastWord)
                ### START CUSTOM functions for SQLIse
                #######################
                function Write-DbObjects
                {
                     param($base,$objType,$expression)
                     
                     $objects = @()
                     $rawObjArray = $base -split '\.'
                     
                     switch ($rawObjArray.Count)
                     {
                        1 {$dbObj = $rawObjArray[0]}
                        2 {$schema = $rawObjArray[0]; $dbObj = $rawObjArray[1]}
                        3 {$db = $rawObjArray[0]; $schema = $rawObjArray[1]; $dbObj = $rawObjArray[2]}
                     }
                     
                     $expression = $expression.Trim("$dbObj")
                     $dbObj = $dbObj.Trim('*')
                     $dbObj = $dbObj + '%'
                     
                     switch ($rawObjArray.Count)
                     {
                       1 {$objQry = "Object like '$dbObj'"
                           $global:dsDbObjects.Tables["Database"].select("Database like '$dbObj'") | % {$objects += ,$_.Database}
                           $global:dsDbObjects.Tables["Schema"].select("Schema like '$dbObj'") | % {$objects += ,$_.Schema}}
                       2 {if ($schema = $global:conn.database) {
                            $objQry = "Object = '0'" 
                            $global:dsDbObjects.Tables["Schema"].select("Schema like '$dbObj'") | % {$objects += ,$_.Schema}}
                          else {$objQry = "Schema = '$schema' and Object like '$dbObj'"}}
                       3 {if ($schema) { $objQry = "Database = '$db' and Schema = '$schema' and Object like '$dbObj'"}
                           else {$objQry = "Database = '$db' and Object like '$dbObj'"}}
                     }

                     if ($objType -eq 'Table')
                     { $global:dsDbObjects.Tables["Table"].select($objQry) | % {$objects += ,$_.Object} }
                     else
                     { $global:dsDbObjects.Tables["Routine"].select($objQry) | % {$objects += ,$_.Object} }
                     
                     foreach ($object in $objects)
                     {
                        if ($object -notmatch 'True|False')
                        { $expression + $object }
                     }

                } #Write-DbObjects
                
                #######################
                function Write-Parmeters
                {
                     param($base,$pat)
                     
                     $objects = @()
                     $rawObjArray = $base -split '\.'
                     $pat = $pat.Trim('*')
                     $pat = $pat + '%'
                     
                     switch ($rawObjArray.Count)
                     {
                        1 {$dbObj = $rawObjArray[0] }
                        2 {$schema = $rawObjArray[0]; $dbObj = $rawObjArray[1]}
                        3 {$db = $rawObjArray[0]; $schema = $rawObjArray[1]; $dbObj = $rawObjArray[2]}
                     }
                     
                     switch ($rawObjArray.Count)
                     {
                       1 {$objQry = "Object = '$dbObj' and Parameter like '$pat'"}
                       2 {$objQry = "Schema = '$schema' and Object = '$dbObj' and Parameter like '$pat'"}
                       3 {if ($schema) { $objQry = "Database = '$db' and Schema = '$schema' and Object = '$dbObj' and Parameter like '$pat'"}
                           else {$objQry = "Database = '$db' and Object = '$dbObj' and Parameter like '$pat'"}}
                     }


                     $global:dsDbObjects.Tables["Parameter"].select($objQry) | % {$objects += ,$_.Parameter}
                      
                     foreach ($object in $objects)
                     {
                        if ($object -notmatch 'True|False')
                        {$object }
                     }

                } #Write-Parmeters

                ### END CUSTOM functions for SQLIse


                switch -regex ($line)
                {
                    ### START CUSTOM Code for SQLIse
                    '(\bFROM\b|\bJOIN\b|\bUPDATE\b|\bINSERT\b|\bDELETE\b)\s+(.*$)' {
                        $expression = $matches[2] #Original expression
                        $base = $matches[2] -replace '\[|\]|"' #Normalized Object
                        Write-DbObjects -base $base -objType 'Table' -expression $expression
                        break;
                    }
                    '(?<![\w\@\#\$])EXEC(UTE)?\s+(\@.+?=\s*)?([^@]+)' {
                        $expression = $matches[3] #Original expression
                        $base = $matches[3] -replace '\[|\]|"' #Normalized Object
                        Write-DbObjects -base $base -objType 'Proc' -expression $expression
                        break;
                    }


                    ### END CUSTOM Code for SQLIse
                 }
                 
                 switch -regex ($lastWord)
                 {
                    '^@([*\w0-9]*)' {
                        $pat = $matches[1] + '*'
                        $line -match '(?<![\w\@\#\$])EXEC(UTE)?\s+(\@.+?=\s*)?([^(\s]+)' | out-null
                        $base = $matches[3] -replace '\[|\]|"' #Normalized Object
                        Write-Parmeters -base $base -pat $pat
                        break;
                    }
                 }

    }
