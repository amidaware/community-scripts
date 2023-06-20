<#
    .SYNOPSIS
    Checks windows laptop for battery health

    .DESCRIPTION 
    This script will check the DesignCapacity and the FullChargeCapacity and determine the percentage of battery health left. 

    .OUTPUTS
    The script will return the obtained values and the battery health in a percentage and then write "Battery health is {greak,ok,low,critical}"

    Exit codes are:

    0 great
    1 ok
    2 low
    3 critical

    .EXAMPLE
    Battery life report saved to file path C:\Windows\TEMP\batteryreport.xml.

    DesignCapacity     : 75998
    FullChargeCapacity : 60640
    BatteryHealth      : 79
    CycleCount         : 0
    Id                 : ASUS Battery

    Battery Health is Great

    .NOTES
    Thanks to Jay Hill for the forum post that gave me this code. I just added the exit codes.
    https://learn.microsoft.com/en-us/answers/questions/666760/using-powershell-to-get-a-battery-health-report-wi 
#>

$InfoAlertPercent = "70"
$WarnAlertPercent = "50"
$CritAlertPercent = "20"
$BatteryHealth=""
& powercfg /batteryreport /XML /OUTPUT "batteryreport.xml"
Start-Sleep 1
[xml]$b = Get-Content batteryreport.xml

$b.BatteryReport.Batteries |
    ForEach-Object{
        [PSCustomObject]@{
            DesignCapacity = $_.Battery.DesignCapacity
            FullChargeCapacity = $_.Battery.FullChargeCapacity
            BatteryHealth = [math]::floor([int64]$_.Battery.FullChargeCapacity/[int64]$_.Battery.DesignCapacity*100)
            CycleCount = $_.Battery.CycleCount
            Id = $_.Battery.id
        }

        if (([int64]$_.Battery.FullChargeCapacity/[int64]$_.Battery.DesignCapacity)*100 -gt $InfoAlertPercent){
            $BatteryHealth="Great"
            write-host "Battery Health is $BatteryHealth"
            exit 0
        }elseif (([int64]$_.Battery.FullChargeCapacity/[int64]$_.Battery.DesignCapacity)*100 -and ([int64]$_.Battery.FullChargeCapacity/[int64]$_.Battery.DesignCapacity)*100 -gt $WarnAlertPercent){
            $BatteryHealth="OK"
            write-host "Battery Health is $BatteryHealth"
            exit 1
        }elseif (([int64]$_.Battery.FullChargeCapacity/[int64]$_.Battery.DesignCapacity)*100 -and ([int64]$_.Battery.FullChargeCapacity/[int64]$_.Battery.DesignCapacity)*100 -gt $CritAlertPercent){
            $BatteryHealth="Low"
            write-host "Battery Health is $BatteryHealth"
            exit 2
        }elseif (([int64]$_.Battery.FullChargeCapacity/[int64]$_.Battery.DesignCapacity)*100 -le $CritAlertPercent){
            $BatteryHealth="Critical"
            write-host "Battery Health is $BatteryHealth"
            exit 3
        }
    }
