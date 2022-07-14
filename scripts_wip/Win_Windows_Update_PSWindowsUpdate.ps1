# http://woshub.com/pswindowsupdate-module/

<# 
Clear-WUJob – use the Get-WUJob to clear the WUJob in Task Scheduler;
Download-WindowsUpdate (alias for Get-WindowsUpdate –Download) — get a list of updates and download them;
Get-WUInstall, Install-WindowsUpdate (alias for Get-WindowsUpdate –Install) – install Windows updates;
Uninstall-WindowsUpdate – remove update using the Remove-WindowsUpdate;
Add-WUServiceManager – register the update server (Windows Update Service Manager) on the computer;
Enable-WURemoting — enable Windows Defender firewall rules to allow remote use of the PSWindowsUpdate cmdlets;
Get-WindowsUpdate (Get-WUList) — displays a list of updates that match the specified criteria, allows you to find and install the updates. This is the main cmdlet of the PSWindowsUpdate module. Allows to download and install updates from a WSUS server or Microsoft Update. Allows you to select update categories, specific updates and set the rules of a computer restart when installing the updates;
Get-WUApiVersion – get the Windows Update Agent version on the computer;
Get-WUHistory – display a list of installed updates (update history);
Get-WUInstallerStatus — check the Windows Installer service status;
Get-WUJob – check for WUJob update tasks in the Task Scheduler;
Get-WUSettings – get Windows Update client settings;
Invoke-WUJob – remotely call WUJobs task in the Task Scheduler to immediately execute PSWindowsUpdate commands;
Remove-WUServiceManager – disable Windows Update Service Manager;
Set-PSWUSettings – save PSWindowsUpdate module settings to the XML file;
Set-WUSettings – configure Windows Update client settings;
Update-WUModule – update the PSWindowsUpdate module (you can update the module on a remote computer by copying it from the current one, or updating from PSGallery);
Reset-WUComponents – allows you to reset the Windows Update agent on the computer to the default state.
 #>


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (Get-PackageProvider -Name NuGet) {
    Write-Output "NuGet Already Installed"
} 
else {
    Write-Output "Installing NuGet"
    Install-PackageProvider -Name NuGet -Force
} 

if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
    #Get-Updates
    Write-Output "Got PSWindowsUpdate"

}
else {
    Install-PackageProvider -Name NuGet -Force
    Install-Module -Name PSWindowsUpdate -Force
    Get-Updates

}


Install-Module -Name PSWindowsUpdate 

# TODO: parameterize
# See all commands (Get-Command) available for the PSWindowsUpdate module
Get-Command -Module PSWindowsUpdate



# Checking for Available Windows Updates
Get-WindowsUpdate


# Perhaps you also want to check where Windows gets an update from to see if the source is trustworthy
# Microsoft Update – the standard update source
# DCat Flighting Prod – an alternative MS supdate ource for specific flighted update items (from previews, etc)
# Windows Store (DCat Prod) – normally just Windows Store, but has Dcat Prod when for insider preview PC
# Windows Update – an older update source for Windows Vista and older Windows OS.
Get-WUServiceManager


# Excluding Windows Updates from Installing
Hide-WindowsUpdate -KBArticleID KB4052623


# But before installing updates, checking if updates require a system reboot is a good practice. Why? Knowing whether the Windows updates require a reboot beforehand tells you to save all your work and complete other ongoing installations before diving to the Windows update.
Get-WURebootStatus


# Downloading and Installing All Available Updates
Install-WindowsUpdate -AcceptAll -AutoReboot


# Checking Windows Update History
Get-WUHistory


# dates of the last search and installation of updates (LastSearchSuccessDate and LastInstallationSuccessDate);
Get-WULastResults


# Uninstalling Windows Updates by KB ID
Remove-WindowsUpdate -KBArticleID KB2267602

