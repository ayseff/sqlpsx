$mInfo = $MyInvocation.MyCommand.ScriptBlock.Module
$mInfo.OnRemove = {
     if ($Script:conn.state -eq 'open')
     {
        Write-Host -BackgroundColor Black -ForegroundColor Yellow "Connection $($Script:conn.database) closed"
        $Script:conn.Close()
     }
    
    Write-Host -BackgroundColor Black -ForegroundColor Yellow "$($MyInvocation.MyCommand.ScriptBlock.Module.name) removed on $(Get-Date)"
    Remove-IseMenu SQLIse
}


import-module ISECreamBasic
import-module SQLParser
import-module adolib
import-module WPK

. $psScriptRoot\Get-ConnectionInfo.ps1
. $psScriptRoot\Set-Options.ps1
. $psScriptRoot\Switch-CommentOrText.ps1
. $psScriptRoot\Switch-SelectedCommentOrText.ps1
. $psScriptRoot\Show-TableBrowser.ps1
. $psScriptRoot\Get-DbObjectList.ps1
. $psScriptRoot\Show-DbObjectList.ps1
. $psScriptRoot\Show-ConnectionManager.ps1
. $psScriptRoot\Get-TabObjectList.ps1
. $psScriptRoot\Invoke-Coalesce.ps1
. $psScriptRoot\Get-TableAlias.ps1
. $psScriptRoot\TabExpansion.ps1
. $psScriptRoot\ConvertTo-StringData.ps1
. $psScriptRoot\Library-UserStore.ps1
. $psScriptRoot\ConvertFrom-Xml.ps1

Set-Alias Expand-String $psScriptRoot\Expand-String.ps1

$Script:conn=new-object System.Data.SqlClient.SQLConnection

#Load saved options into hashtable
Initialize-UserStore  -fileName "options.txt" -dirName "SQLIse" -defaultFile "$psScriptRoot\defaultopts.ps1"
$options = Read-UserStore -fileName "options.txt" -dirName "SQLIse" -typeName "Hashtable"

$Script:DatabaseList = New-Object System.Collections.ArrayList

$bitmap = new-object System.Windows.Media.Imaging.BitmapImage
$bitmap.BeginInit()
$bitmap.UriSource = "$psScriptRoot\SQLPSX.PNG"
$bitmap.EndInit()

#######################
function Invoke-ParseSql
{
    param()
    if (-not $psise.CurrentFile)
    {
        Write-Error 'You must have an open script file'
        return
    }
    
    $selectedRunspace = $psise.CurrentFile
    $selectedEditor=$selectedRunspace.Editor

    if (-not $selectedEditor.SelectedText)
    {
        $inputScript = $selectedEditor.Text
    }
    else
    {
        $inputScript = $selectedEditor.SelectedText
    }
    Test-SqlScript -InputScript $inputScript -QuotedIdentifierOff:$($options.QuotedIdentifierOff) -SqlVersion:$($options.SqlVersion)
 
} #Invoke-ParseSql

