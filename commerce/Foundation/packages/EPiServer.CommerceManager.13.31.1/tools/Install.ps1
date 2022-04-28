param($installPath, $toolsPath, $package, $project)

Import-Module (Join-Path $toolsPath "Get-ConfigPath.psm1")
Import-Module (Join-Path $toolsPath "Get-Config.psm1")
Import-Module (Join-Path $toolsPath "Update-AssemblyBinding.psm1")
Import-Module (Join-Path $toolsPath "Expand-Zip.psm1")
Import-Module (join-path $toolsPath  "Get-PackagesToolPath.psm1")
Import-Module (join-path $toolsPath  "Get-EPiServerCommerceConnectionString.psm1")
Import-Module (join-path $toolsPath  "Copy-EcfConfigsIfNotExist.psm1")
Import-Module (join-path $toolsPath  "Set-ConnectionStringUsingProjectsInSameSolution.psm1")
Import-Module (join-path $toolsPath  "Update-CommerceManagerLink.psm1")
Import-Module (join-path $toolsPath  "Set-CommerceManagerSearchIndexBasePath.psm1")
Import-Module (join-path $toolsPath  "Set-CommerceManagerSharedNotificationTemplatesPath.psm1")

Function RemoveInvalidHttpModulePreCondition([System.Xml.XmlDocument]$config)
{
	$invalidModules = $config.SelectNodes("/configuration/system.web/httpModules/add[@preCondition]")
	foreach ($module in $invalidModules)
	{
		Write-Host "Removing invalid preCondition attribute of httpModule".
		$module.RemoveAttribute("preCondition") | Out-Null
	}
}

Function RemoveMediachaseCmsAssembly([System.Xml.XmlDocument]$config)
{    
    $ns = New-Object Xml.XmlNamespaceManager $config.NameTable
    $ns.AddNamespace( "x", "urn:schemas-microsoft-com:asm.v1" )
    $xpath = "/configuration/runtime/x:assemblyBinding/x:dependentAssembly[x:assemblyIdentity/@name='Mediachase.Cms']"
    $mediachaseCmsAssembly = $config.SelectSingleNode($xpath, $ns)
    if($mediachaseCmsAssembly -ne $null)
    {
        Write-Host "Removing Mediachase Cms Assembly"
        $mediachaseCmsAssembly.ParentNode.RemoveChild($mediachaseCmsAssembly);
    }    	
}

Function RemoveObsoleteFiles([String] $sitePath)
{
	#Remove obsolete files relate to Mediachase.Cms		
	$mediachaseCmsDllPath = Join-Path $sitePath "bin\Mediachase.Cms.*";
	if(Test-Path($mediachaseCmsDllPath)) {
		Write-Host "Removing file $mediachaseCmsDllPath"
		Remove-Item $mediachaseCmsDllPath
	}		
	
	$mediachaseCmsContentFolder = Join-Path $sitePath "Apps\Content";
	if(Test-Path($mediachaseCmsContentFolder)) {
		Write-Host "Removing folder $mediachaseCmsContentFolder"
		Remove-Item $mediachaseCmsContentFolder -Recurse
	}		
}

Function RemoveAssetFolder([String] $sitePath)
{ 
    $assetFolder = Join-Path $sitePath "Apps\Asset";
    if(Test-Path($assetFolder)) {
        Write-Host "Removing folder $assetFolder"
        Remove-Item $assetFolder -Recurse
    }       
}

#Get the Framework package
$frameworkPackage = Get-package -ProjectName $project.ProjectName | where-object { $_.id -eq "EPiServer.Framework"} | Sort-Object -Property Version -Descending | select-object -first 1
$frameWorkToolPath = Get-PackagesToolPath $installPath "EPiServer.Framework" $frameworkPackage.Version
$deployEXEPath =  join-Path ($frameWorkToolPath) "epideploy.exe"

$projectFilePath = Get-ChildItem $project.Fullname
$sitePath = $projectFilePath.Directory.FullName

#copy EPiServerLog.config without overwriting
$episerverLogConfigPath =[System.IO.Path]::Combine($installPath, "tools\EPiServerLog.config")
if (!(Test-Path (Join-Path $sitePath "EPiServerLog.config")))
{
	Copy-Item $episerverLogConfigPath -Destination $sitePath
}

