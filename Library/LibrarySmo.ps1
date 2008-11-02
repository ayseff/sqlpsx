# ---------------------------------------------------------------------------
### <Script>
### <Author>
### Chad Miller 
### </Author>
### <Description>
### Defines function wrappers around many of the SMO Classes and implements 2000 
### (80) versions of functions where the SMO class does not support SQL 2000.
### Also defines several utility functions: Get-SqlData, Set-SqlData and Get-SqlShowMbrs
### </Description>
### <Usage>
### . ./LibrarySmo.ps1
### </Usage>
### </Script>
# ---------------------------------------------------------------------------
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") > $null 

$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)
. $scriptRoot\LibraryShowMbrs.ps1

Set-Alias Get-InvalidLogins $scriptRoot\Get-InvalidLogins.ps1
Set-Alias Get-SessionTimeStamp $scriptRoot\Get-SessionTimeStamp.ps1

#######################
function Get-SqlServer
{
    param([string]$sqlserver=$(throw 'Get-SqlServer:`$sqlserver is required.'))
    #When $sqlserver passed in from the SMO Name property, brackets
    #are automatically inserted which then need to be removed
    $sqlserver = $sqlserver -replace "\[|\]"

    Write-Verbose "Get-SqlServer $sqlserver"
    $server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $sqlserver
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.StoredProcedure], "IsSystemObject")
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.Table], "IsSystemObject")
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.View], "IsSystemObject")
    $server.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.UserDefinedFunction], "IsSystemObject")
    #trap { "Check $SqlServer Name"; continue} $server.ConnectionContext.Connect() 
    return $server
    
} #Get-SqlServer

#######################
function Get-SqlDatabase
{ 
    param($sqlserver=$(throw 'Get-SqlDatabase:`$sqlserver is required'),[string]$dbname)

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlDatabase:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlDatabase $($server.Name) $dbname"

    if ($dbname)
    { if (!$server.Databases.Contains("$dbname")) {throw 'Check $dbname Name.'}
      else { 
        if ($server.Databases[$dbname].IsAccessible -eq $false) {throw "Database $dname not accessible."}
        else {$server.Databases[$dbname]} 
      }
    }
    else
    #Skip systems databases
    { $server.Databases | where {$_.IsSystemObject -eq $false -and $_.IsAccessible -eq $true} }

} # Get-SqlDatabase

#######################
function Get-SqlData
{
    param($sqlserver,$dbname=$(throw 'Get-SqlData:`$dbname is required.'),[string]$qry=$(throw 'Get-SqlData:`$qry is required.'))

    switch ($dbname.GetType().Name)
    {
        'String' { $db = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $db = $dbname }
        default { throw "Get-SqlData:Param '`$dbname' must be a String or Database object." }
    }

    #Write-Verbose "Get-SqlData $($db.Parent.Name) $($db.Name) $qry"
    Write-Verbose "Get-SqlData $($db.Parent.Name) $($db.Name)"

    $ds = $db.ExecuteWithResults("$qry")
    $ds.Tables | foreach { $_.Rows}    

}# Get-SqlData

#######################
function Set-SqlData
{
    param($sqlserver,$dbname=$(throw 'Set-SqlData:`$dbname is required.'),[string]$qry=$(throw 'Set-SqlData:`$qry is required.'))

    switch ($dbname.GetType().Name)
    {
        'String' { $db = Get-SqlDatabase $sqlserver $dbname }
        'Database' { $db = $dbname }
        default { throw "Set-SqlData:Param '`$dbname' must be a String or Database object." }
    } 
    
    #Write-Verbose "Set-SqlData $($db.Parent.Name) $($db.Name) $qry"
    Write-Verbose "Set-SqlData $($db.Parent.Name) $($db.Name)"
    
    $db.ExecuteNonQuery("$qry")

}# Set-SqlData

#######################
function ConvertTo-MemberXml
{
    param($member)

    $xmlMember = $null
    $member | foreach { $xmlMember += "<member>$_</member>"}
    return $xmlMember

}# ConvertTo-MemberXml

#######################
function Get-SqlShowMbrs
{
    param($server,[string]$group=$(throw 'Get-SqlShowMbrs:`$group is required.'))

    if ($server.GetType().Name -ne 'Server')
    { throw 'Get-SqlShowMbrs:Param `$server must be a Server object.' }

    Write-Verbose "Get-SqlShowMbrs $($server.Name) $group"

    New-ShowMbrs

    #The call to EnumWindowsGroupInfo will error out on groups which have been removed from AD or 
    #which have been renamed. We need to check for this condition when enumerating groups
    #Individual logins may also be orphaned so we will skip orphaned and enumerate the renamed group 
    #for renamed groups. As a best practice you should run Get-InvalidLogins to identifiy logins/groups and drop
    #orphaned logins or recreate renamed logins to maintain consistency with Active Directory
    $invalidLogin = @()
    Get-InvalidLogins $server.Name | foreach {$invalidLogin += $_.NTLogin}
    $renamed = @{}
    Get-InvalidLogins $server.Name | where {$_.IsRenamed -eq $true} | foreach {$renamed[$_.NTLogin] = $_.NewNTAccount}

    #if group is a valid login i.e. not in invalidLogin array then enumerate it
    if (!($invalidLogin -contains $group ))
    {
        #EnumWindowsGroupInfo is somewhat unreliable, for instance MyServer\SQLServer2005MSSQLUser$MyServer$Myinstance
        #will return null but using a WMI query will return group information. EnumWindowsGroupInfo does not work
        #for groups which have not been granted access to the SQ instnace. since we are using a global session variable
        #to store group user membership the Builtin group is not unique (all other group members should be i.e. a domain
        #or computer cannot have duplicate group names). So Builtin needs to be handled specially
        if ($group -eq 'BUILTIN\Administrators')
        {
           #if we've already enumerated Builtin perhaps for another server remove it and re-enumerate it
            $__SQLPSXGroupUser.remove('BUILTIN\Administrators')

            if ($server.Information.IsClustered)
            {   $allNodes = Get-WmiObject -class MSCluster_Node -namespace "root\mscluster" -computername $($server.Information.NetName) | select name
                foreach ($node in $allNodes)
                { Get-GroupUser "$($node.name)\Administrators" 'BUILTIN\Administrators'}}
            else

            { Get-GroupUser "$($server.Information.NetName)\Administrators" 'BUILTIN\Administrators'}
        }
        else
            { Get-GroupUser $group }
    }
    #if the group is invalid but has been renamed in AD thus still has access to SQL Server enumerate the new group name
    elseif ($renamed.Contains($group))
    {
        Get-GroupUser $renamed[$group]
    }

    return $__SQLPSXGroupUser[$group]

} #Get-SqlShowMbrs

