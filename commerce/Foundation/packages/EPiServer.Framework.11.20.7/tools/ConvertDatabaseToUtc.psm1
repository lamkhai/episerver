
function Get-WebConfig
{
	param ($projectPath)

	# Construct the path to the web.config based on the project path
	$webConfigPath = Join-Path $projectPath "web.config"

	# Do an early exit returning null if the web.config file doesn't exist
	if (!(Test-Path $webConfigPath))
	{
		return $null
	}

	# Load the web.config as an XmlDocument
	[xml] $config = Get-Content $webConfigPath

	# Expand all the nodes that have their configuration in another file
	$config.SelectNodes("//*[@configSource]") | ForEach-Object {
		$configFragmentPath = Join-Path $projectPath $_.GetAttribute("configSource")
		if (Test-Path $configFragmentPath)
		{
			# Set the contents of the referenced file as the contents of the referencing element
			$_.InnerXml = ([xml](Get-Content $configFragmentPath)).FirstChild.InnerXml
			$_.RemoveAttribute("configSource")
		}
	}

	return $config
}


#Create a offset type
Function New-DateTimeConversionOffset()
{
  param ([datetime]$IntervalStart,[datetime] $IntervalEnd, [long]$Offset)

  $DateTimeConversionOffset = new-object PSObject

  $DateTimeConversionOffset | add-member -type NoteProperty  -Name IntervalStart -Value $IntervalStart
  $DateTimeConversionOffset | add-member -type NoteProperty  -Name IntervalEnd -Value $IntervalEnd
  $DateTimeConversionOffset | add-member -type NoteProperty  -Name Offset -Value $Offset

  return $DateTimeConversionOffset
}

#generate Offset with respect to time zone between start and end 
Function GenerateOffsets()
{
	param ([TimeZoneInfo]$timeZone, [int]$startYears, [int]$endYears)
	
	$res = @()
    $start = (get-date).AddYears($startYears)
    $end = (get-date).AddYears($endYears)
    $current = $start
    $startOffset = $timeZone.GetUtcOffset($start).TotalMinutes
    while ($current -lt $end)
    {
        $current = $current.AddMinutes(30)
        $currentOffset = $timeZone.GetUtcOffset($current).TotalMinutes
        if ($startOffset -ne $currentOffset)
        {
            $res += New-DateTimeConversionOffset -IntervalStart:$start -IntervalEnd:$current -Offset:$startOffset
            $start = $current
            $startOffset = $currentOffset
        }
    }
    if ($start -ne $current)
	{
     	$res += New-DateTimeConversionOffset -IntervalStart:$start -IntervalEnd:$current -Offset:$startOffset
	}
	return $res
}

#create offfset as a date table to send to sp
Function CreateOffsetRows()
{
	param ($items)

	$result = New-Object 'System.Collections.Generic.List[Microsoft.SqlServer.Server.SqlDataRecord]'
    if ($items -ne $null)
    {
        $intervalStart =  new-object Microsoft.SqlServer.Server.SqlMetaData("IntervalStart", [System.Data.SqlDbType]::DateTime);
        $intervalEnd =  new-object Microsoft.SqlServer.Server.SqlMetaData("IntervalEnd", [System.Data.SqlDbType]::DateTime);
        $offset =  new-object Microsoft.SqlServer.Server.SqlMetaData("Offset", [System.Data.SqlDbType]::Float);
		foreach($item in $items)
		{
            $sqldr = new-object Microsoft.SqlServer.Server.SqlDataRecord($intervalStart, $intervalEnd, $offset);
            [void]$sqldr.SetDateTime(0, $item.IntervalStart);
            [void]$sqldr.SetDateTime(1, $item.IntervalEnd);
            [void]$sqldr.SetDouble(2, $item.Offset);
			[void]$result.ADD($sqldr)
		}
    }
    return $result;
}