$projectFile = Get-Item $project.FullName
$destination = $projectFile.Directory.FullName

#add/update binding redirects for assemblies in the current package
$commerceConfigBaselinePath =[System.IO.Path]::Combine($installPath, "tools\webconfig-baseline.config")
$commerceConfigUpdatePath =[System.IO.Path]::Combine($installPath, "tools\webconfig-update.config")
$configPath = Get-ConfigPath $project
if ($configPath -eq $null)
{
	Write-Host "Unable to find a configuration file, binding redirect not configured."
}
else
{
    $config = Get-Config $configPath
    Update-AssemblyBinding $config $installPath | Out-Null

    #Also remove invalid preCondition attribute added by 7.5 install/upgrade
    RemoveInvalidHttpModulePreCondition $config
    #Remove Mediachase.cms dependentAssembly from webconfig of upgrade site
    RemoveMediachaseCmsAssembly $config
    $config.Save($configPath)

    RemoveObsoleteFiles $sitePath

    RemoveAssetFolder $sitePath
    
    ## Install baseline if not already added
    $epiConnection = Get-EPiServerCommerceConnectionString($configPath)
    if ($epiConnection -eq $null)
    {
        Write-Host "Adding Commerce baseline configuration"
        & $deployEXEPath -s $sitePath -a config -p $commerceConfigBaselinePath
        
        # get the active solution
        $solution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])
        
        $config = Get-Config $configPath

        # Modify ConnectionString if version only supports LocalDB\v11.0
        $vsVersion = [System.Version]::Parse($project.DTE.Version)
        $localDBDataSource = if ($vsVersion.Major -lt 14) { "(LocalDb)\v11.0" } else { "(LocalDb)\MSSQLLocalDB" }

        Set-CommerceManagerSharedNotificationTemplatesPath $config $destination
        Set-ConnectionStringUsingProjectsInSameSolution $solution $config "EcfSqlConnection" $localDBDataSource
        Set-ConnectionStringUsingProjectsInSameSolution $solution $config "EPiServerDB" $localDBDataSource
        $config.Save($configPath)
        
        Update-CommerceManagerLink $solution $project

        #Update search config
        $searchConfigPath = Join-Path $toolsPath "Configs\Mediachase.Search.Config"
        $searchIndexBasePath = "[appDataPath]\Search\ECApplication\"
        $searchConfig = Get-Config $searchConfigPath
        Set-CommerceManagerSearchIndexBasePath $searchConfig $searchIndexBasePath
        $searchConfig.Save($searchConfigPath)
    }
    Write-Host "Adding Commerce update configuration"
    & $deployEXEPath -s $sitePath -a config -p $commerceConfigUpdatePath
}

Copy-EcfConfigsIfNotExist $project $toolsPath $sitePath

$marketingFolder = join-path $sitePath "Apps\Marketing"
Remove-Item $marketingFolder -Recurse -ErrorAction Ignore

$zipFilePath = join-path $toolsPath "EPiServer.CommerceManager.zip"
Expand-Zip $zipFilePath $destination
# SIG # Begin signature block
# MIIOLQYJKoZIhvcNAQcCoIIOHjCCDhoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUU10nX29vLippvNGdeE3sx3BJ
# /p+gggtkMIIFZzCCBE+gAwIBAgIRAJgvkmklxJsCm+Wj934zo1UwDQYJKoZIhvcN
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
# BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRVFc+BCgzHGmhqlOXfjY7yev5nZjAN
# BgkqhkiG9w0BAQEFAASCAQBSwkDf+1NzSUoNehdfoVrmZ6XvI+5oJL2VuPVOwF2s
# 31b8EyOLfIx5k6A7+Ogs8PKa3fTGkh5DH+Y3QusLTRmCeXMunzpSSIj4cxNQTZuE
# N/LaUDPiG+MPXoSqh1hQg68An4Zil7TRczPz8sXs/WVHEnPHcSSYV8Op/ZjcinZ6
# XowIZTFLmZ6ETkcLEmGIgfH8tXadmPThovUIy+D4YiQo3dL/xW9pifofdOgmAY5T
# qQVOK3InXd/UgEbj7QViHk9PDsgiJ9y2wLY3AlS39uvHDmAGgJ9LKNlkptESPc8/
# +Um4huk+5tOub42q/LORIlvpRgHTR6VxuteflortT32u
# SIG # End signature block
