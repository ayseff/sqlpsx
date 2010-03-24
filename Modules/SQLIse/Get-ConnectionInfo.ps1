function Get-ConnectionInfo
{
param($bitmap, [Object[]]$StoredConnections)
 
$ui = New-Grid -Columns 2 -Rows 8 -width 428 -height 324 `
    -Children {
      $script:Action = {
        $server = $window | Get-ChildControl Server
        $database = $window | Get-ChildControl Database
        $userName = $window | Get-ChildControl UserName
        $password = $window | Get-ChildControl Password

        $this.Parent.Parent.Tag = new-object PSObject -Property @{
                Server= $server.Text
                Database = ($database.Text + '') 
                UserName =  ($userName.Text + '')
                Password = ($Password.Text + '')
            }
            
        $window.Close() 
    }
    
    new-image -source $bitmap -ColumnSpan 2 -Width 400 -Height 40 -HorizontalAlignment Left
    
    New-Label -Row 1 "Server name (required):" -VerticalContentAlignment 'Center' -FontWeight Bold
    
    New-ComboBox -Name Server -IsEditable -DisplayMemberPath Server `
        -Row 1 -Column 1 -Width 200 -Height 20 -HorizontalAlignment Left `
        -IsSynchronizedWithCurrentItem $true `
        -DataBinding @{ ItemsSource = New-Binding } `
        -On_SelectionChanged {
         
                if ( [string]::IsNullOrEmpty(($window | Get-ChildControl UserName).Text) )
                {
                    $Authentication = $window | Get-ChildControl Authentication
                    $Authentication.SelectedIndex = 0
                }
                else
                {
                    $Authentication = $window | Get-ChildControl Authentication
                    $Authentication.SelectedIndex = 1
                }           
            
        }
     
    
    New-Label -Row 2 "Connect to database:" -VerticalContentAlignment 'Center'
    New-TextBox -Row 2 -Column 1 -Name Database -Width 200 -Height 20 -HorizontalAlignment Left `
        -DataBinding @{Text = New-Binding -Path Database}
    
    New-Label -Row 3 "Authentication:" -VerticalContentAlignment 'Center'
    New-ComboBox -SelectedIndex 0 -Row 3 -Column 1 -Name Authentication -Width 200 -Height 20 -HorizontalAlignment Left {'Windows Authentication','SQL Server Authentication'} `
    -On_SelectionChanged {$userName = $window | Get-ChildControl userName
                          $password = $window | Get-ChildControl Password
                          if ($this.SelectedIndex -eq 1)
                          {$userName.Visibility = 'Visible'; $password.Visibility = 'Visible'}
                          else
                          {$userName.Visibility = 'Hidden'; $password.Visibility = 'Hidden'}}
    
    New-Label -Row 4 "  User name:" -VerticalContentAlignment 'Center'
    New-TextBox -Row 4 -Column 1 -Name UserName -Width 200 -Height 20 -Visibility 'Hidden' -HorizontalAlignment Left `
        -DataBinding @{Text = New-Binding -Path UserName}
    
    New-Label -Row 5 "  Password:" -VerticalContentAlignment 'Center'
    New-TextBox -Row 5 -Column 1 -Name Password -Width 200 -Height 20 -Visibility 'Hidden' -HorizontalAlignment Left `
        -DataBinding @{Text = New-Binding -Path Password}
        
    New-Separator -Row 6 -ColumnSpan 2
    
    New-StackPanel -Orientation horizontal -Row 7 -Column 1 -HorizontalAlignment Right {
        New-Button -Name Connect "Connect" -Row 7  -On_Click $action -Width 75 -Height 25
        New-Button -Name Cancel "Cancel" -Row 7 -Column 1 -On_Click {$window.Close()} -Width 75 -Height 25
    }
    
}
    $StoredConnections = Import-Clixml -Path "$psScriptRoot\Connections.xml"
    if ($StoredConnections)
    {
        $ui.DataContext = $StoredConnections
    }  
    
    $Connection = Show-Window $ui
    
    $ExistingServers = $StoredConnections | Select-Object -ExpandProperty Server
    $ExistingDatabases = $StoredConnections | Select-Object -ExpandProperty Database
    
    if (
        ($ExistingServers -notcontains $Connection.Server) -or 
        ($ExistingDatabases -notcontains $Connection.Database) 
       )
    {
        $StoredConnections += $Connection
        $StoredConnections | Export-Clixml -Path "$psScriptRoot\Connections.xml"
    }
    
    $Connection | Write-Output
}