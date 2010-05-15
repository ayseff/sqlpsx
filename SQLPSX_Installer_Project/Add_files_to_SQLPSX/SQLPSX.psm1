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
# ==============================================================================================

## - Ask to install Modules
$LoadSQLPSX = Read-Host "Do you want to proceed loading SQLPSX modules? y/n."
If ($LoadSQLPSX.ToUpper() -eq 'Y'){

		# Building Module destination path and adding it to the PowerShell PSModulePath variable
		$mpath = $env:PSModulePath.Split(";") ; $DestinationLocation = ";" + $mpath[1] + "SQLPSX\Modules;" + $mpath[0] + "\SQLPSX\Modules;";
		$env:PSModulePath = $env:PSModulePath + $DestinationLocation;
		
		# Here's the SQLPSX modules to be loaded: (feel free to manually customized to your need)
		# the following ones are turned off from the list of modules being loaded: WPK, ISECreamBasic, OracleClient, OracleIse, and SQLIse.
		$PSXloadModules = "SQLServer","Agent","Repl","SSIS","SQLParser","Showmbrs","SQLmaint","adolib";
		
		## - Loading the ISE Modules
		if ($Host.Name -eq 'Windows PowerShell ISE Host'){ 
				$SQLPSXloadModules = "WPK","SQLIse"
				foreach($SQLPSXMod in $SQLPSXLoadModules){
					Write-Host "Loading SQLPSX Module for ISE - $SQLPSXMod";
			  		Import-Module $SQLPSXmod -force;
			  	}
			  	## - Loading the ISE Oracle Modules			
				$loadOracle = "n"; $loadOracle = read-host " Do you need to install the Oracle modules for ISE? y/n.";
				if ($loadOracle.ToUpper() -eq "Y"){	
					$OraISEModules = "ISECreamBasic","OracleIse"
					foreach($SQLPSXMod in $SQLPSXLoadModules){
						Write-Host "Loading SQLPSX Oracle Module for ISE - $SQLPSXMod";
				  		Import-Module $SQLPSXmod -force;
			  		}
				} else {Write-Host "Modules for SQLPSX Oracle ISE not loaded" -ForegroundColor Red}
		}
		
		## - Loading the Oracle Modules	for the PSconsole	
		$loadOracle = "n"; $loadOracle = read-host " Do you need to install the Oracle modules for the PSconsole? y/n.";
		if ($loadOracle.ToUpper() -eq "Y"){	
			$OraModules = "OracleClient"
			# Here's the loop that will load the Oracle modules in PSconsole
			foreach($OraMod in $OraModules){
			  Write-Host "Loading SQLPSX Oracle Module for the PSconsole - $PSXModule";
			  Import-Module $OraMod -force;
			}			
		} else {Write-Host "Modules for SQLPSX Oracle not loaded" -ForegroundColor Red}
		
		# Here's the loop that will load the modules
		foreach($PSXmodule in $PSXloadModules){
		  Write-Host "Loading SQLPSX Module for the PSconsole - $PSXModule";
		  Import-Module $PSXmodule -force;
		}
		Write-Host "Loading SQLPSX Modules is Done!" -ForegroundColor Red
		
} else { Write-Host "Modules for SQLPSX not loaded" -ForegroundColor Red}	

## ----- End of Script ----- ##	
