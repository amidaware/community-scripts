<#
.SYNOPSIS
    Take screenshot of currently logged in user.

.DESCRIPTION
    This script captures a screenshot of the currently logged in user's screen. Will not work on RDS with multiple sessions.

.PARAMETER removeFolder
    Removes the screenshots folder and quits.

.PARAMETER single
    Specifies whether to remove old screenshots before taking a new one.

.EXAMPLE
    -single
    Captures a screenshot of the currently logged in user's screen and removes any existing screenshots.

.EXAMPLE
    -removeFolder
    Removes the screenshots folder

    .NOTES
    Version: 1.0 The screenshots are saved in the TacticalRMM scripts/screenshots directory.
    TODO: Get opinion on Set-ExecutionPolicy -ExecutionPolicy $curpsxpol file and should it be left behind?
#>

param (
    [switch]$single,
    [switch]$removeFolder
)

# Remove the screenshots folder
if ($removeFolder) {
    Remove-Item -Path "$env:programdata\TacticalRMM\scripts\screenshots\" -Recurse -Force
    Exit 0
}

if (Get-PackageProvider -Name NuGet) {
    Write-Output "NuGet Already Installed"
} 
else {
    Write-Host "Installing NuGet"
    Install-PackageProvider -Name NuGet -Force
} 
 
if (Get-Module -ListAvailable -Name RunAsUser) {
    Write-Output "RunAsUser Already Installed"
} 
else {
    Write-Output "Installing RunAsUser"
    Install-Module -Name RunAsUser -Force
}

If (!(test-path "$env:programdata\TacticalRMM\scripts\screenshots\")) {
    New-Item -ItemType Directory -Force -Path "$env:programdata\TacticalRMM\scripts\screenshots\"
}

If (!(test-path "$env:programdata\Tactical RMM\temp\curpsxpolicy.txt")) {
    $curexpolicy = Get-ExecutionPolicy

    (
        Write-Output $curexpolicy
    )>"$env:programdata\TacticalRMM\scripts\curpsxpolicy.txt"
}
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell -Name ExecutionPolicy -Value Unrestricted

if ($Clean) {
    Remove-Item "$env:programdata\TacticalRMM\scripts\screenshots\*.png"
}

Invoke-AsCurrentUser -scriptblock {
    $File = 'C:\TacticalRMM\temp\Screenshot1.bmp'

    Add-Type -AssemblyName System.Windows.Forms
    Add-type -AssemblyName System.Drawing

    # Gather Screen resolution information
    $Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen

    # Create bitmap using the top-left and bottom-right bounds
    $bitmap = New-Object System.Drawing.Bitmap $Screen.Width, $Screen.Height

    # Create Graphics object
    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)

    # Capture screen
    $graphic.CopyFromScreen($Screen.Left, $Screen.Top, 0, 0, $bitmap.Size)

    # Save to file
    $screen_file = "$env:programdata\TacticalRMM\scripts\screenshots\" + $env:computername + "_" + $env:username + "_" + "$((get-date).tostring('yyyy.MM.dd-HH.mm.ss')).png"
    $bitmap.Save($screen_file, [System.Drawing.Imaging.ImageFormat]::Png)
}

Write-Output "Successfully saved screenshot"

$curpsxpol = Get-Content -Path "$env:programdata\TacticalRMM\scripts\curpsxpolicy.txt";
    
Set-ExecutionPolicy -ExecutionPolicy $curpsxpol

