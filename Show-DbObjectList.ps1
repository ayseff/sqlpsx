New-Window {
@'
<ScrollViewer>
    <ScrollViewer.Resources>
            <DataTemplate 
        		x:Key = "ColumnTemplate">
        	  <TreeViewItem Header="{Binding Column}" />
        	</DataTemplate>  
            <DataTemplate 
        		x:Key = "KeysTemplate">
        	  <TreeViewItem Header="{Binding COLUMN_NAME}" />
        	</DataTemplate>        	
        	<DataTemplate 
        		x:Key = "OperationsTemplate">
        	  <TreeViewItem Header="{Binding operation}" />
        	</DataTemplate>  
            <DataTemplate 
        		x:Key = "RelationsTemplate">
        	  <TreeViewItem Header="{Binding Relation}" />
        	</DataTemplate>
            <DataTemplate 
        		x:Key = "TableTemplate" >
        		<TreeViewItem Header="{Binding Table}" >
                    <TreeViewItem Header="Columns"
                        ItemsSource="{Binding Table2Column}" 
                        ItemTemplate="{StaticResource ColumnTemplate}" />
                    <TreeViewItem Header="Keys"
                        ItemsSource="{Binding Table2Keys}" 
                        ItemTemplate="{StaticResource KeysTemplate}" />
                    <TreeViewItem Header="Relations"
                        ItemsSource="{Binding Table2Relations}" 
                        ItemTemplate="{StaticResource RelationsTemplate}" />
                    <TreeViewItem Header="Operations"
                        ItemsSource="{Binding Table2Operations}" 
                        ItemTemplate="{StaticResource OperationsTemplate}" />
                </TreeViewItem>             
        	</DataTemplate>        	
        	<HierarchicalDataTemplate 
        		x:Key = "DatabaseTemplate"
        		ItemsSource="{Binding Database2Table}" 
        		ItemTemplate="{StaticResource TableTemplate}" >
        		<TreeViewItem Header="{Binding Database}" />  
        	 </HierarchicalDataTemplate>
    </ScrollViewer.Resources>
    <TreeView 
    	ItemsSource="{Binding Database}"
    	ItemTemplate="{StaticResource DatabaseTemplate}" >
    </TreeView>
</ScrollViewer>
'@
} -DataContext $ds -Height 300 -Width 300 -WindowStartupLocation CenterScreen  -show
