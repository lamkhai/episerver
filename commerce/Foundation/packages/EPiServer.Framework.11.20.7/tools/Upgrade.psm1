#$installPath is the path to the folder where the package is installed
param([string]$installPath)

#	The Update-EPiDataBase and Update-EPiConfig uses by default EPiServerDB connection string name and $package\tools\epiupdates path 
#	to find sql files and transformations file but if it needed to customize the connectionStringname 
#	then a settings.config file can be created (e.g. "settings.config" file under the $package\tools\settings.config).
#	The format of the settings file is like 
#		<settings>
#			<connectionStringName/>
#		</settings>
$setting = "settings.config"
$exportRootPackageName = "EPiUpdatePackage"
$frameworkPackageId = "EPiServer.Framework"
$tools_id = "tools"
$runBatFile = "update.bat"
$updatesPattern = "epiupdates*"
$defaultCommandTimeout = "1800"
$nl = [Environment]::NewLine

#	This CommandLet update DB 
#	It collects all scripts by default under $packagepath\tools\epiupdates
#   By default uses EPiServerDB connection string name and if the connection string name is different from default (EPiServerDB)
#	then it needs a settings.config (See setting for more information)
Function Update-EPiDatabase
{
<#
	.Description
		Update database by deploying updated sql files that can be found under nuget packages. The pattern to find sql files is nugetpackage.id.version\tools\epiupdates*.sql.
		By default uses EPiServerDB connection string name and if the connection string name is different from default (EPiServerDB)
		then it needs a settings.config in the epiupdates folder as: 
		<settings>
			<connectionStringName>MyConnectionString</connectionStringName>
		</settings>
    .SYNOPSIS 
		Update all Epi database
    .EXAMPLE
		Update-EPiDatabase
		Update-EPiDatabase -commandTimeout 60

#>
	[CmdletBinding()]
    param ([string]$commandTimeout = $defaultCommandTimeout)
	Update "sql" -Verbose:(GetVerboseFlag($PSBoundParameters)) $commandTimeout
}

#	This CommandLet update web config 
#	It collects all transformation config by default under $packagepath\tools\epiupdates
Function Update-EPiConfig
{
<#
	.Description
		Update config file by finding transform config files that can be found under nuget packages. The pattern to find transform config files is nugetpackage.id.version\tools\epiupdates*.config.
    .SYNOPSIS 
		Update config file.
    .EXAMPLE
		Update-EPiConfig
#>
	[CmdletBinding()]
    param ( )

	Update "config" -Verbose:($PSBoundParameters["Verbose"].IsPresent -eq $true)
}

#	This command can be used in the visual studio environment
#	Try to find all packages that related to the project that needs to be updated  
#   Create export package that can be used to update to the site
Function Export-EPiUpdates 
{
 <#
	.Description
		Export updated sql and transform config files that can be found under nuget packages. The pattern to find sql and transform config files is nugetpackage.id.version\tools\epiupdates*.
		The transform config files and sql files are saved in the EPiUpdatePackage folder. In the EPiUpdatePackage folder is uppdate.bat file that can be run on the site.
    .SYNOPSIS 
		Export updated sql files into EPiUpdatePackage.
    .EXAMPLE
		Export-EPiUpdates
		Export-EPiUpdates commandTimeout:30
#>
	[CmdletBinding()]
    param ($action = "sql", [string]$commandTimeout =$defaultCommandTimeout)
	
	$params = Getparams $installPath
	$packages = $params["packages"]
	$sitePath = $params["sitePath"]
	ExportPackages  $action $params["sitePath"]  $params["packagePath"] $packages $commandTimeout -Verbose:(GetVerboseFlag($PSBoundParameters))
}