#######################
function Get-SqlUser
{
    param($db)
    begin
    {
        function Select-SqlUser ($db)
        {
            foreach ($user in $db.Users | where {$_.UserType.ToString() -ne 'Certificate'})
            {
                $member = @()

                if ($user.HasDBAccess)
                {
                    $member += @($(Get-SqlUserMember $user))
                    $object = $null

                    #Get objects owned by user, this part is slow with SQL 2000, In 2005 if user owns an object only the schema is listed
                    #as the owned object, so even though SQL 2000 does really doesn't have schemas, will just report they do.
                    if ($db.Parent.Information.Version.Major -ge 9)
                    {
                        foreach ($urn in $user.EnumOwnedObjects())
                        { 
                            $object += [string] "<Object ObjectType=`"" + $urn.Type+ "`" ObjectName=`"" + $urn.GetNameForType($urn.Type) + "`"></Object>"
                        }
                    }
                    elseif ($user.EnumOwnedObjects() -ne $null)
                    { $object += [string] "<Object ObjectType=`"Schema`" ObjectName=`"" + $user.Name + "`"></Object>" }

                    #Return SqlUser Object
                    $user | add-Member -memberType noteProperty -name members -value $member -passthru | 
                            add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                            add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                            add-Member -memberType noteProperty -name objects -value $object -passthru |
                            add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                            add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
                    
                }  
             }

        } #Select-SqlUser
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlUser $($_.Name)"
              Select-SqlUser $_ }
            else
            { throw 'Get-SqlUser:Param `$db must be a database object.' }
        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlUser }
    }

} # Get-SqlUser

