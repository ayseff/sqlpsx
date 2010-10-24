$mInfo = $MyInvocation.MyCommand.ScriptBlock.Module
$mInfo.OnRemove = {
     if ($Script:oracle_conn.state -eq 'open')
     {
        Write-Host "Connection $($Script:oracle_conn.database) closed"
        $Script:oracle_conn.Close()
     }
    Write-Host "$($MyInvocation.MyCommand.ScriptBlock.Module.name) removed on $(Get-Date)"
    Remove-IseMenu OracleIse
}

# Write-Host "$($MyInvocation.MyCommand.ScriptBlock.Module.name) imported on $(Get-Date)"

import-module ISECreamBasic
import-module OracleClient
import-module WPK

. $psScriptRoot\Get-ConnectionInfo.ps1
. $psScriptRoot\Set-Options.ps1
. $psScriptRoot\Switch-CommentOrText.ps1
. $psScriptRoot\Switch-SelectedCommentOrText.ps1

$Script:oracle_conn=new-object Oracle.DataAccess.Client.OracleConnection

#Load saved options into hashtable
$oracle_options = Import-Clixml -Path "$psScriptRoot\Options.xml"

#$Script:DatabaseList = New-Object System.Collections.ArrayList

$bitmap = new-object System.Windows.Media.Imaging.BitmapImage
$bitmap.BeginInit()
$bitmap.UriSource = "$psScriptRoot\SQLPSX.PNG"
$bitmap.EndInit()


#######################
function Connect-Oracle
{
    param()
    $connInfo = Get-ConnectionInfo $bitmap
    if ($connInfo)
    { 
        $Script:oracle_conn = new-oracle_connection -tns $connInfo.tns -user $connInfo.UserName -password $connInfo.Password
#         if ($Script:oracle_conn.State -eq 'Open')
#         { invoke-oracle_query -sql:'sp_databases' -connection:$Script:oracle_conn | foreach { [void]$Script:DatabaseList.Add($_.DATABASE_NAME) } }
    }

} #Connect-Oracle


#######################
function DisConnect-Oracle
{
    param()

    $Script:oracle_conn.Close()
    #$Script:DatabaseList.Clear()

} #DisConnect-Oracle

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
function Invoke-ExecuteOracle
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
        
        if ($oracle_conn.State -eq 'Closed')
        { Connect-Oracle }
        
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
    
    if ( $displaymode -eq $null)
        {
            if ($env:WPKResult)
            {
                # you need to run the Set-Format script, to showing a modeless window to set this variable 
                $displaymode = $env:WPKResult
            }
            else
            {
                # this is the fallback to the released version
                switch ($options.Results)
                {
                    'To Grid' { $displaymode ='grid'}
                    'To Text' { $displaymode ='auto'}
                    'To File' { $displaymode ='file'}
                    'To CSV'  { $displaymode = 'csv'}
                    'To Variable' { $displaymode ='variable'}

                }
            }
         }

    switch($displaymode)
    {
            'grid' {$res = invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn 
                     if ($res.Tables)
                     {
                            Write-host 'multi'
                        $res.tables | %{ $_ |  Out-GridView -Title $psise.CurrentFile.DisplayName}
                     }
                     else
                     {
                      $res |  Out-GridView -Title $psise.CurrentFile.DisplayName
                     }
                   }
            'auto'  {    $res = invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn
                         if ($res.Tables)
                         {
                            Write-host 'multi'
                            # This doesn#t work, only 1st Resultset displayed
                            $res.tables | %{ $_  | out-host}
                         }
                         else
                         {
                            $res
                         }
                   }
            'table' {$res = invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn
                     if ($res.Tables)
                     {
                            Write-host 'multi'
                        $res.tables | %{ $_ | ft -auto }
                     }
                     else
                     {
                      $res | ft -auto
                     }
                   }
            'list' {$res = invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn
                     if ($res.Tables)
                     {
                            Write-host 'multi'
                        $res.tables | %{ $_ | fl }
                     }
                     else
                     {
                      $res | fl
                     }
                   }
            
        'file' {
                    $filePath = Get-FileName 'txt' 'Text'
                    if ($filePath)
                    {invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn | Out-File -FilePath $filePath -Force
                     Write-Host ""}
                  }
        'csv' {
                  $filePath = Get-FileName 'csv' 'CSV'
                  if ($filePath)
                  {invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn | Export-Csv -Path $filepath -NoTypeInformation -Force
                   Write-Host ""}
                 }
        'variable' {
                        if (! $OutputVariable)
                        {
                            $OutputVariable = Read-Host 'Variable (no "$" needed)'
                        }
                        Set-Variable -Name $OutputVariable -Value (invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn) -Scope Global
                    }
            'isetab'   {
                        $res = invoke-oracle_query -sql $inputScript -connection $Script:oracle_conn
#                          Write-Host $res.gettype()
#                          Write-Host $res[0].gettype()
                         $text = ($res | ft -auto | Out-string -width 10000 -stream ) -replace " *$", ""-replace "\.\.\.$", "" -join "`r`n" 
                         $count = $psise.CurrentPowerShellTab.Files.count
                         $psIse.CurrentPowerShellTab.Files.Add()
                         $Newfile = $psIse.CurrentPowerShellTab.Files[$count]
                         $Newfile.Editor.Text = $text

                    }        
    }
        
} #Invoke-ExecuteSql

#######################
function Write-OracleOptions
{
    param()
    $oracle_options | Export-Clixml -Path "$psScriptRoot\Options.xml" -Force

} #Write-OracleOptions

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
                    "Connect..." = {Connect-Oracle}
                    "Disconnect" = {DisConnect-Oracle}
    }
    "Execute" = {Invoke-ExecuteOracle} | Add-Member NoteProperty ShortcutKey "Alt+F7" -PassThru
    #"Change Database..." = {Switch-Database}
    "Options..." = {Set-OracleOptions; Write-OracleOptions}
    "Edit" =@{
                    "Make Uppercase         CTRL+SHIFT+U" = {Edit-Uppercase}
                    "Make Lowercase         CTRL+U" = {Edit-Lowercase}
                    "Toggle Comments" = {Switch-SelectedCommentOrText} | Add-Member NoteProperty ShortcutKey "CTRL+ALT+K" -PassThru
            }
} # -module OracleIse

Export-ModuleMember -function * -Variable oracle_options, bitmap, oracle_conn #, DatabaseList
