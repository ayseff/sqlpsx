$PSXloadModules = @()
$PSXloadModules = "SQLmaint","SQLServer","Agent","Repl","SSIS","Showmbrs"
$PSXloadModules += "SQLParser","adolib","SQLIse"
#$PSXloadModules += "OracleClient","OracleIse"

$PSXremoveModules = $PSXloadModules[($PSXloadModules.count)..0]

$mInfo = $MyInvocation.MyCommand.ScriptBlock.Module
$mInfo.OnRemove = {
    foreach($PSXmodule in $PSXremoveModules){
        if (gmo $PSXmodule)
        {    
          Write-Host "Removing SQLPSX Module - $PSXModule"
          Remove-Module $PSXmodule
        }
    }

    # Remomve $psScriptRoot from $env:PSModulePath
    $pathes = $env:PSModulePath -split ';' | ? { $_ -ne $psScriptRoot}
    $env:PSModulePath = $pathes -join ';'
    #$env:PSModulePath   

    Write-Host "$($MyInvocation.MyCommand.ScriptBlock.Module.name) removed on $(Get-Date)"
}


if (($env:PSModulePath -split ';') -notcontains $psScriptRoot)
{
    $env:PSModulePath += ";" + $psScriptRoot
}


foreach($PSXmodule in $PSXloadModules){
  Write-Host "Loading SQLPSX Module - $PSXModule"
  Import-Module $PSXmodule -global
}
Write-Host "Loading SQLPSX Modules is Done!"