Function Initialize-EPiDatabase
{
<#
	.Description
		Deploy all sql schema that can be found under nuget package. The pattern to find sql files is nugetpackage.id.version\tools\nugetpackage.id.sql.
		By default uses EPiServerDB connection string name and if the connection string name is different from default (EPiServerDB)
		then it needs a settings.config as: 
		<settings>
			<connectionStringName>MyConnectionString</connectionStringName>
		</settings>
    .SYNOPSIS 
		Deploy epi database schema.
    .EXAMPLE
		Initialize-EPiDatabase
		This command deploy all epi database schema that can be found in the nuget packages. 
	.EXAMPLE
		Initialize-EPiDatabase -sqlFilePattern:c:\data\mysql.sql -connectionString:MyConnectionString -commandTimeout:30
		This command deploy mysql.sql into database by using MyConnectionString. The -connectionString can be both connection string name inthe application web config or connection string.
#>
	[CmdletBinding()]
    param ([string]$sqlFilePattern, [string]$connectionString,[bool]$validation = $false, [string]$commandTimeout = $defaultCommandTimeout)

	$params = Getparams $installPath
	$packages = $params["packages"]
	$packagePath = $params["packagePath"]
	$sitePath = $params["sitePath"]

	$epideploy = GetDeployExe $packagePath $packages  
	if (!$epideploy)
	{
		throw "There is no EPiServer.Framework nuget package installed"
	}

	if (!$connectionString -and !$sqlFilePattern) 
	{
		# deploy all products
		DeploySqlFiles $epideploy $packages $packagePath $sitePath $validation $commandTimeout
		return
	}

	if (!$connectionString)
	{
		$connectionString = "EPiServerDB"
	}

	if ($sqlFilePattern)
	{
		DeploySqlFile $epideploy $connectionString $sqlFilePattern $sitePath $validation $commandTimeout
		return;	
	}
}

#	This command can be used in the visual studio environment
#	Try to find all packages that related to the project that has update  
#	Find out setting for each package
#   Call epideploy with -a config for each package
Function Update 
{
 	[CmdletBinding()]
    param ($action, [string]$commandTimeout = $defaultCommandTimeout)

	$params = Getparams $installPath
	$packages = $params["packages"]
	$sitePath = $params["sitePath"]
 
	Update-Packages $action $params["sitePath"] $params["packagePath"] $packages $commandTimeout -Verbose:(GetVerboseFlag($PSBoundParameters))
}


#	This command can be used in the visual studio environment
#	Export all packages that have epiupdates folder under tools path and
#	Create a bat (update.bat) that can be used to call on site
Function ExportPackages
{
 	[CmdletBinding()]
    param ($action, $sitePath, $packagesPath, $packages, $commandTimeout = $defaultCommandTimeout)

	CreateRootPackage  $exportRootPackageName
	$batFile  = AddUsage 
	$packages |foreach-object -process {
			$packageName = $_.id + "." + $_.version
			$packagePath = join-path $packagesPath $packageName
			$packageToolsPath = join-Path $packagePath $tools_id
			if (test-Path $packageToolsPath){
				$updatePackages = Get-ChildItem -path $packageToolsPath -Filter $updatesPattern
				if($updatePackages -ne $null) {
					foreach($p in $updatePackages) {
						$packageSetting = Get-PackageSetting $p.FullName
						ExportPackage $packagePath $packageName $p $packageSetting
						$des = join-path $packageName $p
						AddDeployCommand $action $batFile  $des $packageSetting $commandTimeout
					}
				}
			}
		}
	Add-Content $batFile.FullName ") $($nl)"
	ExportFrameworkTools $packagesPath $packages
	Write-Verbose "A $($runBatFile) file has been created in the $($exportRootPackageName)"
}

Function AddDeployCommand($action, $batFile,  $des, $packageSetting, $commandTimeout = $defaultCommandTimeout)
{
	if ($action -match "config")
	{
		$command =  "epideploy.exe  -a config -s ""%~f1""  -p ""$($des)\*"" -c ""$($packageSetting["connectionStringName"])"""
		Add-Content $batFile.FullName $command
	}
	if ($action -match "sql")
	{
		$command =  "epideploy.exe  -a sql -s ""%~f1""  -p ""$($des)\*""  -m ""$($commandTimeout)""  -c ""$($packageSetting["connectionStringName"])"""
		Add-Content $batFile.FullName $command
	}
}

