# Checks Hardware for Smart Errors
# silversword notes: I've left this in wip because I've been working on a single answer to SMART. This is the dumbest of SMART errors that also constantly does windows gui errors to users constantly (and almost never show because this is the 8% of the time SMART is doing what it was intended to do. Warn on failure)

$ErrorActionPreference = 'silentlycontinue'
$smartst = (Get-WmiObject -namespace root\wmi -class MSStorageDriver_FailurePredictStatus).PredictFailure

if ($smartst = 'False') {
    Write-Output "Theres no SMART Failures predicted"
    exit 0
}


else {
    Write-Output "There are SMART Failures detected"
    exit 1
}
