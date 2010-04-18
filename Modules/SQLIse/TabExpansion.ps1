function TabExpansion
{
    param($line, $lastWord)

    function Write-Members ($sep='.')
    {
        Invoke-Expression ('$_val=' + $_expression)

        $_method = [Management.Automation.PSMemberTypes] `
            'Method,CodeMethod,ScriptMethod,ParameterizedProperty'
        if ($sep -eq '.')
        {
            $params = @{view = 'extended','adapted','base'}
        }
        else
        {
            $params = @{static=$true}
        }

        foreach ($_m in ,$_val | Get-Member @params $_pat |
            Sort-Object membertype,name)
        {
            if ($_m.MemberType -band $_method)
            {
                # Return a method...
                $_base + $_expression + $sep + $_m.name + '('
            }
            else {
                # Return a property...
                $_base + $_expression + $sep + $_m.name
            }
        }
    }
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
           2 {if ($schema -eq $global:conn.database) {
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

    #######################
    function Write-Columns
    {
        param($base,$pat)

        $objects = @()
        $pat = $pat.Trim('*')
        $pat = $pat + '%'
        $objQry = ''
        
        foreach ($table in  ($global:tableAlias | where {$_.Alias -eq $base -or $_.Object -eq $base} ))
        {
            if ($table.Database) {$objQry += "Database = '$($table.Database)' AND "}
            if ($table.Schema) {$objQry += "Schema = '$($table.Schema)' AND "}
            $objQry += "Object = '$($table.Object)' AND Column like '$pat'"
        }

        $global:dsDbObjects.Tables["Column"].select($objQry) | % {$objects += ,$_.Column}

        foreach ($object in $objects)
        {
            if ($object -notmatch 'True|False')
            {$base + '.' + $object }
        }


    } #Write-Columns

    ### END CUSTOM functions for SQLIse

    # If a command name contains any of these chars, it needs to be quoted
    $_charsRequiringQuotes = ('`&@''#{}()$,;|<> ' + "`t").ToCharArray()

    # If a variable name contains any of these characters it needs to be in braces
    $_varsRequiringQuotes = ('-`&@''#{}()$,;|<> .\/' + "`t").ToCharArray()

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
     
        '(?<![\$])(\w)+\.(\w+)?' {
            if ($line -notmatch '\bFROM\b|\bJOIN\b|\bUPDATE\b|\bINSERT\b|\bDELETE\b')
            {
                    $base = ($matches[0] -split '\.')[0]
                    $pat = $matches[2] + '*'
                    Write-Columns -base $base -pat $pat
                    break;
            }
         }
       }

        ### END CUSTOM Code for SQLIse

        switch -regex ($lastWord)
        {
            # Handle property and method expansion rooted at variables...
            # e.g. $a.b.<tab>
            '(^.*)(\$(\w|:|\.)+)\.([*\w]*)$' {
                $_base = $matches[1]
                $_expression = $matches[2]
                $_pat = $matches[4] + '*'
                Write-Members
                break;
            }

            # Handle simple property and method expansion on static members...
            # e.g. [datetime]::n<tab>
            '(^.*)(\[(\w|\.|\+)+\])(\:\:|\.){0,1}([*\w]*)$' {
                $_base = $matches[1]
                $_expression = $matches[2]
                $_pat = $matches[5] + '*'
                Write-Members $(if (! $matches[4]) {'::'} else {$matches[4]})
                break;
            }

            # Handle complex property and method expansion on static members
            # where there are intermediate properties...
            # e.g. [datetime]::now.d<tab>
            '(^.*)(\[(\w|\.|\+)+\](\:\:|\.)(\w+\.)+)([*\w]*)$' {
                $_base = $matches[1]  # everything before the expression
                $_expression = $matches[2].TrimEnd('.') # expression less trailing '.'
                $_pat = $matches[6] + '*'  # the member to look for...
                Write-Members
                break;
            }

            # Handle variable name expansion...
            '(^.*\$)([*\w:]+)$' {
                $_prefix = $matches[1]
                $_varName = $matches[2]
                $_colonPos = $_varname.IndexOf(':')
                if ($_colonPos -eq -1)
                {
                    $_varName = 'variable:' + $_varName
                    $_provider = ''
                }
                else
                {
                    $_provider = $_varname.Substring(0, $_colonPos+1)
                }

                foreach ($_v in Get-ChildItem ($_varName + '*') | sort Name)
                { 
                    $_nameFound = $_v.name
                    $(if ($_nameFound.IndexOfAny($_varsRequiringQuotes) -eq -1) {'{0}{1}{2}'}
                    else {'{0}{{{1}{2}}}'}) -f $_prefix, $_provider, $_nameFound
                }
                break;
            }

            # Do completion on parameters...
            '^-([*\w0-9]*)' {
                $_pat = $matches[1] + '*'

                # extract the command name from the string
                # first split the string into statements and pipeline elements
                # This doesn't handle strings however.
                $_command = [regex]::Split($line, '[|;=]')[-1]

                #  Extract the trailing unclosed block e.g. ls | foreach  cp
                if ($_command -match '\{([^\{\}]*)$')
                {
                    $_command = $matches[1]
                }

                # Extract the longest unclosed parenthetical expression...
                if ($_command -match '\(([^()]*)$')
                {
                    $_command = $matches[1]
                }

                # take the first space separated token of the remaining string
                # as the command to look up. Trim any leading or trailing spaces
                # so you don't get leading empty elements.
                $_command = $_command.TrimEnd('-')
                $_command,$_arguments = $_command.Trim().Split()

                # now get the info object for it, -ArgumentList will force aliases to be resolved
                # it also retrieves dynamic parameters
                try
                {
                    $_command = @(Get-Command -type 'Alias,Cmdlet,Function,Filter,ExternalScript' `
                        -Name $_command -ArgumentList $_arguments)[0]
                }
                catch
                {
                    # see if the command is an alias. If so, resolve it to the real command
                    if(Test-Path alias:\$_command)
                    {
                        $_command = @(Get-Command -Type Alias $_command)[0].Definition
                    }

                    # If we were unsuccessful retrieving the command, try again without the parameters
                    $_command = @(Get-Command -type 'Cmdlet,Function,Filter,ExternalScript' `
                        -Name $_command)[0]
                }

                # remove errors generated by the command not being found, and break
                if(-not $_command) { $error.RemoveAt(0); break; }

                # expand the parameter sets and emit the matching elements
                # need to use psbase.Keys in case 'keys' is one of the parameters
                # to the cmdlet
                foreach ($_n in $_command.Parameters.psbase.Keys)
                {
                    if ($_n -like $_pat) { '-' + $_n }
                }
                break;
            }

            # Tab complete against history either #<pattern> or #<id>
            '^#(\w*)' {
                $_pattern = $matches[1]
                if ($_pattern -match '^[0-9]+$')
                {
                    Get-History -ea SilentlyContinue -Id $_pattern | Foreach { $_.CommandLine } 
                }
                else
                {
                    $_pattern = '*' + $_pattern + '*'
                    Get-History -Count 32767 | Sort-Object -Descending Id| Foreach { $_.CommandLine } | where { $_ -like $_pattern }
                }
                break;
            }

            # try to find a matching command...
            default {
                        # parse the script...
                        $_tokens = [System.Management.Automation.PSParser]::Tokenize($line, [ref] $null)

                        if ($_tokens)
                        {
                            $_lastToken = $_tokens[$_tokens.count - 1]
                            if ($_lastToken.Type -eq 'Command')
                            {
                                $_cmd = $_lastToken.Content

                                # don't look for paths...
                                if ($_cmd.IndexOfAny('/\:') -eq -1)
                                {
                                    # handle parsing errors - the last token string should be the last
                                    # string in the line...
                                    if ($lastword.Length -ge $_cmd.Length -and 
                                        $lastword.substring($lastword.length-$_cmd.length) -eq $_cmd)
                                    {
                                        $_pat = $_cmd + '*'
                                        $_base = $lastword.substring(0, $lastword.length-$_cmd.length)

                                        # get files in current directory first, then look for commands...
                                        $( try {Resolve-Path -ea SilentlyContinue -Relative $_pat } catch {} ;
                                           try { $ExecutionContext.InvokeCommand.GetCommandName($_pat, $true, $false) |
                                               Sort-Object -Unique } catch {} ) |
                                                   # If the command contains non-word characters (space, ) ] ; ) etc.)
                                                   # then it needs to be quoted and prefixed with &
                                                   ForEach-Object {
                                                        if ($_.IndexOfAny($_charsRequiringQuotes) -eq -1) { $_ }
                                                        elseif ($_.IndexOf('''') -ge 0) {'& ''{0}''' -f $_.Replace('''','''''') }
                                                        else { '& ''{0}''' -f $_ }} |
                                                   ForEach-Object {'{0}{1}' -f $_base,$_ }
                                    }
                                }
                            }
                        }
                    }
                }
}