#######################
function New-SqlUserMember
{
    Write-Verbose "New-SqlUserMember"

    #__SQLPSXUserMember is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXUserMember))
    { Set-Variable __SQLPSXUserMember @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-SQLUserMember

#######################
function Get-SqlUserMember
{
    param($user,$db)

    Write-Verbose "Get-SqlUserMember $($user.Name) $($db.Name)"

    New-SqlUserMember

    if ($user -and $user.GetType().Name -eq 'User')
    {
        $key = $null
        $key = $user.parent.parent.name + "." + $user.parent.name

        if(!($__SQLPSXUserMember.$key.$($user.Name))) {
            $member = @()
            $tmpMember = $null        
            if ($user.LoginType -eq 1)
            {
                $tmpMember = Get-SqlShowMbrs $user.parent.parent $user.Login
                if ($tmpMember -ne $null)
                 {$member += $tmpMember}
            }

            #If Guest user i.e. UserType = NoLogin
            if ($user.UserType.ToString() -eq 'NoLogin' -or $user.Name -eq 'guest')
            { $member += $user.Name }
            elseif ($member -notcontains $user.Login)
            { $member += $user.Login }
            #Add member to global hash
            $__SQLPSXUserMember[$key] += @{$user.Name = $member}
            #Return member array
            Return $member
        }
        else
            { $__SQLPSXUserMember.$key.$($user.Name) }
    }
    elseif ($db -and $db.GetType().Name -eq 'Database')
    {
        $key = $null
        $key = $db.parent.name + "." + $db.name
        if(!($__SQLPSXUserMember[$key])) {
            Get-SqlUser $db > $null
            #Return User Hash
            $__SQLPSXUserMember[$key]
        }
        else
        #Return Login Hash
        { $__SQLPSXUserMember[$key] }
    }
    else
    { throw 'Get-SqlUserMember:Param `$user or `$db missing or invalid type.' }

} # Get-SqlUserMember

#######################
function Get-SqlDatabaseRole
{
    param($db)
    begin
    {
        function Select-SqlDatabaseRole ($db)
        {

            foreach ($role in $db.Roles)
            {
                $member = @()
                $member += @($(Get-SqlDatabaseRoleMember $role))

                #Return DatabaseRole Object
                $role | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                        add-Member -memberType noteProperty -name members -value $member -passthru | 
                        add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                        add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $db.Name -passthru

            }

        } # Select-SqlDatabaseRole
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlDatabaseRole $($_.Name)"
              Select-SqlDatabaseRole $_ }
            else
            { throw 'Get-SqlDatabaseRole:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlDatabaseRole }
    }

} #Get-SqlDatabaseRole

#######################
function New-SqlDatabaseRoleMember
{
    Write-Verbose "New-SqlDatabaseRoleMember"

    #__SQLPSXDatabaseRoleMember is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXDatabaseRoleMember))
    { Set-Variable __SQLPSXDatabaseRoleMember @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-SqlDatabaseRoleMember

#######################
function Get-SqlDatabaseRoleMember
{
    param($role,$db)

    Write-Verbose "Get-SqlDatabaseRoleMember $($role.Name) $($db.Name)"

    New-SqlDatabaseRoleMember

    if ($role -and $role.GetType().Name -eq 'DatabaseRole')
    {
        $key = $null
        $key = $role.parent.parent.name + "." + $role.parent.name

        if(!($__SQLPSXDatabaseRoleMember.$key.$($role.Name))) {
            $user = @{}
            $user = Get-SqlUserMember -db $role.parent

            $member = @()
            $tmpMember = @()        

            #Although public is a role its members cannot be enumerated using EnumMembers()
            if (!($role.Name -match "public"))
            {
                 #The EnumMembers() method will recursively (reports nested role members) enumerate role membership for you
                 #Thank You Microsoft SMO Developers!
                 #List only members that are Roles or valid users i.e. users which meet condition in get-sqluser, this will 
                 #eliminate users that do not have access to the database (orphaned DB users)
                 $tmpMember = $role.EnumMembers() | where { $role.parent.Roles.Contains($_) -or $user.Contains($_) }
                 if ($tmpMember -ne $null)
                 {$member += $tmpMember}
                 $member += $role.Name
                 #Now let's re-enumerate and flatten out Windows group membership, adding the SqlUser Objects members array
                 #However we will ensure we only list an individual login once
                 $member | where { $user.Contains($_) } | foreach { $member += $user[$_] }
                 $member = $member | Sort-Object -unique
                
            }
            #enumerate public role by extractng unique values from user hash
            else
            {
                $user.values | foreach { $member += $_ } 
                $member += $role.Name
                $member = $member | Sort-Object -unique
            }
            #Add member to global hash
            $__SQLPSXDatabaseRoleMember[$key] += @{$role.Name = $member}
            #Return member array
            Return $member
        }
        else
            { $__SQLPSXDatabaseRoleMember.$key.$($role.Name) }
    }
    elseif ($db -and $db.GetType().Name -eq 'Database')
    {
        $key = $null
        $key = $db.parent.name + "." + $db.name
        if(!($__SQLPSXDatabaseRoleMember[$key])) {
            Get-SqlDatabaseRole $db > $null
            #Return User Hash
            $__SQLPSXDatabaseRoleMember[$key]
        }
        else
        #Return Login Hash
        { $__SQLPSXDatabaseRoleMember[$key] }
    }
    else
    { throw 'Get-SqlDatabaseRoleMember:Param `$role or `$db missing or invalid type.' }

} # Get-SqlDatabaseRoleMember

#######################
function Get-SqlLogin
{
    param($sqlserver=$(throw 'Get-SqlLogin:`$sqlserver is required.'))

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlLogin:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlLogin $($server.Name)"

    foreach ($login in $server.Logins | where {$_.LoginType.ToString() -ne 'Certificate'})
    {
        $member = @()
        $member += @($(Get-SqlLoginMember $login))

        #Return Login Object
        $login | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                 add-Member -memberType noteProperty -name members -value $member -passthru | 
                 add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                 add-Member -memberType noteProperty -name Server -value $server.Name -passthru

    }

} # Get-SqlLogin

#######################
function Get-SqlLinkedServerLogin
{
    param($sqlserver=$(throw 'Get-SqlLogin:`$sqlserver is required.'))

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlLogin:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlLogin $($server.Name)"

    foreach ($linkedSrv in $server.LinkedServers)
    {
        #Some DataSources contains commas such as "myserver.mydomain.com,1433"
        #This can cause problems when exporting to csv so replace , with ;
        $dataSource = $linkedSrv.DataSource -replace ",",";"

        foreach ($linkedSrvLogin in $linkedSrv.LinkedServerLogins)
        {
        #Return linked Server Login Object
        $linkedSrvLogin | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                          add-Member -memberType noteProperty -name LinkedServer -value $linkedSrv.Name -passthru |
                          add-Member -memberType noteProperty -name DataSource -value $dataSource -passthru |
                          add-Member -memberType noteProperty -name Server -value $server.Name -passthru
        }
    }
}# Get-SqlLinkedServerLogin

#######################
function New-SqlLoginMember
{
    Write-Verbose "New-SqlLoginMember"

    #__SQLPSXLoginMember is a session variable, so only create if it doesn't exist
    if (!(Test-Path Variable:__SQLPSXLoginMember))
    { Set-Variable __SQLPSXLoginMember @{} -Scope Global -Option AllScope -Description "SQLPSX variable" }
    
} #New-SQLLoginMember

#######################
function Get-SqlLoginMember
{
    param($login,$server)

    Write-Verbose "Get-SqlLoginMember $($login.Name) $($server.Name)"

    New-SqlLoginMember

    if ($login -and $login.GetType().Name -eq 'Login')
    {
        if(!($__SQLPSXLoginMember.$($login.parent.name).$($login.Name))) {
            $member = @()
            $tmpMember = $null        
            if ($login.LoginType -eq 1)
            {
                $tmpMember = Get-SqlShowMbrs $login.parent $login.Name
                if ($tmpMember -ne $null)
                 {$member += $tmpMember}
            }

            if ($member -notcontains $login.Name)
            { $member += $login.Name }
            #Add member to global hash
            $__SQLPSXLoginMember[$login.parent.name] += @{$login.Name = $member}
            #Return member array
            Return $member
        }
        else
            { $__SQLPSXLoginMember.$($login.parent.name).$($login.Name) }

    }
    elseif ($server -and $server.GetType().Name -eq 'Server')
    {
        if(!($__SQLPSXLoginMember[$server.name])) {
            Get-SqlLogin $server > $null
            #Return Login Hash
            $__SQLPSXLoginMember[$server.name]
        }
        else
        #Return Login Hash
        { $__SQLPSXLoginMember[$server.name] }
    }
    else
    { throw 'Get-SqlLoginMember:Param `$login or `$server missing or invalid type.' }

} # Get-SqlLoginMember

#######################
function Get-SqlServerRole
{
    param($sqlserver=$(throw 'Get-SqlServerRole:`$sqlserver is required.'))

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlServerRole:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlServerRole $($server.Name)"

    $login = @{}
    $login = Get-SqlLoginMember -server $server
 
    foreach ($svrole in $server.Roles)
    {
        $member = @()
        
        #Although public is a role its members cannot be enumerated using EnumServerRoleMembers()
        if (!($svrole.Name -match "public"))
        {
            #EnumMembers and flatten out Windows group membership, adding the Sqllogin Objects members array
            #However we will ensure we only list an individual login once
            $svrole.EnumServerRoleMembers() | foreach {$login.$_} | foreach {if (!($member -contains $_)) {$member += $_}}
        }
        #enumerate public role by extractng unique values from login hash
        else
        {
            $login.values | foreach { $member += $_ }
            $member = $member | Sort-Object -unique
        }

        $member += $svrole.Name

        #Return ServerRole Object
        $svrole | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                  add-Member -memberType noteProperty -name members -value $member -passthru | 
                  add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                  add-Member -memberType noteProperty -name Server -value $server.Name -passthru
    }

} #Get-SqlServerRole

#######################
function Get-SqlServerPermission
{
    param($sqlserver=$(throw 'Get-SqlServerPermission:`$sqlserver is required.'))

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlServerPermission:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlServerPermission $($server.Name)"

    if ($server.Information.Version.Major -ge 9)
    {$perm = Get-SqlServerPermission90 $server; $perm += Get-SqlDatabasePermission $(Get-SqlDatabase $server 'master'); $perm}
    else {Get-SqlDatabasePermission $(Get-SqlDatabase $server 'master')}

}# Get-SqlServerPermission

#######################
function Get-SqlServerPermission90
{
    param($server=$(throw 'Get-SqlServerPermission90:`$server is required.'))

    if ($server.GetType().Name -ne 'Server')
    { throw 'Get-SqlServerPermission90:Param `$server must be a Server object.' }

    Write-Verbose "Get-SqlServerPermission90 $($server.Name)"
    
    #SQL 2000 Does not suppport the concept of Server Permissions. SQL Server 2000 relies on Server Roles to grant server level permissions
    #There are only three grantable permissions in SQL 2000/2005 only applicable to the master database: CREATE DATABASE; BACKUP DATABASE; BACKUP LOG
    #Although we may think Create Database, Backup and Backup Log are server level permissions the SQL development team apparently does not
    #share the same opinion and EnumServerPermissions will not enumerate these permissions.
    #since I think they should I'll create a custom object and append to accomplish this in Get-SqlServerPermission

    $principal = @{}
    #Get-SqlLogin $server | foreach  { $principal[$_.Name] = $_.members }
    $principal = Get-SqlLoginMember -server $server

        #Apparently having a login to SQL Server is considered a ServePermission in SQL 2005, all logins have this permission
        #I'd rather eliminate the CONNECT SQL permissionType from the output
      foreach ($perm in $server.EnumServerPermissions() | where {$_.PermissionType.ToString() -ne 'CONNECT SQL'})
      {
        $member = @()
        $member = $principal["$($perm.Grantee)"]
        #Return ServerPermission Object
        $perm | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                   add-Member -memberType noteProperty -name members -value $member -passthru | 
                   add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                   add-Member -memberType noteProperty -name dbname 'master' -passthru |
                   add-Member -memberType noteProperty -name Server -value $server.Name -passthru
      }
} #Get-SqlServerPermission90

#######################
function Get-Permission80
{
param($db=$(throw 'Get-Permission80:`$db is required.'))

if ($db.GetType().Name -ne 'Database')
{ throw 'Get-Permission80:Param `$db must be a Database object.' }

Write-Verbose "Get-Permission80 $($db.Name)"

$qry = @"
SELECT
grantee_principal.name AS [Grantee],
grantor_principal.name AS [Grantor],
CASE prmssn.protecttype WHEN 204 THEN 'GRANT_W_GRANT' WHEN 205 THEN 'GRANT' WHEN 206 THEN 'DENY' END AS [PermissionState],
CASE prmssn.id WHEN 0 THEN 'Database' ELSE 'ObjectOrColumn' END  AS [ObjectClass],
null AS [ColumnName],
CASE prmssn.id WHEN 0 THEN DB_NAME() ELSE object_name(prmssn.id) END AS [ObjectName],
user_name(prmssn.uid) AS [ObjectSchema],
CASE prmssn.id WHEN 0 THEN DB_ID() ELSE prmssn.id END AS [ObjectID],
CASE 
	WHEN 1 = grantee_principal.issqlrole THEN 'DatabaseRole'
	WHEN 1 = grantee_principal.isapprole THEN 'ApplicationRole'
	ELSE 'User'
END AS [GranteeType],
CASE
	WHEN 1 = grantor_principal.issqlrole THEN 'DatabaseRole'
	WHEN 1 = grantor_principal.isapprole THEN 'ApplicationRole'
	ELSE 'User'
END AS [GrantorType],
CASE CAST(prmssn.action AS int) 
	WHEN 26 THEN 'REFERENCES'
	WHEN 178 THEN 'CREATE FUNCTION'
	WHEN 193 THEN 'SELECT'
	WHEN 195 THEN 'INSERT'
	WHEN 196 THEN 'DELETE'
	WHEN 197 THEN 'UPDATE'
	WHEN 198 THEN 'CREATE TABLE'
	WHEN 203 THEN 'CREATE DATABASE'
	WHEN 207 THEN 'CREATE VIEW'
	WHEN 222 THEN 'CREATE PROCEDURE'
	WHEN 224 THEN 'EXECUTE'
	WHEN 228 THEN 'BACKUP DATABASE'
	WHEN 233 THEN 'CREATE DEFAULT'
	WHEN 235 THEN 'BACKUP LOG'
	WHEN 236 THEN 'CREATE RULE'
END AS [PermissionType]
FROM
dbo.sysprotects AS prmssn
INNER JOIN sysusers AS grantee_principal ON grantee_principal.uid = prmssn.uid
INNER JOIN sysusers AS grantor_principal ON grantor_principal.uid = prmssn.grantor
WHERE (prmssn.id > 0 AND OBJECTPROPERTY(prmssn.id,'IsMSShipped') = 0)
OR prmssn.id = 0
"@
    Get-SqlData -dbname $db -qry $qry

}# Get-Permission80

# Note: From BOL "sp_helprotect does not return information about securables that are introduced in SQL Server 2005."
# The output of 90 and 80 versions of Get-SqlDatabasePermission and Get-SqlObjectPermissions will not match when 
# run against a SQL 2005 or higher server
#######################
function Get-SqlDatabasePermission
{
    param($db)
    begin
    {
        #######################
        function Select-SqlDatabasePermission90 ($db)
        {
                Write-Verbose "Get-SqlDatabasePermission90 $($db.Name)"

                $user = @{}
                $role = @{}
                $user = Get-SqlUserMember -db $db
                $role = Get-SqlDatabaseRoleMember -db $db
                #Unfortunately on case sensitive servers you can have a role and user with the same name. So instead of using a single hash called
                #principal we will use two different hashes and use the GranteeType to determine which one to use for listing the effective members
                #of the permission.

            foreach ($perm in $db.EnumDatabasePermissions() | where {$_.PermissionType.ToString() -ne 'CONNECT'})
            {
                $member = @()
                switch ($perm.GranteeType)
                {
                    'User' { $member = $user["$($perm.Grantee)"] }
                    'DatabaseRole' { $member = $role["$($perm.Grantee)"] }
                }

                #Return DatabasePermission Object
                $perm | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                          add-Member -memberType noteProperty -name members -value $member -passthru | 
                          add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru | 
                          add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                          add-Member aliasproperty dbname ObjectName -passthru
            }

        }# Select-SqlDatabasePermission90

        #######################
        function Select-SqlDatabasePermission80 ($db)
        {
                Write-Verbose "Get-SqlDatabasePermission80 $($db.Name)"

                $user = @{}
                $role = @{}
                $user = Get-SqlUserMember -db $db
                $role = Get-SqlDatabaseRoleMember -db $db

            foreach ($perm in Get-Permission80 $db | where {$_.ObjectClass -eq 'Database'})
            { 
                $member = @()
                switch ($perm.GranteeType)
                {
                    'User' { $member = $user["$($perm.Grantee)"] }
                    'DatabaseRole' { $member = $role["$($perm.Grantee)"] }
                }

                #Return DatabasePermission Object
                $perm | add-member -memberType NoteProperty -name timestamp  -value $(Get-SessionTimeStamp)  -passthru |
                          add-member -memberType NoteProperty -name members -value $member -passthru |
                          add-member -memberType NoteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru |
                          add-member -memberType NoteProperty -name Server  -value $db.parent.Name -passthru |
                          add-member aliasproperty dbname  ObjectName -passthru
            }
            
        }# Select-SqlDatabasePermission80
    }
    process
    {
        if ($_) {
            if ($_.GetType().Name -eq 'Database')
            {
                Write-Verbose "Get-SqlDatabasePermission $($_.Name)"
                if ($_.Parent.Information.Version.Major -ge 9)
                { Select-SqlDatabasePermission90 $_ }
                else { Select-SqlDatabasePermission80 $_ }
            }
            else { throw 'Get-SqlDatabasePermission:Param `$db must be a database object.' }
        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlDatabasePermission }
    }

}# Get-SqlServerPermission

#######################
function Get-Permission90
{
param($db=$(throw 'Get-Permission90:`$db is required.'))

if ($db.GetType().Name -ne 'Database')
{ throw 'Get-Permission90:Param `$db must be a Database object.' }

Write-Verbose "Get-Permission90 $($db.Name)"

$qry = @"
SELECT
grantee_principal.name AS [Grantee],
grantor_principal.name AS [Grantor],
CASE prmssn.state WHEN 'W' THEN 'GRANT_W_GRANT' WHEN 'G' THEN 'GRANT' WHEN 'D' THEN 'DENY' WHEN 'R' THEN 'REVOKE'END AS [PermissionState],
'ObjectOrColumn' AS [ObjectClass],
COL_NAME(prmssn.major_id,prmssn.minor_id) AS [ColumnName],
obj.name AS [ObjectName],
schema_name(obj.schema_id) AS [ObjectSchema],
prmssn.major_id AS [ObjectID],
CASE grantee_principal.type WHEN 'S' THEN 'User' WHEN 'U' THEN 'WindowsUser' WHEN 'G' THEN 'WindowsGroup' WHEN 'A' THEN 'ApplicationRole' WHEN 'R' THEN 'DatabaseRole'
END AS [GranteeType],
CASE grantor_principal.type WHEN 'S' THEN 'User' WHEN 'U' THEN 'WindowsUser' WHEN 'G' THEN 'WindowsGroup' WHEN 'A' THEN 'ApplicationRole' WHEN 'R' THEN 'DatabaseRole'
END AS [GrantorType],
CASE prmssn.type
WHEN 'AL' THEN 'ALTER'
WHEN 'CL' THEN 'CONTROL'
WHEN 'DL' THEN 'DELETE'
WHEN 'EX' THEN 'EXECUTE'
WHEN 'IN' THEN 'INSERT'
WHEN 'RC' THEN 'RECEIVE'
WHEN 'RF' THEN 'REFERENCES'
WHEN 'SL' THEN 'SELECT'
WHEN 'TO' THEN 'TAKE OWNERSHIP'
WHEN 'UP' THEN 'UPDATE'
WHEN 'VW' THEN 'VIEW DEFINITION'
END AS [PermissionType]
FROM
sys.database_permissions AS prmssn
INNER JOIN sys.database_principals AS grantee_principal ON grantee_principal.principal_id = prmssn.grantee_principal_id
INNER JOIN sys.database_principals AS grantor_principal ON grantor_principal.principal_id = prmssn.grantor_principal_id
INNER JOIN sys.all_objects AS obj ON obj.object_id = prmssn.major_id and prmssn.class = 1
WHERE prmssn.major_id > 0
UNION
SELECT
grantee_principal.name AS [Grantee],
grantor_principal.name AS [Grantor],
CASE prmssn.state WHEN 'W' THEN 'GRANT_W_GRANT' WHEN 'G' THEN 'GRANT' WHEN 'D' THEN 'DENY' WHEN 'R' THEN 'REVOKE'END AS [PermissionState],
'Schema' AS [ObjectClass],
null AS [ColumnName],
obj.name AS [ObjectName],
null AS [ObjectSchema],
prmssn.major_id AS [ObjectID],
CASE grantee_principal.type WHEN 'S' THEN 'User' WHEN 'U' THEN 'WindowsUser' WHEN 'G' THEN 'WindowsGroup' WHEN 'A' THEN 'ApplicationRole' WHEN 'R' THEN 'DatabaseRole'
END AS [GranteeType],
CASE grantor_principal.type WHEN 'S' THEN 'User' WHEN 'U' THEN 'WindowsUser' WHEN 'G' THEN 'WindowsGroup' WHEN 'A' THEN 'ApplicationRole' WHEN 'R' THEN 'DatabaseRole'
END AS [GrantorType],
CASE prmssn.type
WHEN 'AL' THEN 'ALTER'
WHEN 'CL' THEN 'CONTROL'
WHEN 'DL' THEN 'DELETE'
WHEN 'EX' THEN 'EXECUTE'
WHEN 'IN' THEN 'INSERT'
WHEN 'RC' THEN 'RECEIVE'
WHEN 'RF' THEN 'REFERENCES'
WHEN 'SL' THEN 'SELECT'
WHEN 'TO' THEN 'TAKE OWNERSHIP'
WHEN 'UP' THEN 'UPDATE'
WHEN 'VW' THEN 'VIEW DEFINITION'
END AS [PermissionType]
FROM
sys.database_permissions AS prmssn
INNER JOIN sys.database_principals AS grantee_principal ON grantee_principal.principal_id = prmssn.grantee_principal_id
INNER JOIN sys.database_principals AS grantor_principal ON grantor_principal.principal_id = prmssn.grantor_principal_id
INNER JOIN sys.schemas AS obj ON obj.schema_id = prmssn.major_id and prmssn.class = 3
"@

    Get-SqlData -dbname $db -qry $qry

}# Get-Permission90

#######################
function Get-SqlObjectPermission
{
    param($db)
    begin
    {
        #######################
        function Select-SqlObjectPermission90 ($db)
        {
            Write-Verbose "Get-SqlObjectPermission90 $($db.Name)"

            $user = @{}
            $role = @{}
            $user = Get-SqlUserMember -db $db
            $role = Get-SqlDatabaseRoleMember -db $db

            Write-Verbose "EnumObjectPermissions"

            #Skip object permissions for system objects i.e. ObjectID > 0
            #EnumObjectPermissions() will take a long time to return data for very large permission sets
            #in my testing a database with over 57,000 permission will take 10 min. 
            #dtproperties is an annoying little MS table used for DB diagrams it shows up as user table and
            #is automatically created when someone clicks on DB Diagrams in SSMS/EM, permissions default to public
            foreach ($perm in $db.EnumObjectPermissions() | where {$_.ObjectID -gt 0 -and $_.ObjectName -ne 'dtproperties'})
            {
                $member = @()
                switch ($perm.GranteeType)
                {
                    'User' { $member = $user["$($perm.Grantee)"] }
                    'DatabaseRole' { $member = $role["$($perm.Grantee)"] }
                }

                #Return ObjectPermission Object
                $perm |  add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                           add-Member -memberType noteProperty -name members -value $member -passthru |
                           add-Member -memberType noteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru |
                           add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                           add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
            }

        } #Select-SqlObjectPermission90

        #######################
        function Select-SqlObjectPermission80 ($db)
        {
            Write-Verbose "Get-SqlObjectPermission80 $($db.Name)"

            $user = @{}
            $role = @{}
            $user = Get-SqlUserMember -db $db
            $role = Get-SqlDatabaseRoleMember -db $db

            foreach ($perm in Get-Permission80 $db | where {$_.ObjectClass -eq 'ObjectOrColumn' -and $_.ObjectID -gt 0 -and $_.ObjectName -ne 'dtproperties'})
            { 
                $member = @()
                switch ($perm.GranteeType)
                {
                    'User' { $member = $user["$($perm.Grantee)"] }
                    'DatabaseRole' { $member = $role["$($perm.Grantee)"] }
                }

                #Return ObjectPermission Object
                $perm | add-member -memberType NoteProperty -name timestamp  -value $(Get-SessionTimeStamp)  -passthru |
                          add-member -memberType NoteProperty -name members -value $member -passthru |
                          add-member -memberType NoteProperty -name Xmlmembers -value $(ConvertTo-MemberXml $member) -passthru |
                          add-member -memberType NoteProperty -name Server  -value $db.parent.Name -passthru |
                          add-member -memberType NoteProperty -name dbname -value $db.name -passthru
            }

        } #Select-SqlObjectPermission80
    }
    process
    {
        if ($_) {
            if ($_.GetType().Name -eq 'Database')
            {
                Write-Verbose "Get-SqlObjectPermission $($_.Name)"
                if ($_.Parent.Information.Version.Major -ge 9)
                { Select-SqlObjectPermission90 $_ }
                else { Select-SqlObjectPermission80 $_ }
            }
            else { throw 'Get-SqlObjectPermission:Param `$db must be a database object.' }
        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlObjectPermission }
    }

}# Get-SqlObjectPermission

#######################
function Get-SqlTable
{
    param($db, $name="*")
    begin
    {
        function Select-SqlTable ($db, $name="*")
        {

            foreach ($table in $db.Tables)
            {
                if ($table.IsSystemObject -eq $false -and ($table.name -like "*$name*" -or $name.Contains($table.name)))
                {
                #Return Table Object
                $table | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $table.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
                }
            }

        } # Select-SqlTable
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlTable $($_.Name)"
              Select-SqlTable $_ -name $name }
            else
            { throw 'Get-SqlTable:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlTable -name $name }
    }

} #Get-SqlTable

#######################
function Get-SqlStoredProcedure
{
    param($db, $name="*")
    begin
    {
        function Select-SqlStoredProcedure ($db, $name="*")
        {

            foreach ($storedProcedure in $db.StoredProcedures)
            {
                if ($storedProcedure.IsSystemObject -eq $false -and ($storedProcedure.name -like "*$name*" -or $name.Contains($storedProcedure.name)))
                {
                #Return StoredProcedure Object
                $storedProcedure | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
      add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $storedProcedure.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
                }
            }

        } # Select-SqlStoredProcedure
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlStoredProcedure $($_.Name)"
              Select-SqlStoredProcedure $_ -name $name }
            else
            { throw 'Get-SqlStoredProcedure:Param `$db must be a database object.' }
        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlStoredProcedure -name $name }
    }

} #Get-SqlStoredProcedure

#######################
function Get-SqlView
{
    param($db, $name="*")
    begin
    {
        function Select-SqlView ($db, $name="*")
        {

            foreach ($view in $db.Views)
            {
                if ($view.IsSystemObject -eq $false -and ($view.name -like "*$name*" -or $name.Contains($view.name)))
                {
                #Return View Object
                $view | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $view.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
                }
            }

        } # Select-SqlView
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlView $($_.Name)"
              Select-SqlView $_ -name $name }
            else
            { throw 'Get-SqlView:Param `$db must be a database object.' }
        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlView -name $name }
    }

} #Get-SqlView

