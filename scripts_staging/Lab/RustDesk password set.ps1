#public
#experimental password changer for rustdesk will use the content of a var for the source of the PW
#RDPWD={{agent.Local password}}

$ErrorActionPreference = 'SilentlyContinue'

$confirmation_file = "C:\program files\RustDesk\rdrunonce.txt"

# Stop the RustDesk service if it is running
net stop rustdesk > $null
$ProcessActive = Get-Process rustdesk -ErrorAction SilentlyContinue
if ($ProcessActive -ne $null) {
    Stop-Process -ProcessName rustdesk -Force
}

# Use the password from the RDPWD environment variable
$rustdesk_pw = $env:RDPWD
if (-not $rustdesk_pw) {
    Write-Error "The RDPWD environment variable is not set."
    exit 1
}

# Start RustDesk with the provided password
Start-Process "$env:ProgramFiles\RustDesk\RustDesk.exe" "--password $rustdesk_pw" -Wait
Write-Output $rustdesk_pw

# Restart the RustDesk service
net start rustdesk > $null

# Create the confirmation file
New-Item $confirmation_file > $null