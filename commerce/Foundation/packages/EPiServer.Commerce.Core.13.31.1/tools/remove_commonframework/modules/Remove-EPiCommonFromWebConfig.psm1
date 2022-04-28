function Remove-EPiCommonFromWebConfig {

	param ([xml]$webConfig)

	$modified = $false

	$commonSectionDeclaration = $webConfig.SelectSingleNode("/configuration/configSections/section[@name='episerver.common']")
	if ($commonSectionDeclaration -ne $null) {
		Write-Host "Removing episerver.common config section declaration."
		$commonSectionDeclaration.ParentNode.RemoveChild($commonSectionDeclaration) | Out-Null
		$modified = $true
	}

	$commonSection = $webConfig.SelectSingleNode("/configuration/episerver.common")
	if ($commonSection -ne $null) {
		Write-Host "Removing episerver.common config section."
		$commonSection.ParentNode.RemoveChild($commonSection) | Out-Null
		$modified = $true
	}

	$nhibernateSectionDeclaration = $webConfig.SelectSingleNode("/configuration/configSections/section[@name='nhibernate']")
	if ($nhibernateSectionDeclaration -ne $null) {
		Write-Host "Removing nhibernate config section declaration."
		$nhibernateSectionDeclaration.ParentNode.RemoveChild($nhibernateSectionDeclaration) | Out-Null
		$modified = $true
	}

	$nhibernateSection = $webConfig.SelectSingleNode("/configuration/nhibernate")
	if ($nhibernateSection -ne $null) {
		Write-Host "Removing nhibernate config section."
		$nhibernateSection.ParentNode.RemoveChild($nhibernateSection) | Out-Null
		$modified = $true
	}

	$hibernateConfigSectionDeclaration = $webConfig.SelectSingleNode("/configuration/configSections/section[@name='hibernate-configuration']")
	if ($hibernateConfigSectionDeclaration -ne $null) {
		Write-Host "Removing hibernate-configuration config section declaration."
		$hibernateConfigSectionDeclaration.ParentNode.RemoveChild($hibernateConfigSectionDeclaration) | Out-Null
		$modified = $true
	}

	$hibernateConfigSection = $webConfig.SelectSingleNode("/configuration/*[local-name()='hibernate-configuration']")
	if ($hibernateConfigSection -ne $null) {
		Write-Host "Removing hibernate-configuration config section."
		$hibernateConfigSection.ParentNode.RemoveChild($hibernateConfigSection) | Out-Null
		$modified = $true
	}

	$ns = @{x = 'urn:schemas-microsoft-com:asm.v1'}
	$bindingRedirects = $webConfig | Select-Xml -Namespace $ns `
		"/configuration/runtime/x:assemblyBinding/x:dependentAssembly[x:assemblyIdentity[starts-with(@name,'EPiServer.Common.')]]"
	if (($bindingRedirects | Measure-Object).Count -gt 0) {
		Write-Host 'Removing assembly binding redirects:'
		$bindingRedirects| Foreach-Object {
			$assemblyName = $_ | Select-Xml "x:assemblyIdentity/@name" -Namespace $ns
			Write-Host "Removing assembly binding redirect for $assemblyName"
			$_.Node.ParentNode.RemoveChild($_.Node) | Out-Null
		}
		$modified = $true
	}

	$roleProviders = $webConfig | Select-Xml "/configuration/system.web/roleManager/providers/add[starts-with(@type, 'EPiServer.Common.')]"
	if (($roleProviders | Measure-Object).Count -gt 0) {
		Write-Host 'Removing EPiServer Common role provider(s):'
		$roleProviders | Foreach-Object {
			$providerName = $_ | Select-Xml "@name"
			Write-Host "Removing role provider $providerName"
			$_.Node.ParentNode.RemoveChild($_.Node) | Out-Null
		}
		$modified = $true
	}

	$membershipProviders = $webConfig | Select-Xml "/configuration/system.web/membership/providers/add[starts-with(@type, 'EPiServer.Common.')]"
	if (($membershipProviders | Measure-Object).Count -gt 0) {
		Write-Host 'Removing EPiServer Common membership provider(s):'
		$membershipProviders | Foreach-Object {
			$providerName = $_ | Select-Xml "@name"
			Write-Host "Removing membership provider $providerName"
			$_.Node.ParentNode.RemoveChild($_.Node) | Out-Null
		}
		$modified = $true
	}

	$httpModules = $webConfig | Select-Xml "/configuration/system.webServer/modules/add[starts-with(@type, 'EPiServer.Common.')]"
	if (($httpModules | Measure-Object).Count -gt 0) {
		Write-Host 'Removing EPiServer Common http module(s):'
		$httpModules | Foreach-Object {
			$moduleName = $_ | Select-Xml "@name"
			Write-Host "Removing http module $moduleName"
			$_.Node.ParentNode.RemoveChild($_.Node) | Out-Null
		}
		$modified = $true
	}

	$commonShellModule = $webConfig.SelectSingleNode("/configuration/episerver.shell/protectedModules/add[@name='EPiServerCommon']")
	if ($commonShellModule -ne $null) {
		Write-Host "Removing EPiServer Common protected shell module."
		$commonShellModule.ParentNode.RemoveChild($commonShellModule) | Out-Null
		$modified = $true
	}

	$commonLocation = $webConfig.SelectSingleNode("/configuration/location[@path='EPiServerCommon']")
	if ($commonLocation -ne $null) {
		Write-Host "Removing EPiServer Common location element."
		$commonLocation.ParentNode.RemoveChild($commonLocation) | Out-Null
		$modified = $true
	}
	
	return $modified
}
# SIG # Begin signature block
# MIIOLQYJKoZIhvcNAQcCoIIOHjCCDhoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUF4LPIz7lBAFNpvl+bv0M4y9M
# OwSgggtkMIIFZzCCBE+gAwIBAgIRAJgvkmklxJsCm+Wj934zo1UwDQYJKoZIhvcN
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
# BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBR/him2U7dx+1gE2gQ3uU1QvoiENDAN
# BgkqhkiG9w0BAQEFAASCAQCm6S1g40SpdaJPLj0TGOHz2EoyvAfmqlxcN+TL5w+x
# 5CCE+CRV5uNIbvwg7IEnPxo/Ntr7nqSwofkvzRGxh6rfOibSJRostEk2xurDxfxl
# N2AxZVgrz8Lcre4gH7yls4+MC7n7tHYu1A/a4xkIG2Mf03tOZ8Ups/cPewiBqdXW
# /iQW9/UCU18x3V8UWVK6H8xQ5Er89Mf46v8pkxeMmAzkTHRKdd3qzy1att83s9LR
# Pc8aMHco3HyHou+SDcSxJ0dhUjeuq8+GCPohbZd6bl3ZIj81usdTw5e4l1CHjNsF
# ns9wNQXpUUpG2Wkss94Rj4Md1oquaQYpIdHwXPzJVqZq
# SIG # End signature block