#######################
function Get-SqlUserDefinedDataType
{
    param($db, $name="*")
    begin
    {
        function Select-SqlUserDefinedDataType ($db, $name="*")
        {

            foreach ($userDefinedDataType in $db.UserDefinedDataTypes)
            {
           if ($userDefinedDataType.IsSystemObject -eq $false -and ($userDefinedDataType.name -like "*$name*" -or $name.Contains($userDefinedDataType.name)))
                { 
                #Return UserDefinedDataType Object
                $userDefinedDataType | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $userDefinedDataType.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
                }
            }

        } # Select-SqlUserDefinedDataType
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlUserDefinedDataType $($_.Name)"
              Select-SqlUserDefinedDataType $_ -name $name }
            else
            { throw 'Get-SqlUserDefinedDataType:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlUserDefinedDataType -name $name }
    }

} #Get-SqlUserDefinedDataType

#######################
function Get-SqlUserDefinedFunction
{
    param($db, $name="*")
    begin
    {
        function Select-SqlUserDefinedFunction ($db, $name="*")
        {

            foreach ($userDefinedFunction in $db.UserDefinedFunctions)
            {
           if ($userDefinedFunction.IsSystemObject -eq $false -and ($userDefinedFunction.name -like "*$name*" -or $name.Contains($userDefinedFunction.name)))
                {
                #Return UserDefinedFunction Object
                $userDefinedFunction | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $userDefinedFunction.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
                }
            }

        } #Select-SqlUserFunction
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlUserDefinedFunction $($_.Name)"
              Select-SqlUserDefinedFunction $_ -name $name }
            else
            { throw 'Get-SqlUserDefinedFunction:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlUserDefinedFunction -name $name }
    }

} #Get-SqlUserDefinedFunction

