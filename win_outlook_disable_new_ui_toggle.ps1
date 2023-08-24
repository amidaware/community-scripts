# Define the registry path and values
$registryPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
$valueName = "HideNewOutlookToggle"
$valueData = 0

# Check if the registry key already exists
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}

# Add the new DWORD value
Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type DWord