#######################
function Format-Sql
{
    param()
    if (-not $psise.CurrentFile)
    {
        Write-Error 'You must have an open script file'
        return
    }
    
    $selectedRunspace = $psise.CurrentFile
    $selectedEditor=$selectedRunspace.Editor

    if (-not $selectedEditor.SelectedText)
    {
        $inputScript = $selectedEditor.Text
        $outputScript = Out-SqlScript -InputScript $inputScript -QuotedIdentifierOff:$($options.QuotedIdentifierOff) -SqlVersion:$($options.SqlVersion) -AlignClauseBodies:$($options.AlignClauseBodies) `
        -AlignColumnDefinitionFields:$($options.AlignColumnDefinitionFields) -AlignSetClauseItem:$($options.AlignSetClauseItem) -AsKeywordOnOwnLine:$($options.AsKeywordOnOwnLine) `
        -IncludeSemicolons:$($options.IncludeSemicolons) -IndentationSize:$($options.IndentationSize) -IndentSetClause:$($options.IndentSetClause) -IndentViewBody:$($options.IndentViewBody) `
        -KeywordCasing:$($options.KeywordCasing) -MultilineInsertSourcesList:$($options.MultilineInsertSourcesList) -MultilineInsertTargetsList:$($options.MultilineInsertTargetsList) `
        -MultilineSelectElementsList:$($options.MultilineSelectElementsList) -MultilineSetClauseItems:$($options.MultilineSetClauseItems) -MultilineViewColumnsList:$($options.MultilineViewColumnsList) `
        -MultilineWherePredicatesList:$($options.MultilineWherePredicatesList) -NewLineBeforeCloseParenthesisInMultilineList:$($options.NewLineBeforeCloseParenthesisInMultilineList) `
        -NewLineBeforeFromClause:$($options.NewLineBeforeFromClause) -NewLineBeforeGroupByClause:$($options.NewLineBeforeGroupByClause) -NewLineBeforeHavingClause:$($options.NewLineBeforeHavingClause) `
        -NewLineBeforeJoinClause:$($options.NewLineBeforeJoinClause) -NewLineBeforeOpenParenthesisInMultilineList:$($options.NewLineBeforeOpenParenthesisInMultilineList) `
        -NewLineBeforeOrderByClause:$($options.NewLineBeforeOrderByClause) -NewLineBeforeOutputClause:$($options.NewLineBeforeOutputClause) -NewLineBeforeWhereClause:$($options.NewLineBeforeWhereClause)

        if ($outputScript)
        { $selectedEditor.Text = $outputScript }
    }
    else
    {
        $inputScript = $selectedEditor.SelectedText
        $outputScript = Out-SqlScript -InputScript $inputScript -QuotedIdentifierOff:$($options.QuotedIdentifierOff) -SqlVersion:$($options.SqlVersion) -AlignClauseBodies:$($options.AlignClauseBodies) `
        -AlignColumnDefinitionFields:$($options.AlignColumnDefinitionFields) -AlignSetClauseItem:$($options.AlignSetClauseItem) -AsKeywordOnOwnLine:$($options.AsKeywordOnOwnLine) `
        -IncludeSemicolons:$($options.IncludeSemicolons) -IndentationSize:$($options.IndentationSize) -IndentSetClause:$($options.IndentSetClause) -IndentViewBody:$($options.IndentViewBody) `
        -KeywordCasing:$($options.KeywordCasing) -MultilineInsertSourcesList:$($options.MultilineInsertSourcesList) -MultilineInsertTargetsList:$($options.MultilineInsertTargetsList) `
        -MultilineSelectElementsList:$($options.MultilineSelectElementsList) -MultilineSetClauseItems:$($options.MultilineSetClauseItems) -MultilineViewColumnsList:$($options.MultilineViewColumnsList) `
        -MultilineWherePredicatesList:$($options.MultilineWherePredicatesList) -NewLineBeforeCloseParenthesisInMultilineList:$($options.NewLineBeforeCloseParenthesisInMultilineList) `
        -NewLineBeforeFromClause:$($options.NewLineBeforeFromClause) -NewLineBeforeGroupByClause:$($options.NewLineBeforeGroupByClause) -NewLineBeforeHavingClause:$($options.NewLineBeforeHavingClause) `
        -NewLineBeforeJoinClause:$($options.NewLineBeforeJoinClause) -NewLineBeforeOpenParenthesisInMultilineList:$($options.NewLineBeforeOpenParenthesisInMultilineList) `
        -NewLineBeforeOrderByClause:$($options.NewLineBeforeOrderByClause) -NewLineBeforeOutputClause:$($options.NewLineBeforeOutputClause) -NewLineBeforeWhereClause:$($options.NewLineBeforeWhereClause)

        if ($outputScript)
        { $selectedEditor.InsertText($outputScript) }
    }
 
} #Format-Sql

#######################
function Connect-Sql
{
    param(
        $database,
        $server,
        $user,
        $password
    )
    if ($database)
    {
        if (!$server)
        {
            $server = 'localhost'
        }
    }
    else
    {
        $script:connInfo = Get-ConnectionInfo $bitmap
        if ($connInfo)
        { 
            $database = $connInfo.Database
            $server = $connInfo.Server
            $user = $connInfo.UserName
            $password = $connInfo.Password
        }
    }
     
    if ($database)
    { 
        $Script:conn = new-connection -server $server -database $database -user $user -password $password
        $handler    = [System.Data.SqlClient.SqlInfoMessageEventHandler] {
            if ($filePath  -ne $null)
            {
                $_.Message | Out-File -FilePath $filePath -append
            }
                else
            {
                Write-Host $_
                #Write-Host $error[0].InnerException
            }
        }
        $Script:conn.add_InfoMessage($handler)
        if ($Script:conn.State -eq 'Open')
        { 
            invoke-query -sql:'sp_databases' -connection:$Script:conn | foreach { [void]$Script:DatabaseList.Add($_.DATABASE_NAME) } 
            Get-TabObjectList
        }
    }
    
} #Connect-Sql

