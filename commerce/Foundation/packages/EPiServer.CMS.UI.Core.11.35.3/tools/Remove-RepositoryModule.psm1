function Remove-RepositoryModule
{
    param ($protectedModulesPath, $respositoryPath, $packageName)

    # Validate that the package name parameter exists
    if ($packageName -eq $null -or $packageName -eq "")
    {
        throw (New-Object ArgumentException("The package name was not specified."))
    }

    # Get the package.config content .. so we can construct ModuleRepository folder path 
    $packageConfigPath = Join-Path $protectedModulesPath "packages.config"

	if(!(Test-Path $packageConfigPath)) 
	{
    	return	 
	}
    
    # Load the packages.config as an XmlDocument
    [xml] $packagesConfig = Get-Content $packageConfigPath 

    if($packagesConfig -ne $null)
    {
        # we could have several versions of a package so get all and then delete one by one
        $packageElements = $packagesConfig.SelectNodes("/packages/package[@id=""$packageName""]")
        if($packageElements -ne $null)
        {
            foreach($package in $packageElements)
            {
                $folderName = $package.id + "."+ $package.version
                $repositoryModulePath = (Join-Path $respositoryPath $folderName)

                # If the add-on folder doesn't exist then don't need to delete anything and we exit silently
                if ((Test-Path $repositoryModulePath))
                {
                    try
                    {
                        # Remove the add-on folder and all children.
                        Write-Host "Removing folder - $repositoryModulePath"
                        Remove-Item $repositoryModulePath -Force -Recurse -ErrorAction Stop
                    }
                    catch [Exception]
                    {
                        # Show a message box explaining that the package.config couldn't be saved
                        $errorMsg = "The package installer was unable to delete the folder ""$repositoryModulePath"". Please delete this folder and its contents manually."
                        Write-Host $errorMsg
                        [System.Windows.Forms.MessageBox]::Show($errorMsg, "Error Deleting Repository Module") | Out-Null
                    }   
                }
            }            
        }        
    }
}