#######################
function Get-SqlSynonym
{
    param($db, $name="*")
    begin
    {
        function Select-SqlSynonym ($db, $name="*")
        {

            foreach ($synonym in $db.Synonyms)
            {
                if ($synonym.name -like "*$name*" -or $name.Contains($synonym.name))
                {
                #Return Synonym Object
                $synonym | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $synonym.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
                }
            }

        } # Select-SqlSynonym
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlSynonym $($_.Name)"
              Select-SqlSynonym $_ -name $name }
            else
            { throw 'Get-SqlSynonym:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlSynonym -name $name }
    }

} #Get-SqlSynonym

#######################
function Get-SqlTrigger
{
    param($smo, $name="*")
    begin
    {
        function Select-SqlTrigger ($smo, $name="*")
        {

            foreach ($trigger in $smo.Triggers)
            {
                if ($trigger.name -like "*$name*" -or $name.Contains($trigger.name))
                {
                switch ($smo.GetType().Name)
                {
                    'Server' { $server = $smo.Name }
                    'Database' { $server = $smo.parent.Name; $dbname = $smo.Name }
                    #Default is table or view
                    Default { $server = $smo.parent.parent.Name; $dbname = $smo.parent.Name; $schema = $smo.parent.schema; $tbl = $smo.Name }
                }
                #Return Trigger Object
                if ($trigger -ne $null)
                {
                $trigger | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $triggr.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $server -passthru |
                        add-Member -memberType noteProperty -name dbname -value $dbname -passthru |
                        add-Member -memberType noteProperty -name Schema -value $schema -passthru |
                        add-Member -memberType noteProperty -name Table -value $tbl -passthru 
                }
                }
            }

        } #Select-SqlTrigger
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Server' -or $_.GetType().Name -eq 'Database' -or $_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View')
            { Write-Verbose "Get-SqlTrigger $($_.Name)"
              Select-SqlTrigger $_ -name $name }
            else
            { throw 'Get-SqlTrigger:Param `$smo must be a server, database, table or view object.' }

        }
    }
    end
    {
        if ($smo)
        { $smo | Get-SqlTrigger -name $name }
    }

} #Get-SqlTrigger

