$mInfo = $MyInvocation.MyCommand.ScriptBlock.Module
$mInfo.OnRemove = {
    Write-Host "$($MyInvocation.MyCommand.ScriptBlock.Module.name) removed on $(Get-Date)"
    Remove-IseMenu OracleIse
}

# Write-Host "$($MyInvocation.MyCommand.ScriptBlock.Module.name) imported on $(Get-Date)"

if (! (get-module ISECreamBasic) ) {import-module ISECreamBasic}
if (! (get-module OracleClient) ) {import-module OracleClient}
if (! (get-module WPK) ) {import-module WPK}

. $psScriptRoot\Get-ConnectionInfo.ps1
. $psScriptRoot\Set-Options.ps1
. $psScriptRoot\Switch-CommentOrText.ps1
. $psScriptRoot\Switch-SelectedCommentOrText.ps1

# $Script:oracle_conn=new-object System.Data.OracleClient.OracleConnection
$Script:oracle_conn=new-object Oracle.DataAccess.Client.OracleConnection

#Load saved options into hashtable
$oracle_options = Import-Clixml -Path "$psScriptRoot\Options.xml"

#$Script:DatabaseList = New-Object System.Collections.ArrayList

$bitmap = new-object System.Windows.Media.Imaging.BitmapImage
$bitmap.BeginInit()
$bitmap.UriSource = "$psScriptRoot\SQLPSX.PNG"
$bitmap.EndInit()


#######################
function Connect-Sql
{
    param()
    $connInfo = Get-ConnectionInfo $bitmap
    if ($connInfo)
    { 
        $Script:oracle_conn = new-oracle_connection -tns $connInfo.tns -user $connInfo.UserName -password $connInfo.Password
#         if ($Script:oracle_conn.State -eq 'Open')
#         { invoke-oracle_query -sql:'sp_databases' -connection:$Script:oracle_conn | foreach { [void]$Script:DatabaseList.Add($_.DATABASE_NAME) } }
    }

} #Connect-Sql


#######################
function Disconnect-Sql
{
    param()

    $Script:oracle_conn.Close()
    #$Script:DatabaseList.Clear()

} #Disconnect-Sql

#######################
# my personal opinion is, that modules are not to be allowed to modify promp
# problems arise, when multipe modules are loaded
# and remove-module has to restore the original prompt (bernd_k)

# function Prompt
# {
#     param()
#     $basePrompt = $(if (test-path variable:/PSDebugContext) { '[DBG]: ' } else { '' }) + 'PS ' + $(Get-Location)
#     $sqlPrompt = '#' + $(if ($Script:oracle_conn.State -eq 'Open') {'[CONNECTED][' + $($Script:oracle_conn.DataSource) + '.' + $($Script:oracle_conn.Database) + ']: '} else { '[DISCONNECTED]: '}) + $(if ($nestedpromptlevel -ge 1) { '>>' }) + '> '
#     $basePrompt + $sqlPrompt
# 
# } #Prompt

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
    
    if ($oracle_conn.State -eq 'Closed')
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
    
    switch($($oracle_options.Results))
    {
        'To Grid' {invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn | Out-GridView -Title $psise.CurrentFile.DisplayName; Write-Host "Query executed successfully"}
        'To Text' {invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn; Write-Host "Query executed successfully"}
        'To File' {
                    $filePath = Get-FileName 'txt' 'Text'
                    if ($filePath)
                    {invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn | Out-File -FilePath $filePath -Force; Write-Host "Query executed successfully"}
                  }
        'To CSV' {
                  $filePath = Get-FileName 'csv' 'CSV'
                  if ($filePath)
                  {invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn | Export-Csv -Path $filepath -NoTypeInformation -Force; Write-Host "Query executed successfully"}
                 }
        'To Variable' {
                        Set-Variable -Name $oracle_options.OutputVariable -Value (invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn) -Scope Global
                    }
    }
        
} #Invoke-ExecuteSql

#######################
function Write-Options
{
    param()
    $oracle_options | Export-Clixml -Path "$psScriptRoot\Options.xml" -Force

} #Write-Options

#######################
# this does not apply to Oracle
# function Switch-Database
# {
#     param()
# 
#     $Action = {
#         $this.Parent.Tag = $this.SelectedItem
#         $window.Close() }
#                 
#     $database = New-ComboBox -Name Database -Width 200 -Height 20 {$DatabaseList} -SelectedItem $conn.Database -On_SelectionChanged $Action -Show
# 
#     if ($database)
#     { $Script:oracle_conn.ChangeDatabase($database) } 
# 
# } #Switch-Database

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
Add-IseMenu -name OracleIse @{
    "Connection" =@{
                    "Connect..." = {Connect-Sql}
                    "Disconnect" = {Disconnect-Sql}
    }
    "Execute" = {Invoke-ExecuteSql} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+F5" -PassThru
    #"Change Database..." = {Switch-Database}
    "Options..." = {Set-Options; Write-Options}
    "Edit" =@{
                    "Make Uppercase         CTRL+SHIFT+U" = {Edit-Uppercase}
                    "Make Lowercase         CTRL+U" = {Edit-Lowercase}
                    "Toggle Comments" = {Switch-SelectedCommentOrText} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+K" -PassThru
            }
} -module OracleIse

Export-ModuleMember -function * -Variable oracle_options, bitmap, oracle_conn #, DatabaseList
