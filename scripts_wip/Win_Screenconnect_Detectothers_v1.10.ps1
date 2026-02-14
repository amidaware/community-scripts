<#

.NOTES
    v1.6 silversword411 Making into a function
    v1.7 silversword411 Adding Custom Field AuditSCOtherDisable Disables check
    v1.8 silversword411 Adding debug output for ScreenConnect service names only
    v1.9 silversword411 Adding function to remove invalid ScreenConnect services
    v1.10 silversword411 Get-WmiObject : Invalid class "Win32_OperatingSystem"

-AuditSCOtherDisable {{agent.AuditSCOtherDisable}}
-deleteInvalid
#>
param (
    [string] $SCURLtocheck, # The URL to check against the service path
    [Int] $AuditSCOtherDisable, # Disable check
    [switch] $debug,
    [switch] $deleteInvalid # If enabled, deletes non-matching ScreenConnect services
)

if ($debug) {
    $DebugPreference = "Continue"
    $ErrorActionPreference = 'Continue'
    Write-Debug "Debug mode enabled"
}
else {
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = 'silentlycontinue'
    Write-Output "Regular mode enabled"
}

try {
    $OSVersion = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Version
}
catch {
    # fall-back that doesn’t use WMI
    $OSVersion = [System.Environment]::OSVersion.Version.ToString()
}

if ($OSVersion.StartsWith('6.1')) {
    # Windows 7
    Write-Output 'Running on Windows 7.  Exiting…'
    exit 0
}

# See if Custom Field has disabled AuditSCOtherDisable
Write-Debug "AuditSCOtherDisable: $AuditSCOtherDisable"
if ($AuditSCOtherDisable) {
    Write-Output "Other SC check disabled."
    Exit 0
}

function Check-SCServicePath {

    Write-Output "################# Check ScreenConnect Service Path #################"

    # For setting debug output level
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

    # List ScreenConnect services in debug mode
    if ($debug) {
        Write-Debug "ScreenConnect Services Found:"
        $SCServices | ForEach-Object { Write-Debug "Service Name: $($_.Name) - Display Name: $($_.DisplayName)" }
    }

    $servicesNotContainingUrl = @()

    foreach ($service in $SCServices) {

        # single, fault-tolerant lookup
        $serviceDetail = Get-ServiceDetail -Name $service.Name
        if (-not $serviceDetail -or [string]::IsNullOrWhiteSpace($serviceDetail.PathName)) {
            continue   # couldn't read the path, ignore this service
        }

        if ($serviceDetail.PathName -notlike "*$SCURLtocheck*") {
            $servicesNotContainingUrl += $service
        }
    }


    if ($servicesNotContainingUrl.Count -gt 0) {
        Write-Output "WARNING: ScreenConnect services do not contain '$SCURLtocheck' in their path."

        foreach ($service in $servicesNotContainingUrl) {
            $serviceDetail = Get-ServiceDetail -Name $service.Name
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

            if ($deleteInvalid) {
                Remove-InvalidSCService -ServiceName $service.Name
            }
        }
        Exit 1
    }
    else {
        Write-Output "AllGood: All ScreenConnect services contain '$SCURLtocheck' in their path."
    }
}

function Get-ServiceDetail {
    param([string]$Name)

    try {
        # Primary (fast) path – WMI / CIM
        return Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
    }
    catch {
        # Fallback – read ImagePath directly from the registry
        $reg = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
        $img = (Get-ItemProperty -Path $reg -Name ImagePath -ErrorAction Stop).ImagePath
        # Build a minimal object with PathName so the rest of your code doesn’t change
        [pscustomobject]@{ PathName = $img }
    }
}

function Remove-InvalidSCService {
    param (
        [string] $ServiceName
    )

    Write-Output "Deleting invalid ScreenConnect service: $ServiceName"
    try {
        # Stop the service
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        # Delete the service
        sc.exe delete $ServiceName | Out-Null

        Write-Output "Successfully deleted service: $ServiceName"
    }
    catch {
        Write-Output "ERROR: Failed to delete service: $ServiceName - $_"
    }
}

Check-SCServicePath