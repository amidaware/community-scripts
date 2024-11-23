<#
.SYNOPSIS
    Gets Cellular info

.NOTES
    v1.0 11/23/2024 silversword411 initial release
#>

# Ensure the script is running with appropriate permissions to access WMI
try {
    # Query the WMI class for cellular information
    $WWAN_Data = Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_DeviceStatus_CellularIdentities01_01" |
    Select-Object -Property ICCID, IMSI, InstanceID, PhoneNumber

    if ($WWAN_Data) {
        # Output the retrieved cellular data
        Write-Output $WWAN_Data
    }
    else {
        Write-Output "No cellular data found."
    }
}
catch {
    Write-Error "An error occurred while retrieving cellular data: $_"
}