#######################
function Get-SqlColumn
{
    param($table)
    begin
    {
        function Select-SqlColumn ($table)
        {

            foreach ($column in $table.Columns)
            {
                #Return Column Object
                $column | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $column.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                        add-Member -memberType noteProperty -name Schema -value $table.schema -passthru |
                        add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
            }

        } # Select-SqlColumn
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View')
            { Write-Verbose "Get-SqlColumn $($_.Name)"
              Select-SqlColumn $_ }
            else
            { throw 'Get-SqlColumn:Param `$table must be a table or view object.' }

        }
    }
    end
    {
        if ($table)
        { $table | Get-SqlColumn }
    }

} #Get-SqlColumn

#######################
function Get-SqlIndex
{
    param($table)
    begin
    {
        function Select-SqlIndex ($table)
        {

            foreach ($index in $table.Indexes)
            {
                #Return Index Object
                $index | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
  add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $index.ExtendedProperties) -passthru |
  add-Member -memberType noteProperty -name XMLIndexedColumns -value $(ConvertTo-IndexedColumnXML $index.IndexedColumns) -passthru |
                        add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                        add-Member -memberType noteProperty -name Schema -value $table.Schema -passthru |
                        add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
            }

        } #Select-SqlIndex
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View')
            { Write-Verbose "Get-SqlIndex $($_.Name)"
              Select-SqlIndex $_ }
            else
            { throw 'Get-SqlIndex:Param `$table must be a table or view object.' }

        }
    }
    end
    {
        if ($table)
        { $table | Get-SqlIndex }
    }

} #Get-SqlIndex

