# ==============================================================================================
# Microsoft PowerShell Source File -- Created with SAPIEN Technologies PrimalScript 2009
# NAME: SQLPSX_LoadModules.ps1 (renamed to SQLPSX.psm1)
# AUTHOR: Max Trinidad , PutItTogether
# DATE  : 1/3/2010
# 
# COMMENT: Script to load all SQLPSX module into PS Session.
# 03/24/2010 - added new modules: adolib,SQLmaint, & SQLIse.
# 04/04/2010 - Fix $DestinationLocation using split and to end in ";".
# 05/07/2010 - Script remaned to a *psm1 
# 05/11/2010 - Commented out the module path to SQLPSX\Modules to go to modules by default.
# 05/15/2010 - Changes to Reduce code by Chad and Bernd.
# 05/16/2010 - More code clean up remove Import for ISE not working as expected.
# 05/17/2010 - Added code identify ISE machines running x86 and x64 architetures.
# ==============================================================================================
# Here's the SQLPSX modules to be loaded: (feel free to manually customized to your need)

## - Ask to install Modules
$LoadSQLPSX = Read-Host "Do you want to proceed loading SQLPSX modules? Y or press Enter."

 If ($LoadSQLPSX.ToUpper() -eq 'Y'){
                 
         ## - Loading the ISE Modules
         	if ($Host.Name -eq 'Windows PowerShell ISE Host'){
            
  		         # - For ISE even if they don't load the SQLPSX modules then the path is build anyway for manual modules load.
		         $mpath = $env:PSModulePath.Split(";") ;
		         $DestinationLocation = ";" + $mpath[1] + "SQLPSX\Modules;" + $mpath[0] + "\SQLPSX\Modules;";
		         $env:PSModulePath = $env:PSModulePath + $DestinationLocation;
          
		        # Detect x86 or amd64
				if ($env:Processor_Architecture -ne 'x86'){
				
				    Write-Host "*****  64bit PowerShell Environment  *****" -ForegroundColor Yellow -BackgroundColor Black
				    Write-Host "  Warning!! You can't load SQLPSX - SQLIse module on the 64bit version of ISE." -ForegroundColor green #-BackgroundColor Black
                    Write-Host " ****  SQLPSX - SQLIse not loaded!!  ****" -foregroundcolor red #-backgroundcolor black
				
				} else {
				
					Write-Host "*****  32bit PowerShell Environment  *****" -ForegroundColor Yellow -BackgroundColor Black
					Import-Module SQLIse -Global
	             	Write-Host " **** SQLPSX - SQLIse module loaded on ISE!! ****" -ForegroundColor Yellow -backgroundcolor black
				}
             
	        } else {
            
                 # Building Module destination path and adding it to the PowerShell PSModulePath variable
                 $mpath = $env:PSModulePath.Split(";") ;
                 $DestinationLocation = ";" + $mpath[1] + "SQLPSX\Modules;" + $mpath[0] + "\SQLPSX\Modules;";
                 $env:PSModulePath = $env:PSModulePath + $DestinationLocation;
                  
	             ## - Load for PSconsole only
	             $PSXloadModules = "SQLServer","Agent","Repl","SSIS","Showmbrs","SQLmaint","ADOlib";
	             
	             # Here's the loop that will load the modules
	             foreach($PSXmodule in $PSXloadModules){
                 
	               Write-Host "Loading SQLPSX Module for the PSconsole - $PSXModule";
	               Import-Module $PSXmodule -Global; 
	            
            	}
            	
            	 Write-Host "Loading SQLPSX Modules in PSconsole is Done!" -ForegroundColor yellow -backgroundcolor black
        }
         
 } else { Write-Host " **** SQLPSX Module(s) not loaded!! **** " -ForegroundColor Red}   
 
 ## ----- End of Script ----- ## 