Export-ModuleMember -Function Remove-RepositoryModule
# SIG # Begin signature block
# MIIamAYJKoZIhvcNAQcCoIIaiTCCGoUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDTsX4zjze70/HQMozq3SDX/t
# XISgghWbMIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgVGltZXN0YW1waW5nIENBMB4XDTIxMDEwMTAwMDAwMFoXDTMxMDEw
# NjAwMDAwMFowSDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMu
# MSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMTCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBAMLmYYRnxYr1DQikRcpja1HXOhFCvQp1dU2UtAxQ
# tSYQ/h3Ib5FrDJbnGlxI70Tlv5thzRWRYlq4/2cLnGP9NmqB+in43Stwhd4CGPN4
# bbx9+cdtCT2+anaH6Yq9+IRdHnbJ5MZ2djpT0dHTWjaPxqPhLxs6t2HWc+xObTOK
# fF1FLUuxUOZBOjdWhtyTI433UCXoZObd048vV7WHIOsOjizVI9r0TXhG4wODMSlK
# XAwxikqMiMX3MFr5FK8VX2xDSQn9JiNT9o1j6BqrW7EdMMKbaYK02/xWVLwfoYer
# vnpbCiAvSwnJlaeNsvrWY4tOpXIc7p96AXP4Gdb+DUmEvQECAwEAAaOCAbgwggG0
# MA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsG
# AQUFBwMIMEEGA1UdIAQ6MDgwNgYJYIZIAYb9bAcBMCkwJwYIKwYBBQUHAgEWG2h0
# dHA6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAfBgNVHSMEGDAWgBT0tuEgHf4prtLk
# YaWyoiWyyBc1bjAdBgNVHQ4EFgQUNkSGjqS6sGa+vCgtHUQ23eNqerwwcQYDVR0f
# BGowaDAyoDCgLoYsaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJl
# ZC10cy5jcmwwMqAwoC6GLGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtdHMuY3JsMIGFBggrBgEFBQcBAQR5MHcwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBPBggrBgEFBQcwAoZDaHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRFRpbWVzdGFtcGluZ0NB
# LmNydDANBgkqhkiG9w0BAQsFAAOCAQEASBzctemaI7znGucgDo5nRv1CclF0CiNH
# o6uS0iXEcFm+FKDlJ4GlTRQVGQd58NEEw4bZO73+RAJmTe1ppA/2uHDPYuj1UUp4
# eTZ6J7fz51Kfk6ftQ55757TdQSKJ+4eiRgNO/PT+t2R3Y18jUmmDgvoaU+2QzI2h
# F3MN9PNlOXBL85zWenvaDLw9MtAby/Vh/HUIAHa8gQ74wOFcz8QRcucbZEnYIpp1
# FUL1LTI4gdr0YKK6tFL7XOBhJCVPst/JKahzQ1HavWPWH1ub9y4bTxMd90oNcX6X
# t/Q/hOvB46NJofrOp79Wz7pZdmGJX36ntI5nePk2mOHLKNpbh6aKLzCCBTEwggQZ
# oAMCAQICEAqhJdbWMht+QeQF2jaXwhUwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4X
# DTE2MDEwNzEyMDAwMFoXDTMxMDEwNzEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEx
# MC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFtcGluZyBD
# QTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL3QMu5LzY9/3am6gpnF
# OVQoV7YjSsQOB0UzURB90Pl9TWh+57ag9I2ziOSXv2MhkJi/E7xX08PhfgjWahQA
# OPcuHjvuzKb2Mln+X2U/4Jvr40ZHBhpVfgsnfsCi9aDg3iI/Dv9+lfvzo7oiPhis
# EeTwmQNtO4V8CdPuXciaC1TjqAlxa+DPIhAPdc9xck4Krd9AOly3UeGheRTGTSQj
# MF287DxgaqwvB8z98OpH2YhQXv1mblZhJymJhFHmgudGUP2UKiyn5HU+upgPhH+f
# MRTWrdXyZMt7HgXQhBlyF/EXBu89zdZN7wZC/aJTKk+FHcQdPK/P2qwQ9d2srOlW
# /5MCAwEAAaOCAc4wggHKMB0GA1UdDgQWBBT0tuEgHf4prtLkYaWyoiWyyBc1bjAf
# BgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzASBgNVHRMBAf8ECDAGAQH/
# AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB5BggrBgEF
# BQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBD
# BggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2Ny
# bDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDig
# NoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9v
# dENBLmNybDBQBgNVHSAESTBHMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYc
# aHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzALBglghkgBhv1sBwEwDQYJKoZI
# hvcNAQELBQADggEBAHGVEulRh1Zpze/d2nyqY3qzeM8GN0CE70uEv8rPAwL9xafD
# DiBCLK938ysfDCFaKrcFNB1qrpn4J6JmvwmqYN92pDqTD/iy0dh8GWLoXoIlHsS6
# HHssIeLWWywUNUMEaLLbdQLgcseY1jxk5R9IEBhfiThhTWJGJIdjjJFSLK8pieV4
# H9YLFKWA1xJHcLN11ZOFk362kmf7U2GJqPVrlsD0WGkNfMgBsbkodbeZY4UijGHK
# eZR+WfyMD+NvtQEmtmyl7odRIeRYYJu6DC0rbaLEfrvEJStHAgh8Sa4TtuF8QkIo
# xhhWz0E0tmZdtnR79VYzIi8iNrJLokqV2PWmjlIwggVnMIIET6ADAgECAhEAmC+S
# aSXEmwKb5aP3fjOjVTANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJHQjEbMBkG
# A1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxJDAiBgNVBAMTG1NlY3RpZ28gUlNBIENvZGUg
# U2lnbmluZyBDQTAeFw0xOTA1MjIwMDAwMDBaFw0yMjA1MjEyMzU5NTlaMIG1MQsw
# CQYDVQQGEwJTRTEOMAwGA1UEEQwFMTExNTYxDzANBgNVBAgMBlN3ZWRlbjESMBAG
# A1UEBwwJU3RvY2tob2xtMRowGAYDVQQJDBFSZWdlcmluZ3NnYXRhbiA2NzERMA8G
# A1UEEgwIQm94IDcwMDcxFTATBgNVBAoMDEVwaXNlcnZlciBBQjEUMBIGA1UECwwL
# RW5naW5lZXJpbmcxFTATBgNVBAMMDEVwaXNlcnZlciBBQjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALMg0HiSm99PJyVgbuJFKNjRyi98VFKF4lTVA4GX
# fXgixyErz+ISaHcXrjxEW1CkH55+Vh+LDjBIMqJ2mOC+2d/Dh9OwZINayxOxV+gs
# qGH7F+7o//+EAWztkRH9Etw2IBedwlTeZvZitKew6gYWZwMq7wM5Ndp7oaXw8E4M
# XviOY6Lof390xWWy3BhWRu9I37JhU4vkrnxg4cPZ8sZYb0OEw/n0mvJ2Y2wjyRUQ
# YZXtUHyAe2c5lfmDpdFkFf7QEPB9Erkm19MvF6RvAv9hkaeQbNnFAKbJcp57ewpD
# dEMzR+CrLkwjSZhX5HM39/Aq/O58e4fCfSIotBYSnDZcjrcCAwEAAaOCAagwggGk
# MB8GA1UdIwQYMBaAFA7hOqhTOjHVir7Bu61nGgOFrTQOMB0GA1UdDgQWBBT8FQmi
# bCssGc1dLqmLA0Jk40EuJDAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAT
# BgNVHSUEDDAKBggrBgEFBQcDAzARBglghkgBhvhCAQEEBAMCBBAwQAYDVR0gBDkw
# NzA1BgwrBgEEAbIxAQIBAwIwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdv
# LmNvbS9DUFMwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5zZWN0aWdvLmNv
# bS9TZWN0aWdvUlNBQ29kZVNpZ25pbmdDQS5jcmwwcwYIKwYBBQUHAQEEZzBlMD4G
# CCsGAQUFBzAChjJodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29SU0FDb2Rl
# U2lnbmluZ0NBLmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5j
# b20wIAYDVR0RBBkwF4EVc3VwcG9ydEBlcGlzZXJ2ZXIuY29tMA0GCSqGSIb3DQEB
# CwUAA4IBAQCEvy8b9Y9uMcMSgC6H4qSrY0WetAMrQwTIea4KhaNDA/6C5hwfDv9H
# yOupMkBFgOUx2nxvH0MPy1yAC6EH2wtk+VCIbIYAhDPKLMdJ2s8UqCjbIAFKfCCh
# 1im+VtUkQnFDWKNt+fLfKk9CfAd2lhS0NnUEmSzj8/z4QwRO06asyL2i0VjdicUQ
# TvRVEEoVqABvUisChgJMyp+yRHi5SbXDoSfiaIV/Hx+JILrr2nBAQ0Cj5KXHW0Dn
# BAFyGqXTC62iFKz2ToNG250Dk+FWX1zBbQShc9nemuHX/HYmYWEg8M/9YorIYwDD
# EFNFjupbDPP67cA7vauuXqsuy2TcdXo9MIIF9TCCA92gAwIBAgIQHaJIMG+bJhjQ
# guCWfTPTajANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Ck5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUg
# VVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkwHhcNMTgxMTAyMDAwMDAwWhcNMzAxMjMxMjM1OTU5
# WjB8MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAw
# DgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJDAiBgNV
# BAMTG1NlY3RpZ28gUlNBIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAIYijTKFehifSfCWL2MIHi3cfJ8Uz+MmtiVmKUCGVEZ0
# MWLFEO2yhyemmcuVMMBW9aR1xqkOUGKlUZEQauBLYq798PgYrKf/7i4zIPoMGYmo
# bHutAMNhodxpZW0fbieW15dRhqb0J+V8aouVHltg1X7XFpKcAC9o95ftanK+ODtj
# 3o+/bkxBXRIgCFnoOc2P0tbPBrRXBbZOoT5Xax+YvMRi1hsLjcdmG0qfnYHEckC1
# 4l/vC0X/o84Xpi1VsLewvFRqnbyNVlPG8Lp5UEks9wO5/i9lNfIi6iwHr0bZ+UYc
# 3Ix8cSjz/qfGFN1VkW6KEQ3fBiSVfQ+noXw62oY1YdMCAwEAAaOCAWQwggFgMB8G
# A1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBQO4TqoUzox
# 1Yq+wbutZxoDha00DjAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAdBgNVHSUEFjAUBggrBgEFBQcDAwYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRV
# HSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9V
# U0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDB2BggrBgEFBQcB
# AQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRydXN0LmNvbS9VU0VS
# VHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZaHR0cDovL29jc3Au
# dXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEATWNQ7Uc0SmGk295qKoyb
# 8QAAHh1iezrXMsL2s+Bjs/thAIiaG20QBwRPvrjqiXgi6w9G7PNGXkBGiRL0C3da
# nCpBOvzW9Ovn9xWVM8Ohgyi33i/klPeFM4MtSkBIv5rCT0qxjyT0s4E307dksKYj
# alloUkJf/wTr4XRleQj1qZPea3FAmZa6ePG5yOLDCBaxq2NayBWAbXReSnV+pbjD
# bLXP30p5h1zHQE1jNfYw08+1Cg4LBH+gS667o6XQhACTPlNdNKUANWlsvp8gJRAN
# GftQkGG+OY96jk32nw4e/gdREmaDJhlIlc5KycF/8zoFm/lv34h/wCOe0h5DekUx
# wZxNqfBZslkZ6GqNKQQCd3xLS81wvjqyVVp4Pry7bwMQJXcVNIr5NsxDkuS6T/Fi
# kyglVyn7URnHoSVAaoRXxrKdsbwcCtp8Z359LukoTBh+xHsxQXGaSynsCz1XUNLK
# 3f2eBVHlRHjdAd6xdZgNVCT98E7j4viDvXK6yz067vBeF5Jobchh+abxKgoLpbn0
# nu6YMgWFnuv5gynTxix9vTp3Los3QqBqgu07SqqUEKThDfgXxbZaeTMYkuO1dfih
# 6Y4KJR7kHvGfWocj/5+kUZ77OYARzdu1xKeogG/lU9Tg46LC0lsa+jImLWpXcBw8
# pFguo/NbSwfcMlnzh6cabVgxggRnMIIEYwIBATCBkTB8MQswCQYDVQQGEwJHQjEb
# MBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgw
# FgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJDAiBgNVBAMTG1NlY3RpZ28gUlNBIENv
# ZGUgU2lnbmluZyBDQQIRAJgvkmklxJsCm+Wj934zo1UwCQYFKw4DAhoFAKB4MBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYE
# FHnh7kj/fcL+SY1c89oW7C+cQpbEMA0GCSqGSIb3DQEBAQUABIIBAJHcH0aacXxi
# 6cIM2it1hWbqWX2HDHw9/PFulzVz//IYvtqOPPI4gTRhoUaLTDfiO90PwL73m5XM
# HFLFme2WNGmgkunLWWfYXe7AoovT9G41kUth0CIuAXaIy4uW/2799alYybKceY23
# WqGYtCxhqAr9qkg23qGWHPeeadjv0ZF0y/2o/v/g0aoUFfFDrRekh3hX3z4YXyP5
# MHUFgs3NY9X1iX+o4Sjvrj+ZXGYAhbhCen5aUo04Z9MM8ecf1jPPPDag/pxTyA6+
# lGHeThnQLtPsPTvquxid77S7bgBNHRbTW6KGTGoAEbJIKWqTpPlVNcG/lea5CLSw
# FJQMZQGaUH6hggIwMIICLAYJKoZIhvcNAQkGMYICHTCCAhkCAQEwgYYwcjELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRp
# bWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEFAKBp
# MBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIxMDYw
# NDA5MTIyMVowLwYJKoZIhvcNAQkEMSIEIBIC8IswPzTpgmlwsuLoBtXiU53xAvO/
# PhBeMRnLUMAUMA0GCSqGSIb3DQEBAQUABIIBAInHlUnRKu6uUSsx7lNkzC9VIKoZ
# xLgXLAet8BLL9Seq2rIDmW+89KVUZt4v0zOeK3XpHNuWFlT9Rze/QqQx7/WrSE0z
# 5VAzi3gExrKWVQypJZhr1aTSPvNtMuNqQJD7yuL+MMxZPfoBvHNukLm7Q+GQYjuR
# r+rAROgOj2xuUr90oGrzhX1K824AbItjf4SwvNIIPV2fhL7BbZu0uGjdoZdfhOwj
# W6LoHeu3FSNx7dZd7Jv5ZGWjayb89ZBwhvL/zxMxe/Donj5zAj2EPrhphKrgRUR9
# WMACwdRI2X8pQ12mlkVfc2Nt4U/Rm2kw+SczYJhYh3QA9UOu8iojLznZIoM=
# SIG # End signature block