#######################
function Get-SqlStatistic
{
    param($table)
    begin
    {
        function Select-SqlStatistic ($table)
        {

            foreach ($statistic in $table.Statistics)
            {
                #Only return statistics not associated with indexes
                if ($statistic.IsFromIndexCreation -eq $false)
                {
                #Return Statistic Object
                $statistic | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
            add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $statistic.ExtendedProperties) -passthru |
            add-Member -memberType noteProperty -name XMLStatisticColumns -value $(ConvertTo-StatisticColumnXML $statistic.StatisticColumns) -passthru |
                        add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                        add-Member -memberType noteProperty -name Schema -value $table.Schema -passthru |
                        add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
                }
            }

        } #Select-SqlStatistic
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View')
            { Write-Verbose "Get-SqlStatistic $($_.Name)"
              Select-SqlStatistic $_ }
            else
            { throw 'Get-SqlStatistic:Param `$table must be a table or view object.' }

        }
    }
    end
    {
        if ($table)
        { $table | Get-SqlStatistic }
    }

} #Get-SqlStatistic

#######################
function Get-SqlCheck
{
    param($table)
    begin
    {
        function Select-SqlCheck ($table)
        {

            foreach ($Check in $table.Checks)
            {
                #Return Check Object
                $Check | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
            add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $check.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                        add-Member -memberType noteProperty -name Schema -value $table.Schema -passthru |
                        add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
            }

        } #Select-SqlCheck
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View')
            { Write-Verbose "Get-SqlCheck $($_.Name)"
              Select-SqlCheck $_ }
            else
            { throw 'Get-SqlCheck:Param `$table must be a table or view object.' }

        }
    }
    end
    {
        if ($table)
        { $table | Get-SqlCheck }
    }

} #Get-SqlCheck

#######################
function Get-SqlForeignKey
{
    param($table)
    begin
    {
        function Select-SqlForeignKey ($table)
        {

            foreach ($ForeignKey in $table.ForeignKeys)
            {
                #Return ForeignKey Object
                $ForeignKey | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
           add-Member -memberType noteProperty -name XMLExtendedProperties -value $(ConvertTo-ExtendedPropertyXML $ForeignKey.ExtendedProperties) -passthru |
                        add-Member -memberType noteProperty -name Server -value $table.parent.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $table.parent.Name -passthru |
                        add-Member -memberType noteProperty -name Schema -value $table.Schema -passthru |
                        add-Member -memberType noteProperty -name Table -value $table.Name -passthru 
            }

        } #Select-SqlForeignKey
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Table' -or $_.GetType().Name -eq 'View')
            { Write-Verbose "Get-SqlForeignKey $($_.Name)"
              Select-SqlForeignKey $_ }
            else
            { throw 'Get-SqlForeignKey:Param `$table must be a table or view object.' }

        }
    }
    end
    {
        if ($table)
        { $table | Get-SqlForeignKey }
    }

} #Get-SqlForeignKey

#######################
function Set-SqlScriptingOptions
{
    #There 77 settable scripting options at the time of this writing, rather than set the options as parameters
    #I've choosen to set them through a separate file called scriptopts.txt. Modify the scriptopts.txt to set
    #the various scriptingOptions to your liking. See the following MSDN link for a description of the settable options:
    #http://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.scriptingoptions_members.aspx

    $ScriptingOptions = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
    if (test-path $scriptRoot\scriptopts.txt)
    {
        $include = [System.IO.File]::ReadAllText("$scriptRoot\scriptopts.txt")
        invoke-expression $include
    }

    return $scriptingOptions

} #Set-SqlScriptingOptions

#######################
function Get-SqlScripter
{
    param($smo, $scriptingOptions=$(Set-SqlScriptingOptions))
    begin
    {
        function Select-SqlScripter ($smo, $scriptingOptions=$(Set-SqlScriptingOptions))
        {
            $smo.Script($scriptingOptions)

        } #Select-SqlScripter
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Namespace -like "Microsoft.SqlServer.Management.Smo*")
            { Write-Verbose "Get-SqlScripter $($_.Name)"
              Select-SqlScripter $_ $scriptingOptions }
            else
            { throw 'Get-SqlScripter:Param `$smo must be an SMO object.' }

        }
    }
    end
    {
        if ($smo)
        { $smo | Get-SqlScripter -scriptingOptions $scriptingOptions }
    }

} #Get-SqlScripter

#######################
function Get-Information_Schema.Tables
{
    param($db,$name='%')
    begin
    {
        function Select-Information_Schema.Tables ($db, $name='%')
        {
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, * FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
AND OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
AND TABLE_NAME NOT IN ('dtproperties','sysdiagrams')
AND TABLE_NAME LIKE '%$name%'
"@
            Get-SqlData -dbname $db -qry $qry
        } #Select-Information_Schema.Tables
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-Information_Schema.Tables $($_.Name)"
              Select-Information_Schema.Tables $_ -name $name }
            else
            { throw 'Get-Information_Schema.Tables:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-Information_Schema.Tables -name $name }
    }

} #Get-Information_Schema.Tables

#######################
function Get-Information_Schema.Columns
{
    param($db,$tblname='%',$colname='%')
    begin
    {
        function Select-Information_Schema.Columns ($db,$tblname='%',$colname='%')
        {
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME NOT IN ('dtproperties','sysdiagrams')
AND OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
AND TABLE_NAME LIKE '%$tblname%'
AND COLUMN_NAME LIKE '%$colname%'
"@
            Get-SqlData -dbname $db -qry $qry
        } #Select-Information_Schema.Columns
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-Information_Schema.Columns $($_.Name)"
              Select-Information_Schema.Columns $_ -tblname $tblname -colname $colname }
            else
            { throw 'Get-Information_Schema.Columns:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-Information_Schema.Columns -tblname $tblname -colname $colname }
    }

} #Get-Information_Schema.Columns

#######################
function Get-Information_Schema.Views
{
    param($db,$name='%')
    begin
    {
        function Select-Information_Schema.Views ($db, $name='%')
        {
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, * FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_NAME like '%$name%'
AND OBJECTPROPERTY(OBJECT_ID('['+TABLE_SCHEMA+'].['+TABLE_NAME+']'),'IsMSShipped') = 0
"@
            Get-SqlData -dbname $db -qry $qry
        } #Select-Information_Schema.Views
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-Information_Schema.Views $($_.Name)"
              Select-Information_Schema.Views $_ -name $name }
            else
            { throw 'Get-Information_Schema.Views:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-Information_Schema.Views -name $name }
    }

} #Get-Information_Schema.Views

