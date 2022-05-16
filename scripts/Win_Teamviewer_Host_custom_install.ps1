<#
.SYNOPSIS
    Installs TeamViewer Host customized with API and CustomID, only TeamViewer Corporate.

.REQUIREMENTS
    You will need API and custom ID to use this script.
    You will need to upload TeamViewer Host msi on a web url

.INSTRUCTIONS
    1. Create TeamViewer Customized Host with assignment of Host.
    2. Take notes of token of assignation and of configuration ID.
    3. Download MSI file and upload it on your website.
    4. In Tactical RMM, Global Settings -> Custom Fields, create custom fields for clients, so that you can create customized hosts for clients and not for users.
    5. Fill in:
        a) TeamViewerAPI -> Text
        b) CUSTOMIDTW -> Text
        c) LinkMSITW -> Text -> the only to fill in on global settings with your link to MSI, this will be the same for all clients.
    6. Compile for clients:
        a) TeamViewerAPI with token of assignation.
        b) CUSTOMIDTW with custom ID.
    7. Now when you will launch the script it will install TeamViewer customized Host with auto assignation and easy access already activated.

.NOTES
	V1.0 Initial Release
	
#>
param (
   [string] $urlmsitw,
   [string] $customidtw,
   [string] $apitw
)

if ([string]::IsNullOrEmpty($urlmsitw)) {
    throw "URL must be defined. Use -urlmsitw <value> to pass it."
}
if ([string]::IsNullOrEmpty($customidtw)) {
    throw "Custom ID must be defined. Use -customidtw <value> to pass it."
}
if ([string]::IsNullOrEmpty($apitw)) {
    throw "API must be defined. Use -apitw <value> to pass it."
}
Write-Host "Running TeamViewer Host customized with API on: $env:COMPUTERNAME"

    Write-Host "Checking if TeamViewer Host is installed.  Please wait..."
    $installedSoftware = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*teamviewer*"}
if ($installedSoftware){
if (Select-String -InputObject $installedSoftware.DisplayName -Pattern "Host"){
Write-Host "Host Client Version is installed. Converting Host."
Set-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\TeamViewer" -Name "InstallationConfigurationId" -Type String -Value $customidtw
Write-Host "Closing TeamViewer Host."
Taskkill /IM teamviewer.exe /F
Write-Host "Opening and setting TeamViewer Host."
$dirtw = ${env:ProgramFiles(x86)} + '\TeamViewer\TeamViewer.exe'
Start-Process $dirtw -ArgumentList "assign --api-token $apitw --reassign --alias $ENV:COMPUTERNAME --grant-easy-access"
Write-Host "Installation of TeamViewer Host completed."
}
else{
Write-Host "Full Client Version is installed. Skipping installation."
}
Write-host "installed version is" $installedSoftware.VersionMajor
}
else {
    Write-Host "TeamVIewer Host is NOT installed. Installing now..."
    Write-Host "Downloading TeamViewer Host from " + $urlmsitw + " Please wait..." 
    $tmpDir = [System.IO.Path]::GetTempPath()
    $outpath = $tmpDir + "TeamViewer_Host.msi"
    Write-Host "Saving file to " + $outpath
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $urlmsitw -OutFile $outpath
    Write-Host "Running TeamViewer Host Setup... Please wait up to 10 minutes for install to complete." 
    msiexec.exe /i $outpath /qn CUSTOMCONFIGID=$customidtw APITOKEN=$apitw ASSIGNMENTOPTIONS="--grant-easy-access"
	Write-Host "Installation of TeamViewer Host completed."
}
