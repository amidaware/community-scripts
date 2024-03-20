<#
Requires global variables for serviceName "ScreenConnectService" and url "ScreenConnectInstaller"
serviceName is the name of the ScreenConnect Service once it is installed EG: "ScreenConnect Client (1327465grctq84yrtocq)"
url is the path the download the exe version of the ScreenConnect Access installer
Both variables values must start and end with "
Also accepts uninstall variable to remove the installed instance if required.
2022-10-12: Added -action start and -action stop variables
2024-3-19 silversword411 - Adding debug. Fixing uninstall when .exe not running.
#>

param (
    [string] $serviceName,
    [string] $url,
    [string] $clientname,
    [string] $sitename,
    [string] $action,
    [switch] $debug
)

# For setting debug output level. -debug switch will set $debug to true
if ($debug) {
    $DebugPreference = "Continue"
    $ErrorActionPreference = 'Continue'
    Write-Debug "Debug mode enabled"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
    Write-Output "Regular mode enabled"
}

$clientname = $clientname.Replace(" ", "%20")
$sitename = $sitename.Replace(" ", "%20")
$url = $url.Replace("&t=&c=&c=&c=&c=&c=&c=&c=&c=", "&t=&c=$clientname&c=$sitename&c=&c=&c=&c=&c=&c=")
$ErrorCount = 0

if (!$serviceName) {
    write-output "Variable not specified ScreenConnectService, please create a global custom field under Client called ScreenConnectService, Example Value: `"ScreenConnect Client (1327465grctq84yrtocq)`" `n"
    $ErrorCount += 1
}
if (!$url) {
    write-output "Variable not specified ScreenConnectInstaller, please create a global custom field under Client called ScreenConnectInstaller, Example Value: `"https://myinstance.screenconnect.com/Bin/ConnectWiseControl.ClientSetup.exe?h=stupidlylongurlhere`" `n"
    $ErrorCount += 1
}

if (!$ErrorCount -eq 0) {
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($action -eq "uninstall") {
    $MyApp = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -eq "$serviceName" }
    Write-Debug "MyApp: $MyApp"
    $MyApp.Uninstall()
}
elseif ($action -eq "stop") {
    If ((Get-Service $serviceName).Status -eq 'Running') {
        Try {
            Write-Output "Stopping $serviceName"
            Set-Service -Name $serviceName -Status stopped -StartupType disabled
            exit 0
        }
        Catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Error -Message "$ErrorMessage $FailedItem"
            exit 1
        }
        Finally {
        }

    }
}
elseif ($action -eq "start") {
    If ((Get-Service $serviceName).Status -ne 'Running') {  
        Try {
            Write-Host "Starting $serviceName"
            Set-Service -Name $serviceName -Status running -StartupType automatic
            exit 0
        }
        Catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Error -Message "$ErrorMessage $FailedItem"
            exit 1
        }
        Finally {
        }

    }
}
else {
    If (Get-Service $serviceName -ErrorAction SilentlyContinue) {

        If ((Get-Service $serviceName).Status -eq 'Running') {
            Try {
                Write-Output "Stopping $serviceName"
                Set-Service -Name $serviceName -Status stopped -StartupType disabled
                exit 0
            }
            Catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Write-Error -Message "$ErrorMessage $FailedItem"
                exit 1
            }
            Finally {
            }

        }
        Else {

            Try {
                Write-Host "Starting $serviceName"
                Set-Service -Name $serviceName -Status running -StartupType automatic
                exit 0
            }
            Catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Write-Error -Message "$ErrorMessage $FailedItem"
                exit 1
            }
            Finally {
            }

        }

    }
    Else {

        $OutPath = $env:TMP
        $output = "screenconnect.exe"

        Try {
            $start_time = Get-Date
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile("$url", "$OutPath\$output")
            Write-Debug "Time taken to download: $((Get-Date).Subtract($start_time).Seconds) second(s)"
			    
            $start_time = Get-Date
            $wc = New-Object System.Net.WebClient 
            Start-Process -FilePath $OutPath\$output -Wait
            Write-Debug "Time taken to install: $((Get-Date).Subtract($start_time).Seconds) second(s)"           
            exit 0
        }
        Catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Write-Error -Message "$ErrorMessage $FailedItem"
            exit 1
        }
        Finally {
            Remove-Item -Path $OutPath\$output
        }

    }
}