Function AddUsage ()
{
	$content = "@echo off  $($nl) if '%1' ==''  ($($nl) echo  USAGE: %0  web application path ""[..\episerversitepath or c:\episerversitepath]"" $($nl)	) else ($($nl)" 
	New-Item (join-path $exportRootPackageName $runBatFile) -type file -force -value $content
}

Function CreateRootPackage ($deployPackagePath)
{
	if (test-path $deployPackagePath)
	{
		remove-Item -path $deployPackagePath -Recurse
	}
	$directory = New-Item -ItemType directory -Path $deployPackagePath
	Write-Host "An Export package is created $($directory.Fullname)"
}

Function ExportPackage($packagpath, $packageName, $updatePackage, $setting)
{
	$packageRootPath = join-path (join-Path $exportRootPackageName  $packageName) $updatePackage.Name
	write-Host "Exporting  $($updatePackage.Name) into $($packageRootPath)"
	$destinationupdatePath  = join-Path $packageRootPath  $package.Name
	copy-Item $updatePackage.FullName  -Destination $destinationupdatePath  -Recurse
	if ($setting["settingPath"])
	{
		copy-Item $setting["settingPath"]  -Destination $packageRootPath 
	}
}

Function GetEpiFrameworkFromPackages($packages)
{
	return (GetPackage $packages $frameworkPackageId)
}

Function DeploySqlFiles()
{
 	[CmdletBinding()]
	 param ($epideploy, $packages, $packagesPath, $sitePath, [bool]$validation = $false, [string]$commandTimeout = $defaultCommandTimeout)

	 $packages | foreach-object -process {
			$packageName = $_.id + "." + $_.version
			$packagePath = join-path $packagesPath $packageName
			$sqldatabaseFile = join-Path (join-Path $packagePath $tools_id) ( $_.id + ".sql")
			if (test-Path $sqldatabaseFile){
				$packageSetting = Get-PackageSetting $packagePath
				DeploySqlFile $epideploy $packageSetting["connectionStringName"] $sqldatabaseFile  $sitePath  $validation $commandTimeout
			}
		}
}

Function DeploySqlFile()
{
	[CmdletBinding()]
	param ($epideploy, [string]$connectionString, [string]$sqlFilePattern, [string]$sitePath, [bool]$validation = $false, [string]$commandTimeout = $defaultCommandTimeout)

	if ((($connectionString -Match "Data Source=") -eq $true) -or (($connectionString -Match "AttachDbFilename=") -eq $true) -or (($connectionString -Match "Initial Catalog=") -eq $true)) 
	{
		&$epideploy  -a "sql" -s $sitePath  -p $sqlFilePattern -b  $connectionString  -v $validation -d (GetVerboseFlag($PSBoundParameters)) -m $commandTimeout
	}
	else
	{
		&$epideploy  -a "sql" -s $sitePath  -p $sqlFilePattern -c  $connectionString  -v $validation -d (GetVerboseFlag($PSBoundParameters))  -m $commandTimeout
	}
}

Function GetPackage($packages, $packageid)
{
	$package = $packages | where-object  {$_.id -eq $packageid} | Sort-Object -Property version -Descending
	if ($package -ne $null)
	{
		return $package.id + "." + $package.version 
	}
}

Function ExportFrameworkTools($packagePath, $packages)
{
	$epiDeployPath = GetDeployExe $packagesPath  $packages
	copy-Item $epiDeployPath  -Destination $exportRootPackageName
}
 
Function Update-Packages
{
	[CmdletBinding()]
	param($action, $sitePath, $packagesPath, $packages, [string]$commandTimeout = $defaultCommandTimeout)
	$epiDeployPath = GetDeployExe $packagesPath  $packages
	$packages | foreach-object -process {
				$packagePath = join-path $packagesPath ($_.id + "." + $_.version)
				$packageToolsPath = join-Path $packagePath $tools_id
				if (test-Path $packageToolsPath){
					$updatePackages = Get-ChildItem -path $packageToolsPath -Filter $updatesPattern
					if($updatePackages -ne $null) {
						foreach($p in $updatePackages) {
							$settings = Get-PackageSetting $p.FullName
							Update-Package $p.FullName $action $sitePath $epiDeployPath  $settings  -Verbose:(GetVerboseFlag($PSBoundParameters)) $commandTimeout
						}
					}
				}
			}
}
 
