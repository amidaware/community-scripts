# Checks for Mesh service, folder, and .exe. Returns 1 if there's a problem
# Useful to run as a monitoring script to check for AV deleting mesh

$serviceName = "Mesh Agent"
$ErrorCount = 0

if (!(Get-Service $serviceName)) { 
    Write-Output "Mesh Agent Service Missing"
    $ErrorCount += 1
}

else {
    Write-Output "Mesh Agent Service Found"
}

if (!(Test-Path "c:\Program Files\Mesh Agent")) {
    Write-Output "Mesh Agent Folder missing"
    $ErrorCount += 1
}

else {
    Write-Output "Mesh Agent Folder exists"
}

if (!(Test-Path "c:\Program Files\Mesh Agent\MeshAgent.exe")) {
    Write-Output "Mesh Agent exe missing"
    $ErrorCount += 1
}

else {
    Write-Output "Mesh Agent exe exists"
}

if (!$ErrorCount -eq 0) {
    exit 1
}