Function CreateOffsetInDB($connectionString, $rows)
{
	$effectedRows = ExecuteSP $connectionString "dbo.DateTimeConversion_InitDateTimeOffsets" "@DateTimeOffsets"  $rows "dbo.DateTimeConversion_DateTimeOffset"
} 

Function InitFieldNames($connectionString)
{
	$effectedRows = ExecuteSP $connectionString "DateTimeConversion_InitFieldNames"  
}

Function InitBlocks($connectionString, $blockSize)
{
	$effectedRows = ExecuteSP $connectionString "DateTimeConversion_InitBlocks" "@BlockSize"  $blockSize
}

Function RunBlocks($connectionString)
{
	$effectedRows = ExecuteSP $connectionString "DateTimeConversion_RunBlocks" 
}

Function SwitchToUtc($connectionString)
{
	$effectedRows = ExecuteSP $connectionString "DateTimeConversion_Finalize" 
}

Function ExecuteSP($connectionString, $nameOfSP, $paramName, $paramValue, $typeName)
{
	$connection = $null
	$cmd = $null;

	try
	{
		$connection = new-object System.Data.SqlClient.SQLConnection($connectionString)
		$connection.Open()
		$cmd = new-object System.Data.SqlClient.SqlCommand($nameOfSP, $connection)
		$cmd.CommandType = [System.Data.CommandType]::StoredProcedure
		$cmd.CommandTimeout = 0
		if ($paramName -and $paramValue)
		{
			$cmdparam = $cmd.Parameters.AddWithValue($paramName, $paramValue)
			if($typeName)
			{
				$cmdparam.SqlDbType = [System.Data.SqlDbType]::Structured
				$cmdparam.TypeName = $typeName
			}		
		}
		return  $cmd.ExecuteNonQuery() 
	}
	finally
	{
		if ($cmd)
		{
			[Void]$cmd.Dispose()
		}
		if ($connection)
		{
			[Void]$connection.Close()
		}
	}
}

<#
	This function can be used in the powershell context if the database connectionstring is known.
#>
Function ConvertEPiDatabaseToUtc()
{
<#
	.Description
		Convert the dateTime columns in the database to UTC. The Convert-EPiDatabaseToUtc cmdlet converts the columns that has been 
		configured in the DateTimeConversion_GetFieldNames. By default it only converts the content related items in the db.
		If both the Web applictaion and SQL Database already runs on the UTC, the cmdlet can be run with onlySwitchToUtc flag.
    .SYNOPSIS 
		Convert the dateTime in the database to UTC.  
    .EXAMPLE
		Convert-EPiDateTime -connectionString:"connection string"
		Convert-EPiDateTime -connectionString:"connection string" -onlySwitchToUtc:$true 
		Convert-EPiDateTime -connectionString:"connection string" -timeZone:([TimeZoneInfo]::FindSystemTimeZoneById("US Eastern Standard Time")) 
#>

	param (
	[Parameter(Mandatory=$true)][string]$connectionString, 
	[TimeZoneInfo] $timeZone = [TimeZoneInfo]::Local, 
	[int] $startYears = -25, 
	[int] $endYears = 5, 
	[int] $blockSize = 1000, 
	[bool]$onlySwitchToUtc  = $false)

	Write-Host "Database conversion to UTC has started..."

	if ($onlySwitchToUtc -eq $true)
	{
		InitFieldNames $connectionString 
		SwitchToUtc  $connectionString 
	}
	else
	{
		$offsets = GenerateOffsets $timeZone $startYears $endYears
		$rows = [Microsoft.SqlServer.Server.SqlDataRecord[]](CreateOffsetRows $offsets)
		CreateOffsetInDB $connectionString $rows
		InitFieldNames $connectionString 
		InitBlocks $connectionString $blockSize
		RunBlocks  $connectionString 
		SwitchToUtc  $connectionString 
	}
	
	Write-Host "Database conversion to UTC completed successfully"
}

