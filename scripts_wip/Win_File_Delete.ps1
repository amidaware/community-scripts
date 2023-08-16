param (
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

$currentuser = ((Get-WMIObject -ClassName Win32_ComputerSystem).Username).Split('\')[1]

If (!$currentuser) {    
    Write-Debug "Noone currently logged in"
    Exit 0
}
else {
    Write-Debug "Currently logged in user is: $currentuser"
}
    
$targetDir = "c:\Users\$($currentuser)\Downloads\"
Write-Debug "targetDir is $targetDir"
$pattern = "PC_Support.Client*.exe"
$filesToDelete = Get-ChildItem $targetDir | Where-Object { ($_.name -like $pattern) -and ($_.CreationTime -gt (Get-Date).AddDays(-5000)) }

If (!$filesToDelete) {
    Write-Output "No $pattern files in the last 5000 days"
}
else {
    Write-Output $filesToDelete
        
    # Delete the detected files
    $filesToDelete | ForEach-Object {
        Write-Output ("Deleting file: " + $_.FullName)
        Remove-Item $_.FullName -Force
        Exit 1
    }
}
Write-Output "Finished Run"
