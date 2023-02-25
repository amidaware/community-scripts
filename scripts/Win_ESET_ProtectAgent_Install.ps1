<#
.SYNOPSIS
    Installs ESET Protect Agent.
    IF ALREADY installed reconfigure it.

.REQUIREMENTS
    You will need .ini file from ESET Protect Console to insert parameters.
    You will need:
    - Host
    - Cert
    - Cert Auth
    - Cert Password (optional)
    - Port (optional)
    - Static Group (optional)
    - Custom Policy (optional)

.INSTRUCTIONS
    1. Create Installation Package as Script GPO or SCCM
    2. Take notes requirements.
    3. In Tactical RMM, Global Settings -> Custom Fields, create custom fields for clients, so that you can create customized hosts for clients and not for users.
    5. Fill in:
        a) eset_protect_host -> Text -> You can fill in on global settings with your host, this will be the same for all clients.
        b) eset_cert -> Text -> ONLY IF you use the same cert for all clients can fill in on global settings with your host, this will be the same for all clients.
        c) eset_cert_auth -> ONLY IF you use the same cert for all clients can fill in on global settings with your host, this will be the same for all clients.
        d) eset_protect_port (optional) -> Text -> You can fill in on global settings with your host, this will be the same for all clients.
        e) eset_cert_password (optional) -> Text -> ONLY IF you use the same cert for all clients can fill in on global settings with your host, this will be the same for all clients.
        f) eset_static_group (optional) -> ONLY IF you use the same initial group for all clients can fill in on global settings with your host, this will be the same for all clients.
        g) eset_custom_policy (optional) -> ONLY IF you use the same initial policy for all clients can fill in on global settings with your host, this will be the same for all clients.
    6. Compile for clients custom fields.
    7. Now when you will launch the script it will install latest ESET Protect Agent (x86 or x64 based on system) and join it automatically to ESET Protect Console.

.NOTES
    How to by ESET to have .ini file:
    https://help.eset.com/protect_admin/81/en-US/fs_local_deployment_aio_create.html?fs_agent_deploy_gpo_sccm.html
    
.VERSION
	V1.0 Initial Release
#>
param (
   [string] $eset_protect_host,
   [string] $eset_cert,
   [string] $eset_cert_password,
   [string] $eset_cert_auth,
   [string] $eset_protect_port,
   [string] $eset_static_group,
   [string] $eset_custom_policy
)
if ([string]::IsNullOrEmpty($eset_protect_host)) {
    throw "Host must be defined. Use -eset_protect_host <value> to pass it."
}
if ([string]::IsNullOrEmpty($eset_cert)) {
    throw "Cert must be defined. Use -eset_cert <value> to pass it."
}
if ([string]::IsNullOrEmpty($eset_cert_auth)) {
    throw "Host must be defined. Use -eset_cert_auth <value> to pass it."
}
if ([string]::IsNullOrEmpty($eset_protect_port)) {
    $eset_protect_port=2222
}
if ([string]::IsNullOrEmpty($eset_cert_password)) {
    $eset_cert_password=""
}
if ([string]::IsNullOrEmpty($eset_static_group)) {
    $eset_static_group=""
}
if ([string]::IsNullOrEmpty($eset_static_group)) {
    $eset_custom_policy=""
}

Write-Host "Running ESET Protect Agent installation on:" $env:COMPUTERNAME
$tmpDir = [System.IO.Path]::GetTempPath()
$inipath = $tmpDir + "install_config.ini"
Write-Host "Saving file .ini to" $inipath
$esetini = @"
[ERA_AGENT_PROPERTIES]
P_INSTALL_MODE_EULA_ONLY=1
P_CERT_CONTENT=$eset_cert
P_CERT_PASSWORD_IS_BASE64=yes
P_CERT_PASSWORD=$eset_cert_password
P_CERT_AUTH_CONTENT=$eset_cert_auth
P_ENABLE_TELEMETRY=1
P_HOSTNAME=$eset_protect_host
P_PORT=$eset_protect_port
P_INITIAL_STATIC_GROUP=$eset_static_group
P_CUSTOM_POLICY=$eset_custom_policy
"@
New-Item $inipath -type file -force -value $esetini
if ((Get-WmiObject win32_operatingsystem | select osarchitecture).osarchitecture -like "64*"){
    $urleset = "https://download.eset.com/com/eset/apps/business/era/agent/latest/agent_x64.msi"
    $agent_eset = "agent_x64.msi"
}
else{
    $urleset = "https://download.eset.com/com/eset/apps/business/era/agent/latest/agent_x86.msi"
    $agent_eset = "agent_x86.msi"
}
Write-Host "Downloading latest Installer from ESET Please wait..."
    $tmpDir = [System.IO.Path]::GetTempPath()
    $outpath = $tmpDir + $agent_eset
    $logpath = $tmpDir + "ra-agent-install.log"
    Write-Host "Saving file to" $outpath
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $urleset -OutFile $outpath
Write-Host "Installation log file will be at" $logpath
Write-Host "Installing latest ESET Protect Agent... Please wait up to 10 minutes for install to complete."
msiexec.exe /qr /i $outpath /l*v $logpath /norestart
