#Install Winget if missing

#Setup
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#Setup temp folder
$InstallerFolder = "c:\temp"
if (!(Test-Path $InstallerFolder)) {
    New-Item -Path $InstallerFolder -ItemType Directory -Force -Confirm:$false
}

#If Visual C++ Redistributable 2022 not present, download and install. (Winget Dependency)
if (Get-WmiObject -Class Win32_Product -Filter "Name LIKE '%Visual C++ 2022%'") {
    Write-Host "VC++ Redistributable 2022 already installed"
}
else {
    Write-Host "Installing Visual C++ Redistributable"
    #Permalink for latest supported x64 version
    Invoke-Webrequest -uri https://aka.ms/vs/17/release/vc_redist.x64.exe -Outfile $InstallerFolder\vc_redist.x64.exe
    Start-Process "$InstallerFolder\vc_redist.x64.exe" -Wait -ArgumentList "/q /norestart"
}

#Check Winget Install
$TestWinget = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "Microsoft.DesktopAppInstaller" }
If ([Version]$TestWinGet. Version -gt "2022.506.16.0") {
    Write-Host "WinGet is already installed" -ForegroundColor Green
}
Else {
    #Download WinGet MSIXBundle
    Write-Host "Winget is not installed. Downloading WinGet..." 
    Invoke-Webrequest -uri https://aka.ms/getwinget -Outfile $InstallerFolder\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
    
    #Install WinGet MSIXBundle 
    Try {
        Write-Host "Installing MSIXBundle for App Installer..." 
        Add-AppxProvisionedPackage -Online -PackagePath "$InstallerFolder\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -SkipLicense 
        Write-Host "Installed MSIXBundle for App Installer" -ForegroundColor Green
    }
    Catch {
        Write-Host "Failed to install MSIXBundle for App Installer..." -ForegroundColor Red
    }   
}

#Remove downloaded files
if (Test-Path "$InstallerFolder\vc_redist.x64.exe") {
    Remove-Item -Path "$InstallerFolder\vc_redist.x64.exe" -Force -ErrorAction Continue
}
if (Test-Path "$InstallerFolder\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle") {
    Remove-Item -Path "$InstallerFolder\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -Force -ErrorAction Continue
}

Start-Sleep -seconds 5
#Find the Winget path, and peel off winget.exe
$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
if ($null -eq $ResolveWingetPath) {
    write-host "ERROR: Winget path was not found."
    exit 1
}
$WingetPath = $ResolveWingetPath[-1].Path
$WingetPath = Split-Path -Path $WingetPath -Parent

#Add Winget to the System path environment variable if it doesn't exist
if ([Environment]::GetEnvironmentVariable("PATH", "Machine") -notlike "*$WingetPath*") {
  
    #Set system path environment variable
    $SystemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine") + [IO.Path]::PathSeparator + $WingetPath
    [Environment]::SetEnvironmentVariable( "Path", $SystemPath, "Machine" )
 
    #Check if path successfully added
    if ([Environment]::GetEnvironmentVariable("PATH", "Machine") -like "*$WingetPath*") {
        Write-Host "Successfully added winget to the Environment Variables for System Path.  Computer must be rebooted before this takes effect."
        exit
    }
    else {
        Write-Host "Failed to add winget to the Environment Variables for System Path"
        exit 1
    }    
}
Write-Host "Environment Variable for system path already exists for winget."