<#
.SYNOPSIS
    Installs printers via name and IP
.DESCRIPTION
.INSTRUCTIONS
.NOTES
    Version: 1.0
    Creation Date: 2022-02-14
#>

Param(
    [Parameter(Mandatory)]
    [string]$PrinterNames,

    [Parameter(Mandatory)]
    [string]$PrinterIPs,

    [Parameter(Mandatory)]
    [string]$DriverNames,

    [Parameter(Mandatory)]
    [string]$DriverLocations,

    [switch]$Force
)

function Win_PrinterInstaller {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$PrinterNames,

        [Parameter(Mandatory)]
        [string]$PrinterIPs,

        [Parameter(Mandatory)]
        [string]$DriverNames,

        [Parameter(Mandatory)]
        [string]$DriverLocations,

        [switch]$Force
    )

    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
        #test for install
        #check params, expecting comma separated values
        $pn = @($PrinterNames -Split ",")
        $pi = @($PrinterIPs -Split ",")
        if ($pn.Length -ne $pi.Length) {
            Write-Error "Printer names and IPs must have the same count."
            return
        }
        else {
            Write-Output "$($pn.Length) printer(s) specified."
        }

        $dn = @($DriverNames -Split ",")
        if ($pn.Length -ne $dn.Length) {
            Write-Error "Printer names and Driver names must have the same count."
        }

        $dl = @()
        if ($DriverLocations.Length -gt 0) {
            $dl = @($DriverLocations -Split ",")
            if ($pn.Length -ne $dl.Length) {
                Write-Error "Printer Names and Drivers must have the same count."
                return
            }
        }
        else {
            Write-Error "No drivers specified."
        }
    }

    Process {
        Try {
            #do install
            for ($i = 0; $i -le $pn.Length; $i++) {
                #Check if driver location is web address for download
                if ($dl[$i].StartsWith("https://")) {
                    Write-Output "Downloading printer driver zip."
                    Invoke-RestMethod $dl[$i] -OutFile "C:\packages$random\driver.zip"
                    $dl[$i] = "C:\packages$random\"
                    Expand-Archive -Path "C:\packages$random\driver.zip" -DestinationPath $dl[$i] -Force
                }

                if ($Force) {
                    $port = Get-PrinterPort -Name "$($pn[$i]) Port" -ErrorAction SilentlyContinue
                    if ($port) {
                        Get-Printer | Where-Object { $_.PortName -eq "$($pn[$i]) Port" } | Remove-Printer
                        Remove-PrinterPort -Name "$($pn[$i]) Port"
                    }
                }

                #add drivers to windows
                Write-Output "Installing printer driver."
                $inf = Get-ChildItem -Path $dl[$i] -Recurse -Filter "*.inf" | ForEach-Object {
                    $p = $_.FullName
                    $pnp = & pnputil.exe /add-driver $p /install | Out-String
                    $null = $pnp -match '(?m)^Published Name:\s+(.+)$'
                    $matches[1]
                    return $matches[1]
                }

                $inf[-1] = $inf[-1] -replace "`t|`n|`r"
                $loc = (Get-WindowsDriver -Online | Where-Object { $_.Driver -match $inf[-1] }).OriginalFileName
                Add-PrinterDriver -Name $dn[$i] -InfPath $loc -ErrorAction Stop
                Write-Output "Printer driver installation complete."
                Write-Output "Adding printer port."
                Add-PrinterPort -Name "$($pn[$i]) Port" -PrinterHostAddress $pi[$i]
                Write-Output "Printer port added."
                $printerArgs = @{
                    DriverName = $dn[$i]
                    Name       = $pn[$i]
                    PortName   = "$($pn[$i]) Port" 
                }

                Write-Output "Installing printer."
                Add-Printer @printerArgs
                Write-Output "$($pn[$i]) added."
            }

            Write-Output "Printer installation complete."
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        Exit 0
    }
}

if (-Not(Get-Command 'Win_PrinterInstaller' -ErrorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
    PrinterNames    = $PrinterNames
    PrinterIPs      = $PrinterIPs
    DriverNames     = $DriverNames
    DriverLocations = $DriverLocations
    Force           = $Force
}

Win_PrinterInstaller @scriptArgs