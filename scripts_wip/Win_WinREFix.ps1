<#
.SYNOPSIS
    Move WinRE partition to end and increase size by 250MB every run.
.DESCRIPTION
    This script resolves the error caused by the January 1st 2024 update for KB5034441
#>
Write-Output "Diagnosing Windows RE Issues..."
Write-Output "Getting disk info"
$diskpart = [System.Text.StringBuilder]::new()
$osdisk = (Get-disk | Where-Object { $_.IsBoot }).Number
[void]$diskpart.AppendLine("sel disk $osdisk")
[void]$diskpart.AppendLine("list part")
Remove-Item diskpart.txt -ErrorAction SilentlyContinue | Out-Null
New-Item diskpart.txt | Out-Null
Add-Content diskpart.txt $diskpart.ToString()
$output = & diskpart /s diskpart.txt
$primaryPart = ( -split ($output -match "Primary"))[1]
$winREPart = ( -split ($output -match "Recovery"))[1]
$winRESize = ( -split ($output -match "Recovery"))[3]
$winREOffset = ( -split ($output -match "Recovery"))[5]
$winREOffsetType = ( -split ($output -match "Recovery"))[6]
Write-Output "WinRE Partition: Part: $winREPart - Size: $winRESize - Offset: $winREOffset - Type: $winREOffsetType"
if (-Not(Test-Path "C:\Windows\System32\Recovery\Winre.wim")) {
    Write-Output "WinRE image missing. Disabling RE Agent..."
    & reagentc /disable
}

if (-Not(Test-Path "C:\Windows\System32\Recovery\Winre.wim")) {
    Write-Error "WinRE image still missing. Download Recovery wim file to expected location..."
    exit 1
}
else {
    Write-Output "WinRE image available"
}

$diskInfo = ("list disk" | diskpart)
Write-Output "Fixing WinRE Drive Configuration..."
#check if gpt or mbr
[void]$diskpart.Clear()
[void]$diskpart.AppendLine("sel disk $osdisk")
if ($winREPart) {
    #has winre partition
    [void]$diskpart.AppendLine("sel part $winREPart")
    [void]$diskpart.AppendLine("delete partition override")
}

if ($diskInfo -match "\*") {
    Write-Output "Disk is GPT"
    [void]$diskpart.AppendLine("sel part $primaryPart")
    [void]$diskpart.AppendLine("shrink desired=250 minimum=250")
    [void]$diskpart.AppendLine("create partition primary id=de94bba4-06d1-4d40-a16a-bfd50179d6ac")
    [void]$diskpart.AppendLine("gpt attributes =0x8000000000000001")
    [void]$diskpart.AppendLine("format quick fs=ntfs label=`"Windows RE tools`"")
}
else {
    Write-Output "Disk is MBR"
    [void]$diskpart.AppendLine("sel part $primaryPart")
    [void]$diskpart.AppendLine("shrink desired=250 minimum=250")
    [void]$diskpart.AppendLine("create partition primary id=27")
    [void]$diskpart.AppendLine("format quick fs=ntfs label=`"Windows RE tools`"")
}

Clear-Content diskpart.txt
Add-Content diskpart.txt $diskpart.ToString()
$output = & diskpart /s diskpart.txt
Remove-Item diskpart.txt
$output

Write-Output "Enabling reagent..."
& reagentc /enable
& reagentc /info
Write-Output "System must be rebooted before patching."