Function Update-Package  
  {
	[CmdletBinding()]
    Param ($updatePath, $action, $sitePath, $epiDeployPath, $settings, [string]$commandTimeout = $defaultCommandTimeout)
	
    if (test-Path $updatePath)
	{
        Write-Verbose "$epiDeployPath  -a $action -s $sitePath  -p $($updatePath)\* -c $($settings["connectionStringName"]) "
		&$epiDeployPath  -a $action -s $sitePath  -p $updatePath\* -c $settings["connectionStringName"]  -d (GetVerboseFlag($PSBoundParameters)) -m $commandTimeout
	}
}

#	Find out EPiDeploy from frameworkpackage
Function GetDeployExe($packagesPath, $packages)
 {
	$frameWorkPackage = $packages |  where-object  {$_.id -eq $frameworkPackageId} | Sort-Object -Property version -Descending
	$frameWorkPackagePath = join-Path $packagesPath ($frameWorkPackage.id + "." + $frameWorkPackage.version)
	join-Path  $frameWorkPackagePath "tools\epideploy.exe"
 }

#	Find "settings.config" condig file under the package  
#	The format of the settings file is like 
#		<settings>
#			<connectionStringName/>
#		</settings>
Function Get-PackageSetting($packagePath)
{
	$packageSettings = Get-ChildItem -Recurse $packagePath -Include $setting | select -first 1
	if ($packageSettings -ne $null)
	{
		$xml = [xml](gc $packageSettings)
		if ($xml.settings.SelectSingleNode("connectionStringName") -eq $null)
		{
			$connectionStringName = $xml.CreateElement("connectionStringName")
			$xml.DocumentElement.AppendChild($connectionStringName)
		}
		if ([String]::IsNullOrEmpty($xml.settings.connectionStringName))
		{
			$xml.settings.connectionStringName  = "EPiServerDB"
		}
	}
	else
	{
		$xml = [xml] "<settings><connectionStringName>EPiServerDB</connectionStringName></settings>"
	}
	 @{"connectionStringName" = $($xml.settings.connectionStringName);"settingPath" = $packageSettings.FullName}
}

# Get base params
Function GetParams($installPath)
{
	#Get The current Project
	$project  = GetProject
	$projectPath = Get-ChildItem $project.Fullname
	#site path
	$sitePath = $projectPath.Directory.FullName
	#Get project packages 
	$packages = GetPackage($project.Name)
 
	if ($installPath)
	{
		#path to packages 
		$packagePath = (Get-Item -path $installPath -ErrorAction:SilentlyContinue).Parent.FullName
	}

	if (!$packagePath -or (test-path $packagePath) -eq $false)
	{
		throw "There is no 'nuget packages' directory"
	}

	@{"project" = $project; "packages" = $packages; "sitePath" = $sitePath; "packagePath" = $packagePath}
}

Function GetVerboseFlag ($parameters)
{
	($parameters["Verbose"].IsPresent -eq $true)
}

Function GetProject()
{
	Get-Project
}