#######################
function Disconnect-Sql
{
    param()

    $Script:conn.Close()
    $Script:DatabaseList.Clear()

} #Disconnect-Sql

#######################
function USE-ReopenSql
{
    param()
    if (!! $Script:conn.ConnectionString )
    {
        $Script:conn.Open()
        if ($Script:conn.State -eq 'Open')
        { 
            invoke-query -sql:'sp_databases' -connection:$Script:conn | foreach { [void]$Script:DatabaseList.Add($_.DATABASE_NAME) } 
            Get-TabObjectList
        }
    }
} #USE-ReopenSql

#######################
if ((gmo Oracleise))
{
    function Prompt
    {
        param()
        $basePrompt = $(if (test-path variable:/PSDebugContext) { '[DBG]: ' } else { '' }) + 'PS ' + $(Get-Location)
        $sqlPrompt = ' #[SQL]' + $(if ($Script:conn.State -eq 'Open') { $($Script:conn.DataSource) + '.' + $($Script:conn.Database) } else { '---'})
        $oraclePrompt = ' #[Oracle]' + $(if ($oracle_conn.State -eq 'Open') { $($oracle_conn.DataSource) } else { '---'})
        $basePrompt + $sqlPrompt + $oraclePrompt +$(if ($nestedpromptlevel -ge 1) { ' >>' }) + ' > '

    } #Prompt
}
else
{
    function Prompt
    {
        param()
        $basePrompt = $(if (test-path variable:/PSDebugContext) { '[DBG]: ' } else { '' }) + 'PS ' + $(Get-Location)
        $sqlPrompt = '#' + $(if ($Script:conn.State -eq 'Open') {'[CONNECTED][' + $($Script:conn.DataSource) + '.' + $($Script:conn.Database) + ']: '} else { '[DISCONNECTED]: '}) + $(if ($nestedpromptlevel -ge 1) { '>>' }) + '> '
        $basePrompt + $sqlPrompt

    } #Prompt
}
#######################
function Get-FileName
{
    param($ext,$extDescription)
    $sfd = New-SaveFileDialog -AddExtension -DefaultExt "$ext" -Filter "$extDescription (.$ext)|*.$ext|All files(*.*)|*.*" -Title "Save Results" -InitialDirectory $pwd.path
    [void]$sfd.ShowDialog()
    return $sfd.FileName

} #Get-FileName

