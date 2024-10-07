# Script information
Write-Host ""
Write-Host "Author: Sunny Patel"
Write-Host "Date Created: July 03, 2024 ~ Date Modified: July 12, 2024"
Write-Host ""

# Function to write output with color
function Write-Color {
    param (
        [string]$message,
        [ConsoleColor]$color
    )
    $currentColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $color
    Write-Host $message
    $Host.UI.RawUI.ForegroundColor = $currentColor
}

# Function to check if the script is running with admin rights
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if the script is running with admin rights
if (-not (Test-AdminRights)) {
    Write-Host "Script requires elevated privileges. Please enter administrator credentials."

    # Get the current script path
    $scriptPath = $MyInvocation.MyCommand.Path

    # Restart the script with elevated privileges
    Start-Process powershell.exe -ArgumentList "-executionpolicy bypass -File `"$scriptPath`"" -Verb RunAs

    # Exit the current non-elevated script
    Exit
}

# ASCII art function
function Show-ASCIIArt {
    @"
▐▓█▀▀▀▀▀▀▀▀▀█▓▌░▄▄▄▄▄░
▐▓█░░▀░░▀▄░░█▓▌░█▄▄▄█░
▐▓█░░▄░░▄▀░░█▓▌░█▄▄▄█░
▐▓█▄▄▄▄▄▄▄▄▄█▓▌░█████░
░░░░▄▄███▄▄░░░░░█████░


░██████╗██╗░░░██╗███╗░░██╗███╗░░██╗██╗░░░██╗██╗░██████╗  ██╗░░░██╗░██████╗███████╗██████╗░
██╔════╝██║░░░██║████╗░██║████╗░██║╚██╗░██╔╝╚█║██╔════╝  ██║░░░██║██╔════╝██╔════╝██╔══██╗
╚█████╗░██║░░░██║██╔██╗██║██╔██╗██║░╚████╔╝░╚╝╚█████╗░  ██║░░░██║╚█████╗░█████╗░░██████╔╝
░╚═══██╗██║░░░██║██║╚████║██║╚████║░░╚██╔╝░░░░░░╚═══██╗  ██║░░░██║░╚═══██╗██╔══╝░░██╔══██╗
██████╔╝╚██████╔╝██║░╚███║██║░╚███║░░░██║░░░░░░██████╔╝  ╚██████╔╝██████╔╝███████╗██║░░██║
╚═════╝░╚═════╝░╚═╝░░╚══╝╚═╝░░╚══╝░░░╚═╝░░░░░░╚═════╝░  ░╚═════╝░╚═════╝░╚══════╝╚═╝░░╚═╝

██████╗░███████╗██╗░░░░░███████╗████████╗██╗░█████╗░███╗░░██╗  ████████╗░█████╗░░█████╗░██╗░░░░░
██╔══██╗██╔════╝██║░░░░░██╔════╝╚══██╔══╝██║██╔══██╗████╗░██║  ╚══██╔══╝██╔══██╗██╔══██╗██║░░░░░
██║░░██║█████╗░░██║░░░░░█████╗░░░░░██║░░░██║██║░░██║██╔██╗██║  ░░░██║░░░██║░░██║██║░░██║██║░░░░░
██║░░██║██╔══╝░░██║░░░░░██╔══╝░░░░░██║░░░██║██║░░██║██║╚████║  ░░░██║░░░██║░░██║██║░░██║██║░░░░░
██████╔╝███████╗███████╗███████╗░░░██║░░░██║╚█████╔╝██║░╚███║  ░░░██║░░░╚█████╔╝╚█████╔╝███████╗
╚═════╝░╚══════╝╚══════╝╚══════╝░░░╚═╝░░░╚═╝░╚════╝░╚═╝░░╚══╝  ░░░╚═╝░░░░╚════╝░░╚════╝░╚══════╝

██████╗░░░░░░███╗░░
╚════██╗░░░░████║░░
░░███╔═╝░░░██╔██║░░
██╔══╝░░░░░╚═╝██║░░
███████╗██╗███████╗
╚══════╝╚═╝╚══════╝

"@
}

# Display ASCII art
Show-ASCIIArt

# Function to show progress bar
function Show-ProgressBar {
    param (
        [string]$activity,
        [int]$status,
        [int]$total,
        [string]$currentUser
    )
    $percentComplete = [math]::Round(($status / $total) * 100)
    $remainingUsers = $total - $status
    Write-Progress -Activity $activity -Status "$percentComplete% Complete: $status/$total Users Processed. Current: $currentUser, Remaining: $remainingUsers" -PercentComplete $percentComplete
}

# Function to remove user registry entries
function Remove-UserRegistry {
    param (
        [string]$sid
    )
    $registries = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
    )
    foreach ($reg in $registries) {
        try {
            Remove-Item -Path $reg -Recurse -ErrorAction Stop
            Write-Color "Removed registry entry: $reg" -color Green
        }
        catch {
            Write-Color "Failed to remove registry entry: $reg - $_" -color Red
        }
    }
}

# Function to remove user folders
function Remove-UserFolders {
    param (
        [string]$folderPath
    )
    try {
        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction Stop
        Write-Color "Removed user folder: $folderPath" -color Green
    }
    catch {
        Write-Color "Failed to remove user folder: $folderPath - $_" -color Red
    }
}

# Function to check disk space
function Check-DiskSpace {
    $drive = Get-PSDrive -Name C
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
    Write-Color "Available Disk Space: $freeSpaceGB GB" -color Cyan
    if ($freeSpaceGB -lt 10) {
        Write-Color "Warning: Low disk space. Consider freeing up space before proceeding." -color Red
    }
}

# Function to monitor resource usage
function Monitor-Resources {
    $cpu = Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
    $memory = Get-WmiObject Win32_OperatingSystem | Select-Object @{Name = "FreeMemory"; Expression = { $_.FreePhysicalMemory / 1024 } }, @{Name = "TotalMemory"; Expression = { $_.TotalVisibleMemorySize / 1024 } }
    $usedMemory = [math]::Round($memory.TotalMemory - $memory.FreeMemory, 2)
    Write-Color "Resource Usage: CPU Load: $cpu%, Memory Usage: $usedMemory MB" -color Cyan
}

# Function to calculate folder size
function Get-FolderSize {
    param (
        [string]$folderPath
    )
    try {
        $size = (Get-ChildItem -Path $folderPath -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum
        return [math]::Round($size / 1MB, 2)
    }
    catch {
        return "Error calculating size"
    }
}

# Function to get the current logged-in user
function Get-LoggedInUser {
    try {
        $loggedInUser = (query user | Select-String -Pattern ">" | ForEach-Object { $_.ToString().Split()[0] }).Trim()
        return $loggedInUser
    }
    catch {
        return "Unknown"
    }
}

# Start the timer
$startTime = Get-Date

# Check disk space before starting
Check-DiskSpace

# Display initial disclaimer and instructions
Write-Host ""
Write-Color "DISCLAIMER: This script will delete user profiles and their associated data." -color Yellow
Write-Color "Make sure you have backups of important data before proceeding." -color Yellow
Write-Host ""
Write-Color "Press any key to continue..." -color Yellow
[void]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Prompt the user to enter the usernames that should not be deleted
$usersToKeep = Read-Host "Enter the usernames (comma-separated) that should not be deleted"
$usersToKeepArray = $usersToKeep -split "," | ForEach-Object { $_.Trim() }

# Define the hardcoded usernames to keep
$hardcodedUsers = @("sunny.patel", "sunny.j.patel", "Public", "public", "Default", "NetworkService", "LocalService", "systemprofile", "cw.it", "Administrator")

# Combine the hardcoded usernames with the user input
$allUsersToKeep = $hardcodedUsers + $usersToKeepArray

# Get the current logged-in user
$loggedInUser = Get-LoggedInUser
if ($loggedInUser -ne "Unknown") {
    $keepCurrentUser = Read-Host "The script has detected the current logged in user is $loggedInUser. Would you like to keep their profile? (Y/N)"
    if ($keepCurrentUser -match "^(y|Y)$") {
        $allUsersToKeep += $loggedInUser
    }
}

# Display all the profiles to be kept
Write-Host ""
Write-Color "The following user profiles will be kept:" -color Cyan
$allUsersToKeep | ForEach-Object {
    Write-Color "  $_" -color Green
}
Write-Host ""
Write-Color "Press any key to start the deletion process..." -color Yellow
[void]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Arrays to store users removed and kept
$removedUsers = @()
$keptUsers = @()

# Track errors
$errors = @()

# Get the user profiles and filter out the ones to keep, then remove the rest
$userProfiles = Get-CimInstance -Class Win32_UserProfile
$totalUsers = $userProfiles.Count
$currentUserIndex = 0

# Display pre-check information
Write-Host ""
Write-Color "Pre-check Information:" -color Cyan
Write-Color "Total user profiles found: $totalUsers" -color Cyan
Write-Color "User profiles to be kept: $($allUsersToKeep -join ', ')" -color Cyan
Write-Host ""

Write-Color "Starting deletion process..." -color Green

$userProfiles | ForEach-Object {
    $localPathUser = $_.LocalPath.Split('\')[-1]
    if ($allUsersToKeep -contains $localPathUser) {
        $keptUsers += $localPathUser
    }
    else {
        $removedUsers += $localPathUser

        # Show progress bar
        Show-ProgressBar -activity "Removing user profiles" -status $currentUserIndex -total $totalUsers -currentUser $localPathUser
        
        Write-Color "Removing user: $localPathUser" -color Red
        Write-Color "  SID: $($_.SID)" -color Yellow
        Write-Color "  LocalPath: $($_.LocalPath)" -color Yellow
        Write-Color "  Last Use Time: $($_.LastUseTime)" -color Cyan

        # Get and display folder size
        $folderSize = Get-FolderSize -folderPath $_.LocalPath
        Write-Color "  Folder Size: $folderSize MB" -color Magenta

        try {
            Remove-CimInstance $_
            Write-Color "Removed user profile: $localPathUser" -color Red
            
            # Remove registry entries
            Remove-UserRegistry -sid $_.SID

            # Remove user folders
            Remove-UserFolders -folderPath $_.LocalPath
        }
        catch {
            $errors += "Failed to remove user: $localPathUser - $_"
            Write-Color "Failed to remove user: $localPathUser - $_" -color Red
        }
    }
    $currentUserIndex++
    # Monitor resources during the process
    Monitor-Resources
}

# Display the kept users and users not found
Write-Host ""
Write-Color "Users kept or not found:" -color Cyan
$allUsersToKeep | ForEach-Object {
    if ($keptUsers -contains $_) {
        Write-Color "  Kept: $_" -color Green
    }
    else {
        Write-Color "  Not found: $_" -color Magenta
    }
}

# Display the removed users
Write-Host ""
Write-Color "Users removed:" -color Cyan
$removedUsers | ForEach-Object {
    Write-Color "  $_" -color Red
}

# Display errors if any
if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Color "Errors encountered during the process:" -color Red
    $errors | ForEach-Object {
        Write-Color "  $_" -color Red
    }
}

# Summary
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Color "Summary:" -color Cyan
Write-Color "  Total Users Processed: $totalUsers" -color Cyan
Write-Color "  Total Users Removed: $($removedUsers.Count)" -color Cyan
Write-Color "  Total Users Kept: $($keptUsers.Count)" -color Cyan
Write-Color "  Total Errors: $($errors.Count)" -color Cyan
Write-Color "  Execution Time: $($duration.TotalMinutes) minutes" -color Cyan

# Check disk space after completion
Write-Color "Disk space after deletion:" -color Cyan
Check-DiskSpace

Write-Host ""
Write-Color "Process completed. You can now close this window." -color Green

# Pause before closing
Write-Color "Press any key to exit..." -color Yellow
[void]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
