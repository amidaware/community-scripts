#Check if enabled

try {
    # Check SMB1 Server status
    $smbServerConfig = Get-SmbServerConfiguration -ErrorAction Stop
    if ($smbServerConfig.EnableSMB1Protocol -eq $true) {
        Write-Host "SMB1 Server is enabled."
        exit 1
    } else {
        Write-Host "SMB1 Server is not enabled."
    }
}
catch {
    Write-Host "Error checking SMB1 Server status. It may not be applicable on this system."
}

try {
    # Check SMB1 Client status
    $smbClientConfig = Get-SmbClientConfiguration -ErrorAction Stop
    if ($smbClientConfig.EnableSMB1Protocol -eq $true) {
        Write-Host "SMB1 Client is enabled."
        exit 1
    } else {
        Write-Host "SMB1 Client is not enabled."
    }
}
catch {
    Write-Host "Error checking SMB1 Client status. It may not be applicable on this system."
}