function Show-TableBrowser ($resource) {
    New-Grid -Rows 1 -Columns 2 {
        New-ListView -Column 0 -Row 1 -Name TableView -View {
           New-GridView -AllowsColumnReorder -Columns {
               New-GridViewColumn "OWNER" 
               New-GridViewColumn "TABLE_NAME" 
           }
        }   -On_SelectionChanged {
            $restriction = New-Object string[] -ArgumentList 2
            $restriction[1] = $this.selecteditem.TABLE_NAME
            $window.Title = "$($conn.database) Browser - $($this.selecteditem.TABLE_NAME)"
            $ColumnView = $window | Get-ChildControl ColumnView
            $ColumnView.ItemsSource = @($conn.GetSchema('Columns', $restriction) |  Sort-Object ID)
        }

        New-ListView -Column 1 -Row 1 -Name ColumnView -View {
            New-GridView -AllowsColumnReorder  -Columns { 
                    New-GridViewColumn "ID"
                    New-GridViewColumn "COLUMN_NAME"
                    New-GridViewColumn "DATATYPE" 
                    New-GridViewColumn "LENGTHINCHARS"
                    New-GridViewColumn "NULLABLE"
                   }
        }

    } -On_Loaded {
            # Perhaps not restrict owner ?
            $conn = $resource.conn
            $user = ($resource.user).ToUpper()
            $window.Title = "$($conn.DataSource).$($user) Database Browser"
            $TableView = $window | Get-ChildControl TableView
            $restriction = New-Object string[] -ArgumentList 2
            $restriction[0] = $user
            $TableView.ItemsSource = @($conn.GetSchema('Tables', $restriction) | Sort-Object OWNER, TABLE_NAME)
    } -asjob -Resource $resource
}


<#


$restriction = New-Object string[] -ArgumentList 2
$restriction[0] = $global:oracle_user
$table_list = @($global:oracle_conn.GetSchema('Tables', $restriction) | Sort-Object OWNER, TABLE_NAME)
$table_list

#>