#######################
function Get-Information_Schema.Routines
{
    param($db,$name='%',$text='%')
    begin
    {
        function Select-Information_Schema.Routines ($db, $name='%',$text='%')
        {
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, * FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_NAME NOT LIKE 'sp_%diagram%'
AND OBJECTPROPERTY(OBJECT_ID('['+ROUTINE_SCHEMA+'].['+ROUTINE_NAME+']'),'IsMSShipped') = 0
AND ROUTINE_NAME LIKE '%$name%'
AND ROUTINE_DEFINITION LIKE '%$text%'
"@
            Get-SqlData -dbname $db -qry $qry
        } #Select-Information_Schema.Routines
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-Information_Schema.Routines $($_.Name)"
              Select-Information_Schema.Routines $_ -name $name -text $text }
            else
            { throw 'Get-Information_Schema.Routines:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-Information_Schema.Routines -name $name -text $text }
    }

} #Get-Information_Schema.Routines

#######################
function Get-SysDatabases
{
    param($sqlserver=$(throw 'Get-SysDatabases:`$sqlserver is required.'),$name='%')

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SysDatabases:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SysDatabases $($server.Name)"

    $db = Get-SqlDatabase $server 'master'
$qry = @"
SELECT SERVERPROPERTY('ServerName') AS Server, name FROM sysdatabases
WHERE name LIKE '%$name%'
"@
    Get-SqlData -dbname $db -qry $qry

} #Get-SysDatabases

#######################
function Get-SqlDataFile
{
    param($db)
    begin
    {
        function Select-SqlDataFile ($db)
        {

            foreach ($dataFile in $db.FileGroups | % {$_.Files})
            {
                #Return DataFile Object
                $dataFile | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                        add-Member -memberType noteProperty -name FileGroup -value $dataFile.parent.Name -passthru |
                        add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
            }

        } #Select-SqlDataFile
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlDataFile $($_.Name)"
              Select-SqlDataFile $_ }
            else
            { throw 'Get-SqlDataFile:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlDataFile }
    }

} #Get-SqlDataFile

#######################
function Get-SqlLogFile
{
    param($db)
    begin
    {
        function Select-SqlLogFile ($db)
        {

            foreach ($logFile in $db.LogFiles)
            {
                #Return LogFile Object
                $LogFile | add-Member -memberType noteProperty -name timestamp -value $(Get-SessionTimeStamp) -passthru |
                        add-Member -memberType noteProperty -name Server -value $db.parent.Name -passthru |
                        add-Member -memberType noteProperty -name dbname -value $db.Name -passthru
            }

        } #Select-SqlLogFile
    }
    process
    {
        if ($_)
        {
            if ($_.GetType().Name -eq 'Database')
            { Write-Verbose "Get-SqlLogFile $($_.Name)"
              Select-SqlLogFile $_ }
            else
            { throw 'Get-SqlLogFile:Param `$db must be a database object.' }

        }
    }
    end
    {
        if ($db)
        { $db | Get-SqlLogFile }
    }

} #Get-SqlLogFile

#######################
function Get-SqlVersion
{
    param($sqlserver=$(throw 'Get-SqlVersion:`$sqlserver is required.'))

    switch ($sqlserver.GetType().Name)
    {
        'String' { $server = Get-SqlServer $sqlserver }
        'Server' { $server = $sqlserver }
        default { throw 'Get-SqlVersion:Param `$sqlserver must be a String or Server object.' }
    }

    Write-Verbose "Get-SqlVersion $($server.Name)"

    $server.information | Select @{name='Server';Expression={$server.Name}}, Version

}#Get-SqlVersion

#######################
function Get-SqlPort
{
    param([string]$sqlserver=$(throw 'Get-SqlPort:`$sqlserver is required.'))

    #This can be done using Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer,
    #but it has some severe limitations -- only support in 2005 or higher and must have a SQL 
    #instance installed locally, so back SQLDMO instead of SMO for this one

    $dmoServer = New-Object -comobject "SQLDMO.SQLServer"
    $dmoServer.loginsecure = $true
    $dmoServer.connect($sqlserver)
    $tcpPort = $dmoServer.registry.tcpport
    $dmoServer.close() 
    
    new-object psobject |
    add-member -pass NoteProperty Server $sqlserver |
    add-member -pass NoteProperty TcpPort $tcpPort

}#Get-SqlPort

#######################
function ConvertTo-ExtendedPropertyXML
{
    param($extendedProperty=$(throw 'ConvertTo-SqlExtendedPropertyXML:`$extendedProperty is required.'))

    Write-Verbose "ConvertTo-SqlExtendedPropertyXML"
    
    foreach ($xp in $extendedProperty)
    {
            if ($xp.Name -ne $null -and $xp.Value -ne $null)
            { $xpXML += [string] "<ExtendedProperty Name=`"" + $xp.Name + "`" Value=`"" + $xp.Value + "`"></ExtendedProperty>" }
    }

    Return $xpXML

} #ConvertTo-ExtendedPropertyXML

#######################
function Get-Sql
{
    param ($computer=$(throw 'Get-Sql:`$computer is required.'))

    if((get-wmiobject win32_pingstatus -Filter "address='$computer'").protocoladdress) 
    {
        Get-WmiObject win32_service -computer $computer |
Where {($_.Name -Like "MSSQL*" -or $_.Name -Like "SQLAgent*" -or $_.Name -Like "SQLServer*" -or $_.Name -eq 'MSDTC') -and $_.Name -ne 'MSSQLServerADHelper'} | Select SystemName, Name, State, StartName | ft
    }
} #Get-Sql

#######################
function ConvertTo-StatisticColumnXML
{
    param($statisticColumn=$(throw 'ConvertTo-SqlStatisticColumnXML:`$statisticColumn is required.'))

    Write-Verbose "ConvertTo-SqlStatisticColumnXML"
    
    foreach ($wa in $statisticColumn)
    {
        $waXML += [string] "<StatisticColumn Name=`"" + $wa.Name + "`"</StatisticColumn>"
    }

    Return $waXML

} #ConvertTo-StatisticColumnXML

#######################
function ConvertTo-IndexedColumnXML
{
    param($indexedColumn=$(throw 'ConvertTo-SqlIndexedColumnXML:`$indexedColumn is required.'))

    Write-Verbose "ConvertTo-SqlIndexedColumnXML"
    
    foreach ($ix in $indexedColumn)
    {
$ixXML += [string] "<IndexedColumn Name=`"" + $ix.Name + "`" Descending=`"" +$($ix.Descending.ToString()) + "`" IsComputed=`"" + $($ix.IsComputed.ToString())  + "`"</IndexedColumn>"
    }

    Return $ixXML

} #ConvertTo-IndexedColumnXML