Function GetPackage($projectName)
{
	Get-Package -ProjectName  $projectName
}
#Exported functions are Update-EPiDataBase Update-EPiConfig
export-modulemember -function  Update-EPiDatabase, Update-EPiConfig, Export-EPiUpdates, Initialize-EPiDatabase
# SIG # Begin signature block
# MIIOLQYJKoZIhvcNAQcCoIIOHjCCDhoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDEWCEA304Ia8ttLRv1JxVmNT
# wiugggtkMIIFZzCCBE+gAwIBAgIRAJgvkmklxJsCm+Wj934zo1UwDQYJKoZIhvcN
# AQELBQAwfDELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3Rl
# cjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSQw
# IgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNpZ25pbmcgQ0EwHhcNMTkwNTIyMDAw
# MDAwWhcNMjIwNTIxMjM1OTU5WjCBtTELMAkGA1UEBhMCU0UxDjAMBgNVBBEMBTEx
# MTU2MQ8wDQYDVQQIDAZTd2VkZW4xEjAQBgNVBAcMCVN0b2NraG9sbTEaMBgGA1UE
# CQwRUmVnZXJpbmdzZ2F0YW4gNjcxETAPBgNVBBIMCEJveCA3MDA3MRUwEwYDVQQK
# DAxFcGlzZXJ2ZXIgQUIxFDASBgNVBAsMC0VuZ2luZWVyaW5nMRUwEwYDVQQDDAxF
# cGlzZXJ2ZXIgQUIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCzINB4
# kpvfTyclYG7iRSjY0covfFRSheJU1QOBl314IschK8/iEmh3F648RFtQpB+eflYf
# iw4wSDKidpjgvtnfw4fTsGSDWssTsVfoLKhh+xfu6P//hAFs7ZER/RLcNiAXncJU
# 3mb2YrSnsOoGFmcDKu8DOTXae6Gl8PBODF74jmOi6H9/dMVlstwYVkbvSN+yYVOL
# 5K58YOHD2fLGWG9DhMP59JrydmNsI8kVEGGV7VB8gHtnOZX5g6XRZBX+0BDwfRK5
# JtfTLxekbwL/YZGnkGzZxQCmyXKee3sKQ3RDM0fgqy5MI0mYV+RzN/fwKvzufHuH
# wn0iKLQWEpw2XI63AgMBAAGjggGoMIIBpDAfBgNVHSMEGDAWgBQO4TqoUzox1Yq+
# wbutZxoDha00DjAdBgNVHQ4EFgQU/BUJomwrLBnNXS6piwNCZONBLiQwDgYDVR0P
# AQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJ
# YIZIAYb4QgEBBAQDAgQQMEAGA1UdIAQ5MDcwNQYMKwYBBAGyMQECAQMCMCUwIwYI
# KwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMEMGA1UdHwQ8MDowOKA2
# oDSGMmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1JTQUNvZGVTaWduaW5n
# Q0EuY3JsMHMGCCsGAQUFBwEBBGcwZTA+BggrBgEFBQcwAoYyaHR0cDovL2NydC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUlNBQ29kZVNpZ25pbmdDQS5jcnQwIwYIKwYBBQUH
# MAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMCAGA1UdEQQZMBeBFXN1cHBvcnRA
# ZXBpc2VydmVyLmNvbTANBgkqhkiG9w0BAQsFAAOCAQEAhL8vG/WPbjHDEoAuh+Kk
# q2NFnrQDK0MEyHmuCoWjQwP+guYcHw7/R8jrqTJARYDlMdp8bx9DD8tcgAuhB9sL
# ZPlQiGyGAIQzyizHSdrPFKgo2yABSnwgodYpvlbVJEJxQ1ijbfny3ypPQnwHdpYU
# tDZ1BJks4/P8+EMETtOmrMi9otFY3YnFEE70VRBKFagAb1IrAoYCTMqfskR4uUm1
# w6En4miFfx8fiSC669pwQENAo+Slx1tA5wQBchql0wutohSs9k6DRtudA5PhVl9c
# wW0EoXPZ3prh1/x2JmFhIPDP/WKKyGMAwxBTRY7qWwzz+u3AO72rrl6rLstk3HV6
# PTCCBfUwggPdoAMCAQICEB2iSDBvmyYY0ILgln0z02owDQYJKoZIhvcNAQEMBQAw
# gYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtK
# ZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYD
# VQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTE4
# MTEwMjAwMDAwMFoXDTMwMTIzMTIzNTk1OVowfDELMAkGA1UEBhMCR0IxGzAZBgNV
# BAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UE
# ChMPU2VjdGlnbyBMaW1pdGVkMSQwIgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNp
# Z25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCGIo0yhXoY
# n0nwli9jCB4t3HyfFM/jJrYlZilAhlRGdDFixRDtsocnppnLlTDAVvWkdcapDlBi
# pVGREGrgS2Ku/fD4GKyn/+4uMyD6DBmJqGx7rQDDYaHcaWVtH24nlteXUYam9Cfl
# fGqLlR5bYNV+1xaSnAAvaPeX7Wpyvjg7Y96Pv25MQV0SIAhZ6DnNj9LWzwa0VwW2
# TqE+V2sfmLzEYtYbC43HZhtKn52BxHJAteJf7wtF/6POF6YtVbC3sLxUap28jVZT
# xvC6eVBJLPcDuf4vZTXyIuosB69G2flGHNyMfHEo8/6nxhTdVZFuihEN3wYklX0P
# p6F8OtqGNWHTAgMBAAGjggFkMIIBYDAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dib
# wJ3ysgNmyzAdBgNVHQ4EFgQUDuE6qFM6MdWKvsG7rWcaA4WtNA4wDgYDVR0PAQH/
# BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0lBBYwFAYIKwYBBQUHAwMG
# CCsGAQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BBhj9o
# dHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNhdGlv
# bkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNodHRw
# Oi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRkVHJ1c3RDQS5jcnQw
# JQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcN
# AQEMBQADggIBAE1jUO1HNEphpNveaiqMm/EAAB4dYns61zLC9rPgY7P7YQCImhtt
# EAcET7646ol4IusPRuzzRl5ARokS9At3WpwqQTr81vTr5/cVlTPDoYMot94v5JT3
# hTODLUpASL+awk9KsY8k9LOBN9O3ZLCmI2pZaFJCX/8E6+F0ZXkI9amT3mtxQJmW
# unjxucjiwwgWsatjWsgVgG10Xkp1fqW4w2y1z99KeYdcx0BNYzX2MNPPtQoOCwR/
# oEuuu6Ol0IQAkz5TXTSlADVpbL6fICUQDRn7UJBhvjmPeo5N9p8OHv4HURJmgyYZ
# SJXOSsnBf/M6BZv5b9+If8AjntIeQ3pFMcGcTanwWbJZGehqjSkEAnd8S0vNcL46
# slVaeD68u28DECV3FTSK+TbMQ5Lkuk/xYpMoJVcp+1EZx6ElQGqEV8aynbG8HAra
# fGd+fS7pKEwYfsR7MUFxmksp7As9V1DSyt39ngVR5UR43QHesXWYDVQk/fBO4+L4
# g71yuss9Ou7wXheSaG3IYfmm8SoKC6W59J7umDIFhZ7r+YMp08Ysfb06dy6LN0Kg
# aoLtO0qqlBCk4Q34F8W2WnkzGJLjtXX4oemOCiUe5B7xn1qHI/+fpFGe+zmAEc3b
# tcSnqIBv5VPU4OOiwtJbGvoyJi1qV3AcPKRYLqPzW0sH3DJZ84enGm1YMYICMzCC
# Ai8CAQEwgZEwfDELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hl
# c3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSQwIgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNpZ25pbmcgQ0ECEQCYL5JpJcSb
# Apvlo/d+M6NVMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBR3qrHMtVISKDQktLu4rG+YSJowxjAN
# BgkqhkiG9w0BAQEFAASCAQCJcrimTr+c6bjdKz+g47v+EUt03stREE4soYyqDNPp
# 4ULirrc5rqxGx7fLQdAr1YLT29n88POU9EPnvAHVN58yUGZTVz2qCqAKy+DxexVC
# /MDXi/RJQjjmXOo4De4b5CN8Hze2rKiuYVETOnJDU5b3IZLMK/7aRrdRH2pePQg1
# WtVoWd+z0cWxdLPQpUhlzq/7LR80bxWGjHqWyjH0dMZXKnM1CQNIPeNeBQ5ddt75
# XbMG1GWh6juJ5/2s28l6P0J5GZqQXVC9ix56TfS01VYzpxWXwUmpJaeyGrb/yZWz
# jUO3gKo11Ko7aSAd1jY6c98K8x+tzuwAK4C4XBrsDBUS
# SIG # End signature block
