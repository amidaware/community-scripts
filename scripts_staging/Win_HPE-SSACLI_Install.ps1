<#
.SYNOPSIS
   Install HPE SSACLI

.DESCRIPTION
   Downloads and installs HPE SSACLI

.PARAMETER Force (Optional)
   [Boolean] - Default:$False - Force a reinstall or downgrade

.OUTPUTS
   Exit Code: 0 = Pass, 1 = Informational, 2 = Warning, 3 = Error

.EXAMPLE
  Win_HPE-SSACLI_Install.ps1
   #No Parameters, defaults apply

.NOTES
   v1.0 12/5/2023 ConvexSERV
   Currently targetting version 4.21.7.0 of the HPE SSACLI (x64)
#>

param (
    [Boolean] $ForceInstall #Force a reinstall or downgrade
)

#Handle -ForceIntall Parameter
if (-not($ForceInstall)){
    $ArgumentList = "/s"
}
else {
    $ArgumentList = "/s /f"
}

try{
    Write-Host "Info - Downloading Installer..."
    Invoke-WebRequest -Uri "https://downloads.hpe.com/pub/softlib2/software1/sc-windows/p955544928/v183348/cp044527.exe" -UseBasicParsing -OutFile "c:\ProgramData\TacticalRMM\temp\cp044527.exe"
}
catch {
    $AlertText = "Alert - HPE_SSACLI Download Failed."
    Write-Host $AlertText
    $AlertLevel = 3
    $Host.SetShouldExit($AlertLevel)
    Exit
}

if (Test-Path "c:\ProgramData\TacticalRMM\temp\cp044527.exe") {
    
    Write-Host "Info - File Downloaded. Will attempt to install..."
        
    try {
        Write-Host "Installing..."
        Start-Process -NoNewWindow -FilePath "c:\ProgramData\TacticalRMM\temp\cp044527.exe" -ArgumentList '/s' -Wait
        Write-Host "Install completed. Check refresh installed software to verify."
    }
    catch {
        $AlertText = "Alert - HPE_SSACLI Install Failed."
        Write-Host $AlertText
        $AlertLevel = 3
        $Host.SetShouldExit($AlertLevel)
        Exit
    }
}
