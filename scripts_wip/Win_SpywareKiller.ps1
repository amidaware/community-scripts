<#
.SYNOPSIS
    Spyware killer script

.DESCRIPTION
    Death to all spyware! This scans for Wavebrowser, Onelaunch, and Webcompanion

.PARAMETER Days
    The number of days to look back for installers in the Downloads folder. Default is 1000.

.PARAMETER Autodelete
    Switch to enable or disable automatic deletion of installers found in the Downloads folder. When the switch is set, any matching files found will be automatically deleted without prompting. If the switch is not set, the files will not be deleted.

.PARAMETER Debug
    Switch to enable or disable debug output. When the switch is set, debug output will be enabled.

.EXAMPLE
    -Days 365 -Autodelete -Debug
    This will run the script looking back 365 days in the Downloads folder, automatically delete any installers found, and enable debug output.

.EXAMPLE
    -Days 180
    This will run the script looking back 180 days in the Downloads folder, but won't delete any files or enable debug output.

.NOTES
    v1.0 8/2022 silversword411
    Initial release for Wavebrowser
    v1.1 2/2023 silversword411
    Added Onelaunch
    v1.2 7/2023 silversword411
    Refining, adding debug output, adding autodelete switch, reformatting outlook for easier reading
    v1.3 and v1.42 /2024 silversword411
    Adding Webcompanion and Write-Debug
#>

param(
    [Int]$Days = "1000",
    [switch]$Autodelete,
    [switch]$debug
)

# For setting debug output level. -debug switch will set $debug to true
if ($debug) {
    $DebugPreference = "Continue"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
}

[Int]$ErrorCount = 0

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Debug "Days to scan: $Days"
if (!$Autodelete) {
    Write-Debug "Autodelete disabled"
}
else {
    Write-Debug "Autodelete enabled"
}

$currentuser = ((Get-WMIObject -ClassName Win32_ComputerSystem).Username).Split('\')[1]

If (!$currentuser) {    
    Write-Error "Noone currently logged in. Quitting"
    Exit 0
}
else {
    Write-Debug "Currently logged in user is: $currentuser"
}

function Wavebrowser-Scan {
    Write-Debug ""
    Write-Debug "################### Scanning for Wavebrowser ##################"
    $targetProgDir = "c:\users\$currentuser\Wavesor Software\"
    $targetDir = "c:\users\$currentuser\Downloads\"
    Write-Debug "targetDir is $targetDir"
    $pattern = "wave br*.exe"

    # Look for Wavebrowser installer in downloads folder
    Write-Debug "##########"
    If (!(get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-$Days)) })) {
        Write-Debug "No Wavebrowser installers in the downloads folder in the last $Days days"
    }
    else {
        Write-Output "WARNING-WARNING-WARNING - WaveBrowser installer found in downloads folder!"
        Get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-$Days)) } | ForEach-Object {
            if ($AutoDelete) {
                $_ | Remove-Item -Confirm:$false
            }
            else {
                Write-Output $_
            }
        }
        $script:ErrorCount += 1
        Write-Debug "ErrorCount increased. Total is $ErrorCount"
    }

    # Look for installed Wavebrowser
    Write-Debug "##########"
    If (!(get-ChildItem $targetProgDir)) {
        Write-Debug "No installed Wavebrowser"
    }
    else {
        Write-Output "WARNING - WaveBrowser was installed in c:\users\$currentuser\Wavesor Software\"
        $dirdate = (Get-Item "c:\users\$currentuser\Wavesor Software\").CreationTime
        Write-Debug "DirDate is $($dirdate)"
        $script:ErrorCount += 1
        Write-Debug "ErrorCount increased. Total is $ErrorCount"
    }
}
Wavebrowser-Scan

function Onelaunch-Scan {
    Write-Debug ""
    Write-Debug "################### Scanning for Onelaunch ##################"
    $targetProgDir = "c:\users\$currentuser\appdata\local\Onelaunch"
    $targetDir = "c:\users\$currentuser\Downloads\"
    Write-Debug "targetDir is $targetDir"
    $pattern = "onelaunch*.exe"

    # Look for Onelaunch installer in downloads folder
    Write-Debug "##########"
    If (!(get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-$Days)) })) {
        Write-Debug "No Onelaunch installers in the downloads folder in the last $Days days"
    }
    else {
        Write-Output "WARNING-WARNING-WARNING - Onelaunch installer found in downloads folder!"
        Get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-$Days)) } | ForEach-Object {
            if ($AutoDelete) {
                $_ | Remove-Item -Confirm:$false
            }
            else {
                Write-Output $_
            }
        }
        $script:ErrorCount += 1
        Write-Debug "ErrorCount increased. Total is $ErrorCount"
    }

    # Look for installed Onelaunch
    Write-Debug "##########"
    If (!(get-ChildItem $targetProgDir)) {
        Write-Debug "No installed Onelaunch"
    }
    else {
        Write-Debug "WARNING - OneLaunch was installed in c:\users\$currentuser\appdata\local\Onelaunch"
        $dirdate = (Get-Item "c:\users\$currentuser\appdata\local\Onelaunch").CreationTime
        Write-Debug "DirDate is $($dirdate)"
        $script:ErrorCount += 1
        Write-Debug "ErrorCount increased. Total is $ErrorCount"
    }
}
Onelaunch-Scan


function WebCompanion-Scan {
    Write-Debug ""
    Write-Debug "################### Scanning for Onelaunch ##################"
    $targetProgDir = "c:\users\$currentuser\appdata\local\Onelaunch"
    $targetDir = "c:\users\$currentuser\Downloads\"
    Write-Debug "targetDir is $targetDir"
    $pattern = "*Webcompanion.exe"

    # Look for WebCompanion installer in downloads folder
    Write-Debug "##########"
    If (!(get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-$Days)) })) {
        Write-Debug "No WebCompanion installers in the downloads folder in the last $Days days"
    }
    else {
        Write-Output "WARNING-WARNING-WARNING - WebCompanion installer found in downloads folder!"
        Get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-$Days)) } | ForEach-Object {
            if ($AutoDelete) {
                $_ | Remove-Item -Confirm:$false
            }
            else {
                Write-Output $_
            }
        }
        $script:ErrorCount += 1
        Write-Debug "ErrorCount increased. Total is $ErrorCount"
    }

    # Look for installed WebCompanion
    Write-Debug "##########"
    If (!(get-ChildItem $targetProgDir)) {
        Write-Debug "No installed WebCompanion"
    }
    else {
        Write-Output "WARNING - WebCompanion was installed in c:\users\$currentuser\appdata\local\Onelaunch"
        $dirdate = (Get-Item "c:\users\$currentuser\appdata\local\Onelaunch").CreationTime
        Write-Output "DirDate is $($dirdate)"
        $script:ErrorCount += 1
        Write-Debug "ErrorCount increased. Total is $ErrorCount"
    }
}
WebCompanion-Scan

Write-Debug ""
Write-Debug "Finished Tests"

if ($ErrorCount -gt 0) {
    Write-Debug "Total ErrorCount is $ErrorCount. +1 for every detection."
    Write-Output "Spyware was found. Take action."
    Exit 1
}
else {
    Write-Debug "Total ErrorCount is $ErrorCount."
    Write-Output "No spyware detected"
    Exit 0
}