Function GetConnectionString($connectionString)
{
	$theConnectionStringNameOrValue = $connectionString
	if (!$connectionString)
	{
		#default value is EPiServerDB
		$theConnectionStringNameOrValue = "EPiServerDB"
	}
		
	$project = Get-Project
	if (!$project)
	{
		throw "No active project, please define a connectionstring argument if you are not run under a project context."
	}

	$projectPath =  (Get-Item   $project.FullName).Directory.FullName
	$webconfig = Get-WebConfig  -projectPath $projectPath

	if (!$webconfig)
	{
		throw "No web config"
	}

	foreach($cn in $webconfig.configuration.connectionStrings.add)
	{
		#Take first one so far
		if (!$connectionString)
		{
			$connectionString = $cn.connectionString
		}
		if ($cn -and $cn.name -eq $theConnectionStringNameOrValue)
		{
			return $cn.connectionString.replace("|DataDirectory|", (join-path $projectPath "app_data\"))
		}
	}
	
	return  $connectionString 
}

Function Convert-EPiDatabaseToUtc()
{
<#
	.Description
		Convert the dateTime columns in the database to UTC. The Convert-EPiDatabaseToUtc cmdlet converts the columns that has been 
		configured in the DateTimeConversion_GetFieldNames. By default it only converts the content related items in the db. 
		If both the Web applictaion and SQL Database already runs on the UTC, the cmdlet can be run with onlySwitchToUtc.
    .SYNOPSIS 
		Convert the dateTime in the database to UTC.  
    .EXAMPLE
		Convert-EPiDateTime 
		Convert-EPiDateTime -connectionString:"connection string"
		Convert-EPiDateTime -connectionString:"connection string Name"  -onlySwitchToUtc:$true
		Convert-EPiDateTime -connectionString:"connection string" -timeZone:([TimeZoneInfo]::FindSystemTimeZoneById("US Eastern Standard Time")) 
#>
	[CmdletBinding()]
	param (
	[string]$connectionString, 
	[TimeZoneInfo] $timeZone = [TimeZoneInfo]::Local, 
	[int] $startYears = -25, 
	[int] $endYears = 5, 
	[int] $blockSize = 1000, 
	[bool] $onlySwitchToUtc = $false)

	$connectionString = GetConnectionString $connectionString
	if (!$connectionString)
	{
		throw "Failed to find the connectionstring"
	}
	ConvertEPiDatabaseToUtc $connectionString $timeZone $startYears $endYears $blockSize $onlySwitchToUtc
}

# SIG # Begin signature block
# MIIOLQYJKoZIhvcNAQcCoIIOHjCCDhoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5FpZYfQbQCiKzvu8KYIFGpZp
# /oegggtkMIIFZzCCBE+gAwIBAgIRAJgvkmklxJsCm+Wj934zo1UwDQYJKoZIhvcN
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
# BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQAUFSv9pnlZkp6SaAfDYASvbDcRjAN
# BgkqhkiG9w0BAQEFAASCAQAqo6b+yI2jeXWEbiZT0Aq4zlbnitVDXtxRsK8nBv8F
# yGXY5K1PSOUAvZPV9qNAVGuM3ITsB3y3dPVLGzl4fcMwLKcpGIA4M4XbgLTABd2T
# WLtuIhYRxznIdSC9FlzJ+n3s65DGi9Pe4DQNBdI3En/XOutjekJG73zI9VbVdJNm
# vCoFe/j+b8qn6CbsWVrl6frDbZN0vIRzkuz9YDvlvPOWkHHv/ftUkOpUS+17YrCo
# eVGqSrTcrpywVTfEHpOUfdwYYR6yGDwz5h0JtToif/Qp17rVsN5VEMHOYE/8gllc
# qQeVLHjOWptF6lHUsCMuO8CDGF66uCyNcCVu5XQTFnyM
# SIG # End signature block
