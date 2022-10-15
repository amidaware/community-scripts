<#
.Synopsis
	Install MeshCentral from Tactical

.Description
	Install MeshCentral from Tactical if the Mesh install failed.

.Parameters <API_KEY>
	The API Key is generated from Settings > Global Settings | API KEYS.
	The user needs appropriate permissions to use the API Key.

.Outputs
	An error message is output if an error is detected.
	A friendly message is output if Mesh Agent was installed successfully.

.Notes
	The only input is the API Key as a single argument without any parameter names.

#>

$ApiKey = $args[0]
$ApiUrl = Get-ItemPropertyValue -LiteralPath "HKLM:\SOFTWARE\TacticalRMM\" -Name "ApiURL"
$Platform = "windows"
$UrlPath = "api/v3/meshexe"
# Always use Program Files because 32-bit agent will not be installed on 64-bit OS.
$MeshPath = "C:\Program Files\TacticalAgent\"
$TacticalMeshPath = "C:\Program Files\TacticalAgent\"
$MeshAgentExe = "MeshAgent.exe"
$MeshService = "Mesh Agent"
$MeshName = "Mesh Agent"
$Meshconfig = "C:\Program Files\Mesh Agent\MeshAgent.msh"
$MeshExe = Join-Path -Path $MeshPath -ChildPath $MeshAgentExe
$TacticalMeshExe = Join-Path -Path $TacticalMeshPath -ChildPath $MeshAgentExe

function GetURL {
    param (
        [string] $UrlPath
    )Api
    return "https://${ApiUrl}/${UrlPath}/"
}

$Headers = @{
    'X-API-KEY' = $ApiKey
}

if ([Environment]::Is64BitOperatingSystem) {
    $Arch = "amd64"
} else {
    $Arch = "386"
}

$MeshInstallArgs = @{
    ArgumentList = "-fullinstall"
}

$Body = @{
    goarch = $Arch
    plat = $Platform
}

$RestParams = @{
	Uri = ""
	Headers = $Headers
	# Not sure what the correct content type is but commenting it out works.
	#ContentType = "application/json"
	Method = "POST"
	OutFile = $MeshExe
    Body = $Body
}

# Adjust TLS for Windows 7, 8.1
if ([Environment]::OSVersion.Version -le (new-object 'Version' 7,0)) {
    Write-Output "Adjusting TLS version(s) for Windows prior to Win 10"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
}

if ($ApiKey.Length -ne 32) {
    Write-Output "Invalid API_KEY. Should be 32 characters."
    $host.SetShouldExit(1)
    Exit
}

# Check if Mesh is already installed
if ((Get-Service -Name $MeshService -ErrorAction SilentlyContinue).Length -gt 0) {
    Write-Output "Mesh Agent service exists. Exiting."
    $host.SetShouldExit(1)
    Exit
}

# Check if the Mesh config exists
# Mesh Uninstall does not delete the config. Therefore, this check does not work as expected.
if ((Get-Item -Path $MeshConfig -ErrorAction SilentlyContinue).Length -gt 0) {
    Write-Output "Warning: Mesh Config exists from a previous install."
}

# Prefer to handle the error ourselves rather than fill the screen with red text.
$ErrorActionPreference = 'SilentlyContinue'

if ((Get-Item -Path $TacticalMeshExe -ErrorAction SilentlyContinue).Length -eq 0) {
	$RestParams["Uri"] = GetURL($UrlPath)
	Write-Output "Downloading $($MeshAgentExe)"
	Invoke-RestMethod @RestParams
	if (! $?) {
		Write-Output "Failed to download $($MeshAgentExe) from API: $($error[0].ToString() )"
		Write-Output "Stacktrace: $($error[0].Exception.ToString() )"
		$host.SetShouldExit(1)
		Exit
	}
}

Write-Output "Installing ${MeshName}."
Start-Process $MeshExe @MeshInstallArgs
if (! $?) {
	Write-Output "Failed to run $($MeshAgentExe)"
	Write-Output "Stacktrace: $($error[0].Exception.ToString() )"
    $host.SetShouldExit(1)
    Exit
}

Write-Output "${MeshName} has been installed."
$host.SetShouldExit(0)
Exit
