ipmo WPK            
            
$env:WPKResult = "auto"              
New-StackPanel {            
    New-RadioButton -Content "auto"     -GroupName Results -IsChecked $True -On_Click { $env:WPKResult = "auto" }            
    New-RadioButton -Content "list"     -GroupName Results -On_Click { $env:WPKResult = "list" }            
    New-RadioButton -Content "table"    -GroupName Results -On_Click { $env:WPKResult = "table" }
    New-RadioButton -Content "grid"     -GroupName Results -On_Click { $env:WPKResult = "grid" }
    New-RadioButton -Content "variable" -GroupName Results -On_Click { $env:WPKResult = "variable" }
    New-RadioButton -Content "csv"      -GroupName Results -On_Click { $env:WPKResult = "csv" }
    New-RadioButton -Content "file"     -GroupName Results -On_Click { $env:WPKResult = "file" }
                
} -asjob            
            
