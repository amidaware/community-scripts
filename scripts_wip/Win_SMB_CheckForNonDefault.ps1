# Get all SMB shares
$shares = Get-SmbShare

# Filter out default shares
$nonDefaultShares = $shares | Where-Object { $_.Special -eq $false }

if ($nonDefaultShares.Count -eq 0) {
    Write-Output "All good. There are no non-default shares."
} else {
    Write-Output "Error: There are non-default shares present."
    $nonDefaultShares
    exit 1
}