# Namespace of the assemblyBinding element
$ns = "urn:schemas-microsoft-com:asm.v1"

##
## Updates the assemblyBinding element of the config to contain binding redirects to the files in installPath
##
Function Update-AssemblyBinding([System.Xml.XmlDocument]$config, $installPath)
{
	$assemblyBindingElement = Get-AssemblyBindingElement $config

	$assemblyConfigs = $assemblyBindingElement.ChildNodes | where {$_.GetType().Name -eq "XmlElement"}

	#add/update binding redirects for assemblies in the current package
	$libPath = join-path $installPath "lib\*"
	get-childItem "$libPath\*.dll" | % { Update-BindingRedirect $_  $assemblyConfigs $config }

    return $config
}

##
## Gets the assembly binding elements, and if there are multiple, merges them to one.
##
Function Get-AssemblyBindingElement([System.Xml.XmlDocument]$config)
{
	# assume that we have the configuration element and make sure we have all the other parents of the AssemblyIdentity element.
	$configElement = $config.configuration
	$runtimeElement = Get-Element $configElement "runtime" $null $config
	$assemblyBindingElement = Get-Element $runtimeElement "assemblyBinding" $ns $config

	if ($assemblyBindingElement.length -gt 1)
	{
		for ($i=1; $i -lt $assemblyBindingElement.length; $i++) 
		{
			$assemblyBindingElement[0].InnerXml +=  $assemblyBindingElement[$i].InnerXml
			$runtimeElement.RemoveChild($assemblyBindingElement[$i]) | Out-Null
		}
	}
	else 
	{
		$assemblyBindingElement = @($assemblyBindingElement)
	}

	$assemblyBindingElement[0]
}

##
## Inserts a new or updates an existing dependentAssembly element for a specified assembly
##
Function Update-BindingRedirect([System.IO.FileInfo] $file, [System.Xml.XmlElement[]] $assemblyConfigs, [System.Xml.XmlDocument] $config)
{
	[regex]$regex = '[\w\.]+,\sVersion=[\d\.]+,\sCulture=(?<culture>[\w-]+),\sPublicKeyToken=(?<publicKeyToken>\w+)'
    $name =  Get-FileName $file
    $assemblyName = Get-AssemblyName $file

    $assemblyConfig =  $assemblyConfigs | ? { $_.assemblyIdentity.Name -Eq $name } 

    if ($assemblyConfig -Eq $null) 
    { 
        #there is no existing binding configuration for the assembly, we need to create a new config element for it
        Write-Host "Adding binding redirect for $name".

        $matches = $regex.Matches($assemblyName.FullName)
        if ($matches.Count -gt 0)
        {
	        $publicKeyToken = $matches[0].Groups["publicKeyToken"].Value
	        $culture = $matches[0].Groups["culture"].Value
        }
        else 
        {
            Write-Host "Unable to figure out culture and publicKeyToken for $name"
	        $publicKeyToken = "null"
	        $culture = "neutral"
        }
    
        $assemblyIdentity = $config.CreateElement("assemblyIdentity", $ns)
        $assemblyIdentity.SetAttribute("name", $name)
        if (![String]::IsNullOrEmpty($publicKeyToken))
        {
	        $assemblyIdentity.SetAttribute("publicKeyToken", $publicKeyToken)
        }
        if (![String]::IsNullOrEmpty($culture))
        {
	        $assemblyIdentity.SetAttribute("culture", $culture)
        }
        
        $bindingRedirect = $config.CreateElement("bindingRedirect", $ns)
        $bindingRedirect.SetAttribute("oldVersion", "")
        $bindingRedirect.SetAttribute("newVersion", "")
        
        $assemblyConfig = $config.CreateElement("dependentAssembly", $ns)
        $assemblyConfig.AppendChild($assemblyIdentity) | Out-Null
        $assemblyConfig.AppendChild($bindingRedirect) | Out-Null

        #locate the assemblyBinding element and append the newly created dependentAssembly element
        $assemblyBinding = $config.configuration.runtime.ChildNodes | where {$_.Name -eq "assemblyBinding"}
        $assemblyBinding.AppendChild($assemblyConfig) | Out-Null
    } 
    else 
    {
        Write-Host "Updating binding redirect for $name"
    }

    $assemblyConfig.bindingRedirect.oldVersion = "0.0.0.0-" + $assemblyName.Version
    $assemblyConfig.bindingRedirect.newVersion = $assemblyName.Version.ToString()
}

#
# Gets an existing element or creates it
#
Function Get-Element([System.Xml.XmlElement]$parent, $elementName, $ns, $document)
{
    $child = $parent.$($elementName)
    if ($child -eq $null) 
    {        
        $child = $document.CreateElement($elementName, $ns)
        $parent.AppendChild($child) | Out-Null
    }	
    $child
}

##
## Gets the file name from given FileInfo obj
##
Function Get-FileName([System.IO.FileInfo] $file)
{
   $name = [System.IO.Path]::GetFileNameWithoutExtension($file)
   return $name
}

##
## Gets the Assembly name object from given FileInfo obj
##
Function Get-AssemblyName([System.IO.FileInfo] $file)
{
  $assemblyName = [System.Reflection.AssemblyName]::GetAssemblyName($file)
  return $assemblyName
}

# SIG # Begin signature block
# MIIOLQYJKoZIhvcNAQcCoIIOHjCCDhoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUI5vg7YJVIhomCuW8TfKHYfuu
# de2gggtkMIIFZzCCBE+gAwIBAgIRAJgvkmklxJsCm+Wj934zo1UwDQYJKoZIhvcN
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
# BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQtVv60ncYBIDsE0VMoBlm/1BZeXzAN
# BgkqhkiG9w0BAQEFAASCAQBhsUsiVo6tRjC0rgz68n5f5DmA/K8eR7I+3I4mpM73
# Bu3i8tbYzCGFPaix0NCNxp+ADSDqtn30BHYJrB9h1wztXjU9DwbyQCEd5EAufsaB
# EEF1d1dMIvGHmltc2yfiOsJep2jGk7IQv8YxHA4Bv8rBS67hjMFavoqurOkeJhuI
# LiAHySLGuSa6+sR9aeU23GKtSXjf2NHOjgNThWJgw2jzwR2GfRB6iXxPJqStRcYg
# WxXiR1dI3jc9z6muUO60hc5PVi18NhGKIsqlAAL+LqP1p74iwo/1++knCLyh+Qun
# 1eBImQVkw+5G9r5IbI6ufG50I0i+eDe+uM1LluuvZKD8
# SIG # End signature block
