<#
    .SYNOPSIS
        Using Events log "Veeam Agent", gets date of last backup and
    .DESCRIPTION
        Run it daily, it'll output Veeam version, and return 1 if last backup failed. Will also list last good backup
    .PARAMETERS
        -VeeamCheck {{agent.DisableVeeamCheck}}
    .NOTES
        2/2022 v1 Initial release by @silversword411
        If you want to be able to disable per-agent the check, create a custom field switch on agents and use the VeeamCheck variable
  #>

  param(
    [Int]$VeeamCheck
)

#$ErrorActionPreference= 'silentlycontinue'


# List last 20 Veeam Agent Log Items
# Get-EventLog "Veeam Agent" -newest 20 -After (Get-Date).AddDays(-1)

Write-Output "VeeamCheck: $VeeamCheck"

if ($VeeamCheck) {
    Write-Output "Veeam check disabled"
    Exit 0
}

if (Test-Path -Path "C:\Program Files\Veeam\Endpoint Backup") {
    Write-Output "Veeam Installed"
    $Path = "C:\Program Files\Veeam\Endpoint Backup\Veeam.Backup.Core.dll" # Path to Veeam.Backup.Core.dll by default it's located in C:\Program Files\Veeam\Backup and Replication\Backup\Veeam.Backup.Core.dll
    $Item = Get-Item -Path $Path
    $Item.VersionInfo.ProductVersion
#     $item.VersionInfo.FileVersion
    $item.VersionInfo.Comments
    $event = Get-EventLog "Veeam Agent" -newest 1 -After (Get-Date).AddDays(-1) | Where-Object { $_.InstanceID -eq 191 }
  
    if ($event.entrytype -eq "Warning") {
        write-Output "Latest Veeam Backup Failed"
        Get-EventLog "Veeam Agent" -newest 1 -After (Get-Date).AddDays(-1) | Format-List TimeGenerated, InstanceID, EntryType, Message
        write-Output "Last Successful Backup was"
        Get-EventLog "Veeam Agent" -EntryType Information,Warning -InstanceId 190 -newest 1 | Format-List TimeGenerated, InstanceID, EntryType, Message
        Exit 1
    }
    else {
        write-host "Veeam Backup ok, time of last backup:"
        Get-EventLog "Veeam Agent" -EntryType Information,Warning -InstanceId 190 -newest 1 | Format-List TimeGenerated
        Exit 0
    }
    
}
else {
    Write-Output "Veeam not Installed"
    exit 0
}
