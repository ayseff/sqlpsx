add-type -AssemblyName "System.web"

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

$Script:conn=new-object System.Data.SqlClient.SQLConnection


#Load saved options into hashtable
$options = Import-Clixml -Path "$psScriptRoot\Options.xml"

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
    param()
    $script:connInfo = Get-ConnectionInfo $bitmap 
    if ($connInfo)
    { 
        $Script:conn = new-connection -server $connInfo.Server -database $connInfo.Database -user $connInfo.UserName -password $connInfo.Password
        $connInfo | Export-Clixml "$psScriptRoot\ConnInfo.xml"
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
function Prompt
{
    param()
    $basePrompt = $(if (test-path variable:/PSDebugContext) { '[DBG]: ' } else { '' }) + 'PS ' + $(Get-Location)
    $sqlPrompt = '#' + $(if ($Script:conn.State -eq 'Open') {'[CONNECTED][' + $($Script:conn.DataSource) + '.' + $($Script:conn.Database) + ']: '} else { '[DISCONNECTED]: '}) + $(if ($nestedpromptlevel -ge 1) { '>>' }) + '> '
    $basePrompt + $sqlPrompt

} #Prompt

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
    param()
    if (-not $psise.CurrentFile)
    {
        Write-Error 'You must have an open script file'
        return
    }
    
    if ($conn.State -eq 'Closed')
    { Connect-Sql }
    
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
    
    if ($options.PoshMode)
    {
        Invoke-PoshCode $inputScript
        $inputScript = Remove-PoshCode $inputScript
        $inputScript = [system.web.httputility]::htmlencode($($inputScript -replace "'","`""))
        $inputScript = $ExecutionContext.InvokeCommand.ExpandString($inputScript)
        $inputScript = [system.web.httputility]::htmldecode($inputScript) -replace "`"","'"
        
    }

    if ($inputScript -and $inputScript -ne "")
    {
        switch($($options.Results))
        {
            'To Grid' {invoke-query -sql $inputScript -connection $Script:conn | Out-GridView -Title $psise.CurrentFile.DisplayName
                       Write-Host "Query executed successfully"}
            'To Text' {invoke-query -sql $inputScript -connection $Script:conn; Write-Host "Query executed successfully"}
            'To File' {
                        $filePath = Get-FileName 'txt' 'Text'
                        if ($filePath)
                        {invoke-query -sql $inputScript -connection $Script:conn | Out-File -FilePath $filePath -Force
                         Write-Host "Query executed successfully"}
                      }
            'To CSV' {
                      $filePath = Get-FileName 'csv' 'CSV'
                      if ($filePath)
                      {invoke-query -sql $inputScript -connection $Script:conn | Export-Csv -Path $filepath -NoTypeInformation -Force
                       Write-Host "Query executed successfully"}
                     }
            'To Variable' {
                        $OutputVariable = Read-Host 'Variable (no "$" needed)'
                        Set-Variable -Name $OutputVariable -Value (invoke-query -sql $inputScript -connection $Script:conn) -Scope Global
                    }
        }
    }
        
} #Invoke-ExecuteSql

#######################
function Write-Options
{
    param()
    $options | Export-Clixml -Path "$psScriptRoot\Options.xml" -Force

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
        $connInfo = Import-Clixml "$psScriptRoot\ConnInfo.xml" 
        $connInfo.Database = $database
        $connInfo | Export-Clixml "$psScriptRoot\ConnInfo.xml" 
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
Add-IseMenu -name SQLIse @{
    "Parse" = {Invoke-ParseSql} | Add-Member NoteProperty ShortcutKey "CTRL+SHIFT+F5" -PassThru
    "Format" = {Format-Sql} | Add-Member NoteProperty ShortcutKey "CTRL+ 4" -PassThru
    "Connection" =@{
                    "Connect..." = {Connect-Sql}
                    "Disconnect" = {Disconnect-Sql}
    }
    "Execute" = {Invoke-ExecuteSql} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+F5" -PassThru
    "Change Database..." = {Switch-Database}
    "Options..." = {Set-Options; Write-Options}
    "Edit" =@{
                    "Make Uppercase         CTRL+SHIFT+U" = {Edit-Uppercase}
                    "Make Lowercase         CTRL+U" = {Edit-Lowercase}
                    "Toggle Comments" = {Switch-SelectedCommentOrText} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+K" -PassThru
            }
    "Table Browser" = {Show-TableBrowser | Out-Null}
    "Object Browser" = {Show-DbObjectList -ds (Get-DbObjectList)}
    "Manage Connections" = { Show-ConnectionManager }
	"Tab Expansion" = @{
                        "Refresh Alias Cache" = {Get-TableAlias} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+T" -PassThru
                        "Refresh Object Cache" = {Get-TabObjectList} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+R" -PassThru

    }
} -module SQLIse

New-Alias -name setvar -value Set-PoshVariable -Description "SqlIse Alias"
Export-ModuleMember -function * -Variable options, bitmap, conn, DatabaseList, SavedConnections, dsDbObjects -alias setvar