#######################
function Invoke-ExecuteSql
{
    param(
        $inputScript,
        $displaymode = $null,
        $OutputVariable = $null
        )
    
    if ($inputScript -eq $null)
    {
        if (-not $psise.CurrentFile)
        {
            Write-Error 'You must have an open script file'
            return
        }
        
        $selectedRunspace = $psise.CurrentFile
        $selectedEditor=$selectedRunspace.Editor

        if (-not $selectedEditor.SelectedText)
        {
            $inputScript = $selectedEditor.Text 
        }
        else
        {
            $inputScript = $selectedEditor.SelectedText
        }
    }
        
    if ($conn.State -eq 'Closed')
    { Connect-Sql }
        
    # fix CR not followed by NL and NL not preceded by CR
    $inputScript = $inputScript  -replace  "`r(?!`n)","`r`n" -replace "`(?<!`r)`n", "`r`n"
    
    # split into blocks 
    $blocks = $inputScript -split  "\r?\n[ \t]*go[ \t]*(?=\r?\n)"
    $blocknr = 0
    $linenr = 1
    $sql_errors = @()
    $filePath = $null

    if ($displaymode -eq $null)
    {
        $displaymode = $env:SQLPsx_QueryOutputformat
        # Write-Host "Set `$env:SQLPsx_QueryOutputformat to $displaymode"
        [Environment]::SetEnvironmentVariable("SQLPsx_QueryOutputformat", $displaymode, "User")

        if ($displaymode -eq $null)
        {
            $displaymode = 'auto' 
        } 
    }
        
    foreach ($inputScript in $blocks)
    { 
        $linecount = ($inputScript -split [System.Environment]::NewLine).count
        $begline = $linenr
        $endline = $linenr + $linecount -1 
        if ($blocknr++ -ge 1)
        {        
            $begline = $linenr + 1
            if ($filePath -eq $null)
            {
                Write-Host "---------- Blocknr: $blocknr ---  Line: $begline - $endline ---------- $linecount"
            }
        }
        $linenr += $linecount #+ 1

        if ($options.PoshMode)
        {
            Invoke-PoshCode $inputScript
            $inputScript = Remove-PoshCode $inputScript
            $inputScript = Expand-String $inputScript
        }

        if ($inputScript -and $inputScript -ne "")
        {
             try {
                $res = invoke-query -sql $inputScript -connection $Script:conn
             }
             catch {
                $e = $_
                $error_msg = "Blocknr $blocknr $begline $endline $e"
                $sql_errors += $error_msg
                Write-Host $e -ForegroundColor Red -BackgroundColor White
                $res = $null
            }
            # Write-host "Using mode: $displaymode"   
            switch($displaymode)
            {
                'grid' {
                         if ($res.Tables)
                         {
                            Write-host 'multiple results'
                            $res.tables | %{ $_ |  Out-GridView -Title $psise.CurrentFile.DisplayName}
                         }
                         elseif ($res -ne $null)
                         {
                          $res |  Out-GridView -Title $psise.CurrentFile.DisplayName
                         }
                       }
                'auto'  {    
                             if ($res.Tables)
                             {
                                Write-host 'multiple results'
                                $res.tables | %{ $_  | out-host}
                             }
                             else
                             {
                                $res
                             }
                       }
                'table' {
                        Write-Host "Table"
                         if ($res.Tables)
                         {
                            Write-host 'multiple results'
                            $res.tables | %{ $_ | ft -auto }
                         }
                         else
                         {
                          $res | ft -auto
                         }
                       }
                'list' {
                         if ($res.Tables)
                         {
                            Write-host 'multi results'
                            $res.tables | %{ $_ | fl }
                         }
                         else
                         {
                          $res | fl
                         }
                       }
                
                'file' {
                            if ($filePath -eq $null)
                            {
                                $filePath = Get-FileName 'txt' 'Text'
                                if ($filePath)
                                {
                                    '' |  Out-File -FilePath $filePath -Force
                                }
                            }
                            if ($filePath)
                            {
                                if ($res.Tables)
                                {
                                    $res.tables | %{ $_ | Out-File -FilePath $filePath -append }
                                }
                                else
                                {
                                    $res | Out-File -FilePath $filePath -append
                                }
                            }
                          }
                'csv' {
                          $filePath = Get-FileName 'csv' 'CSV'
                          if ($filePath)
                          # what todo with multi resultset 
                          {$res | Export-Csv -Path $filepath -NoTypeInformation -Force
                           Write-Host ""}
                         }
                'variable' {
                        Write-Host "Variable"
                            if (! $OutputVariable)
                            {
                                $OutputVariable = Read-Host 'Variable (no "$" needed)'
                            }
                            Set-Variable -Name $OutputVariable -Value $res -Scope Global
                        }
                'isetab'   {
                             $text = ($res | ft -auto | Out-string -width 10000 -stream ) -replace " *$", ""-replace "\.\.\.$", "" -join "`r`n" 
                             $count = $psise.CurrentPowerShellTab.Files.count
                             $psIse.CurrentPowerShellTab.Files.Add()
                             $Newfile = $psIse.CurrentPowerShellTab.Files[$count]
                             $Newfile.Editor.Text = $text

                        }        
            }
        }
    }
    $sql_errors
        
} #Invoke-ExecuteSql

#######################
function Write-Options
{
    param()
    Write-UserStore -fileName "options.txt" -dirName "SQLIse" -object $options

} #Write-Options

#######################
function Switch-Database
{
    param()

    $Action = {
        $this.Parent.Tag = $this.SelectedItem
        $window.Close() }
                
    $database = New-ComboBox -Name Database -Width 200 -Height 20 {$DatabaseList} -SelectedItem $conn.Database -On_SelectionChanged $Action -Show

    if ($database)
    { 
        $Script:conn.ChangeDatabase($database) 
        $connInfo.Database = $database
        Get-TabObjectList
    } 

} #Switch-Database

#######################
function Edit-Uppercase
{
    param()
    if (-not $psise.CurrentFile)
    {
        Write-Error 'You must have an open script file'
        return
    }
    
    $selectedRunspace = $psise.CurrentFile
    $selectedEditor=$selectedRunspace.Editor

    if (-not $selectedEditor.SelectedText)
    {
        $output = $($selectedEditor.Text).ToUpper()
        if ($output)
        { $selectedEditor.Text = $output }

    }
    else
    {
        $output = $($selectedEditor.SelectedText).ToUpper()
        if ($output)
        { $selectedEditor.InsertText($output) }

    }

} #Edit-Uppercase

