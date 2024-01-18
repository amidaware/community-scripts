<#
.SYNOPSIS
    Sets the registry setting to force office to clear the local cache of files.
.DESCRIPTION
    The reason this script exists is to force applications to pull the cloud version
    of a file instead of using the local cache version for files in OneDrive.
.NOTES
    Version: 1.0
    Author: redanthrax
    Creation Date: 2024-01-18
#>

$sids = Get-ChildItem -Path Registry::HKEY_USERS | `
    Where-Object { $_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$' } | `
    ForEach-Object { $_.Name }
$count = 0
foreach ($sid in $sids) {
    if (Test-Path "Registry::$sid\Software\Microsoft\Office\16.0\Common") {
        $options = @{
            Path  = "Registry::$sid\Software\Microsoft\Office\16.0\Common\FileIO"
            Name  = 'AgeOutPolicy'
            Value = '1'
        }

        Set-ItemProperty @options
        $options["Name"]  = 'DisableLongTermCaching'
        Set-ItemProperty @options
        $count += 1
    }
}

Write-Output "Execution complete. Set for $count user(s)."