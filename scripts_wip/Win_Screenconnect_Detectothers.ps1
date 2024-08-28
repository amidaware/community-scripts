<#

.NOTES
    v1.6 silversword411 Making into a function
    v1.7 silversword411 Adding Custom Field AuditSCOtherDisable Disables check

TODO: Add detection of other remote access systems
-AuditSCOtherDisable {{agent.AuditSCOtherDisable}}
#>
param (
    [string] $SCURLtocheck, # The URL to check against the service path
    [Int] $AuditSCOtherDisable, # Disable
    [switch] $debug
)

# check for Win7 and exit if true
$OSVersion = (Get-WmiObject Win32_OperatingSystem).Version
if ($OSVersion.StartsWith("6.1")) {
    Write-Output "Running on Windows 7. Exiting..."
    Exit
}

# See if Custom Field has disabled AuditSCOtherDisable
Write-Debug "AuditSCOtherDisable: $AuditSCOtherDisable"
if ($AuditSCOtherDisable) {
    Write-Output "Other SC check disabled."
    Exit 0
}

function Check-SCServicePath {

    Write-Output "################# Check ScreenConnect Service Path #################"

    # For setting debug output level. -debug switch will set $debug to true
    if ($debug) {
        $DebugPreference = "Continue"
        $ErrorActionPreference = 'Continue'
        Write-Debug "Debug mode enabled"
    }
    else {
        $DebugPreference = "SilentlyContinue"
        $ErrorActionPreference = 'SilentlyContinue'
    }

    # Get all ScreenConnect services
    $SCServices = Get-Service | Where-Object { $_.Name -match "ScreenConnect Client*" }

    $servicesNotContainingUrl = @()

    foreach ($service in $SCServices) {
        $serviceDetail = Get-CimInstance -ClassName Win32_Service -Filter "Name = '$($service.Name)'"
        if ($serviceDetail.PathName -notlike "*$SCURLtocheck*") {
            $servicesNotContainingUrl += $service
        }
    }

    if ($servicesNotContainingUrl.Count -gt 0) {
        Write-Output "WARNING: ScreenConnect services do not contain '$SCURLtocheck' in their path."

        foreach ($service in $servicesNotContainingUrl) {
            $serviceDetail = Get-CimInstance -ClassName Win32_Service -Filter "Name = '$($service.Name)'"
            Write-Debug "serviceDetail: $serviceDetail"
            $path = $serviceDetail.PathName
            Write-Debug "Path: $path"
            # Extract the text between "&h=" and "&p"
            $startIndex = $path.IndexOf("&h=") + 3
            if ($startIndex -gt 2) {
                # Check if "&h=" exists
                $endIndex = $path.IndexOf("&p", $startIndex)
                if ($endIndex -gt $startIndex) {
                    # Check if "&p" exists after "&h="
                    $extractedText = $path.Substring($startIndex, $endIndex - $startIndex)
                    Write-Output "Other SC server URLs: $($extractedText)"
                }
            }
        }
        Exit 1
    }
    else {
        Write-Output "AllGood: All ScreenConnect services contain '$SCURLtocheck' in their path."
    }
}

Check-SCServicePath