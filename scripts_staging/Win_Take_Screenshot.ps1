## Take screenshot of curently logged in user, will not work on RDS with multiple sessions

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

If (!(test-path "$env:programdata\TRMMScripts\screenshots\")) {
    New-Item -ItemType Directory -Force -Path "$env:programdata\TRMMScripts\screenshots\"
}

If (!(test-path "$env:programdata\Tactical RMM\temp\curpsxpolicy.txt")) {
    $curexpolicy = Get-ExecutionPolicy

    (
        Write-Output $curexpolicy
    )>"$env:programdata\TRMMScripts\curpsxpolicy.txt"
}
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell -Name ExecutionPolicy -Value Unrestricted

#Remove old screenshots before taking a new one
Remove-Item "$env:programdata\TRMMScripts\screenshots\*.png"

Invoke-AsCurrentUser -scriptblock {
$File = 'C:\temp\Screenshot1.bmp'

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
$screen_file = "$env:programdata\TRMMScripts\screenshots\" + $env:computername + "_" + $env:username + "_" + "$((get-date).tostring('yyyy.MM.dd-HH.mm.ss')).png"
$bitmap.Save($screen_file, [System.Drawing.Imaging.ImageFormat]::Png)
}

Write-Output "Successfully saved screenshot"

$curpsxpol = Get-Content -Path "$env:programdata\TRMMScripts\curpsxpolicy.txt";
    
Set-ExecutionPolicy -ExecutionPolicy $curpsxpol

