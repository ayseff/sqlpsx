New-Window {
@'
<Canvas>
    <Canvas.Resources>
            <DataTemplate 
        		x:Key = "ColumnTemplate">
        	  <TreeViewItem Header="{Binding Column}" />
        	</DataTemplate>        	
        	<HierarchicalDataTemplate 
        		x:Key = "TableTemplate"
        		ItemsSource="{Binding Table2Column}" 
        		ItemTemplate="{StaticResource ColumnTemplate}" >
        		<TextBlock Text="{Binding Table}" /> 
        	</HierarchicalDataTemplate>        	
        	<HierarchicalDataTemplate 
        		x:Key = "DatabaseTemplate"
        		ItemsSource="{Binding Database2Table}" 
        		ItemTemplate="{StaticResource TableTemplate}" >
        		<TextBlock Text="{Binding Database}" />  
        	 </HierarchicalDataTemplate>
    </Canvas.Resources>
    <TreeView 
    	ItemsSource="{Binding Database}"
    	ItemTemplate="{StaticResource DatabaseTemplate}"
    	SelectedValuePath="Database">
    </TreeView>
</Canvas>
'@
} -DataContext $ds -Width 300 -Height 300 -WindowStartupLocation CenterScreen -show 