#######################
function Edit-Lowercase
{
    param()
    if (-not $psise.CurrentFile)
    {
        Write-Error 'You must have an open script file'
        return
    }
    
    $selectedRunspace = $psise.CurrentFile
    $selectedEditor=$selectedRunspace.Editor

    if (-not $selectedEditor.SelectedText)
    {
        $output = $($selectedEditor.Text).ToLower()
        if ($output)
        { $selectedEditor.Text = $output }

    }
    else
    {
        $output = $($selectedEditor.SelectedText).ToLower()
        if ($output)
        { $selectedEditor.InsertText($output) }

    }

} #Edit-Lowercase

#######################
function Set-PoshVariable
{
    param($name,$value)

    Set-Variable -Name $name -Value $value -Scope Global

} #Set-PoshVariable

#######################
function Invoke-PoshCode
{
    param($text)

    foreach ( $line in $text -split [System.Environment]::NewLine )
    {
        if ( $line.length -gt 0) {
            if ( $line -match "^\s*!!" ) {
                $line = $line -replace "^\s*!!", ""
                invoke-expression $line
            }
        }
    }

} #Invoke-PoshCode

#######################
function Remove-PoshCode
{
    param($text)

    $returnedText = ""
    foreach ( $line in $text -split [System.Environment]::NewLine )
    {
        if ( $line.length -gt 0) {
            if ( $line -notmatch "^\s*!!" ) {
                $returnText += "{0}{1}" -f $line,[System.Environment]::NewLine
            }
        }
    }
    $returnText

} #Remove-PoshCode

#######################
function Set-Outputformat
{            
    New-StackPanel {            
        New-RadioButton -Content "auto"     -GroupName Results -IsChecked $True -On_Click { $env:SQLPsx_QueryOutputformat = "auto" }            
        New-RadioButton -Content "list"     -GroupName Results -On_Click { $env:SQLPsx_QueryOutputformat = "list" }            
        New-RadioButton -Content "table"    -GroupName Results -On_Click { $env:SQLPsx_QueryOutputformat = "table" }
        New-RadioButton -Content "grid"     -GroupName Results -On_Click { $env:SQLPsx_QueryOutputformat = "grid" }
        New-RadioButton -Content "variable" -GroupName Results -On_Click { $env:SQLPsx_QueryOutputformat = "variable" }
        New-RadioButton -Content "csv"      -GroupName Results -On_Click { $env:SQLPsx_QueryOutputformat = "csv" }
        New-RadioButton -Content "file"     -GroupName Results -On_Click { $env:SQLPsx_QueryOutputformat = "file" }
        New-RadioButton -Content "isetab"   -GroupName Results -On_Click { $env:SQLPsx_QueryOutputformat = "isetab" }
        
                    
    } -asjob            
}           
#######################
$menudefinition = @{
    "Parse" = {Invoke-ParseSql} | Add-Member NoteProperty ShortcutKey "CTRL+SHIFT+F5" -PassThru
    "Format" = {Format-Sql} | Add-Member NoteProperty ShortcutKey "CTRL+ 4" -PassThru
    "Connection" =@{
                    "Connect..." = {Connect-Sql}
                    "Disconnect" = {Disconnect-Sql}
                    "Reconnect"  = {USE-ReopenSql}
    }
    "Execute" = {Invoke-ExecuteSql} | Add-Member NoteProperty ShortcutKey "F7" -PassThru
    "Change Database..." = {Switch-Database}
    "Options..." = {Set-Options; Write-Options}
    "Edit" =@{
                    "Make Uppercase         CTRL+SHIFT+U" = {Edit-Uppercase}
                    "Make Lowercase         CTRL+U" = {Edit-Lowercase}
                    "Toggle Comments" = {Switch-SelectedCommentOrText} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+K" -PassThru
            }
    "Table Browser" = {Show-TableBrowser -resource @{conn = $conn} | Out-Null}
    "Object Browser" = {Show-DbObjectList -ds (Get-DbObjectList)}
    "Manage Connections" = { Show-ConnectionManager }
	"Tab Expansion" = @{
                        "Refresh Alias Cache" = {Get-TableAlias} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+T" -PassThru
                        "Refresh Object Cache" = {Get-TabObjectList} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+R" -PassThru
    }
    "Output Format..." = {Set-Outputformat}
}
 
Add-IseMenu -name SQLIse $menudefinition

New-Alias -name setvar -value Set-PoshVariable -Description "SqlIse Alias"
Export-ModuleMember -function * -Variable options, bitmap, conn, DatabaseList, SavedConnections, dsDbObjects -alias setvar
