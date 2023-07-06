<#
.Synopsis
	(Re)Install MeshCentral from Tactical

.Description
	The purpose of this script is to install or reinstall MeshCentral from Tactical. Several scenarios are
	detected:
	- Corrupt service from Bitdefender quarantining MeshAgent.exe
	- Inaccessible or zombie file after MeshAgent.exe is restored by Bitdefender.
	- Unable to save MeshAgent.exe to TacticalAgent directory after MeshAgent.exe is quarantined by Bitdefender.

	The TRMM_API_KEY needs to be passed as an environmental variable.
	Generate a new API key by going to Settings > Global Settings | API KEYS.
	The user needs appropriate permissions to use the API Key.

.Parameters <Reinstall>
	Using the -Reinstall flag will remove the service and MeshAgent.exe file before installation.
	The existing config will remain to prevent duplicates in MeshCentral.

.Parameters <UseTemp>
	Using the -UseTemp flag will save the MeshAgent.exe file in the system temp folder. If Bitdefender has
	quarantined MeshAgent.exe, sometimes the system user cannot save MeshAgent.exe to the TacticalRMM folder
	even though it's a different folder. A reboot is necessary to restore access to "MeshAgent.exe" in the
	TacticalRMM (and possibly other excluded locations?) folder.

.Parameters <ApiKey>
    Deprecated. DO NOT USE. This was added before the environment vars were introduced. Use the TRMM_API_KEY env
    var.

.EnvironmentalVariable <TRMM_API_KEY>
	Generate a new API key by going to Settings > Global Settings | API KEYS.
	Add it as an environmental variable in the form of TRMM_API_KEY=abcef123456

.Outputs
	All actions taken are output.
	If an error condition is detected, a user friendly error message is output.
	If an error wsa not encountered, a message stating Mesh Agent was installed is output.

.Notes
	v1 Author: 10/15/2022 NiceGuyIT
	v1.1: 6/20/2022 Fixing not erroring when API key is not specified. NiceGuyIT and silversword411
#>

param (
	# Reinstall Mesh Agent
	[switch]$Reinstall,
	# Use the system temp folder instead of Tactical's folder
	[switch]$UseTemp,
	# TRMM API key
	[string]$ApiKey
)

# Check for a valid API Key.
# Command line parameter is deprecated in favor of environmental variables.
if ((Test-Path ApiKey) -or ($ApiKey.Length -gt 0)) {
	Write-Output "Passing the API_KEY on the command line is insecure and no longer supported."
	Write-Output ("ApiKey: '{0}'" -f $ApiKey)
	$host.SetShouldExit(1)
	Exit
}
if (!(Test-Path ENV:TRMM_API_KEY)) {
	Write-Output ("TRMM_API_KEY ENV var is not specified." -f $ENV:TRMM_API_KEY)
	$host.SetShouldExit(1)
	Exit
}
if (!(Test-Path ENV:TRMM_API_KEY) -or ($ENV:TRMM_API_KEY.Length -ne 32)) {
	Write-Output ("Invalid TRMM_API_KEY ('{0}'). Needs to be 32 characters." -f $ENV:TRMM_API_KEY)
	$host.SetShouldExit(1)
	Exit
}

# Get the current value
# [Net.ServicePointManager]::SecurityProtocol

# List all possible values
# [enum]::GetValues('Net.SecurityProtocolType')

function Test-TlsVersion($MinTlsVersion) {
	try {
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Write-Output "TLS 1.2 is supported on this system."
	}
	catch {
		Write-Output "Error: TLS 1.2 is not supported on this system."
		$host.SetShouldExit(1)
		Exit
	}
}

$TRMM = @{
	Name       = 'TacticalRMM'
	AgentName  = 'TacticalAgent'
	RegApiName = 'ApiURL'
	ApiKey     = $ENV:TRMM_API_KEY
}
$TRMM.RegApiPath = Join-Path -Path 'HKLM:\SOFTWARE\' -ChildPath $TRMM.Name -Resolve
$TRMM.ApiDomain = Get-ItemPropertyValue -LiteralPath $TRMM.RegApiPath -Name $TRMM.RegApiName
$TRMM.ApiUrl = 'https://{0}/api/v3/meshexe/' -f $TRMM.ApiDomain

$Mesh = @{
	Name        = 'Mesh Agent'
	ServiceName = 'Mesh Agent'
	ExeName     = 'MeshAgent.exe'
	ConfigName  = 'MeshAgent.msh'
}
# Always use Program Files because 32-bit agent will not be installed on 64-bit OS.
$Mesh.InstallPath = Join-Path -Path $ENV:ProgramFiles -ChildPath $Mesh.Name
$Mesh.InstallExe = Join-Path -Path $Mesh.InstallPath -ChildPath $Mesh.ExeName
$Mesh.ConfigFile = Join-Path -Path $Mesh.InstallPath -ChildPath $Mesh.ConfigName
# Tactical downloads the Mesh file to the Tactical directory. That may result in an error if Bitdefender has
# already quarantined "MeshAgent.exe" even if it was in the Mesh folder.
# Stacktrace: 'System.UnauthorizedAccessException: Access to the path 'C:\Program Files\TacticalAgent\MeshAgent.exe' is denied.
if ($UseTemp) {
	$Mesh.DownloadPath = $ENV:Temp
	$Mesh.DownloadExe = Join-Path -Path $Mesh.DownloadPath -ChildPath $Mesh.ExeName
}
else {
	$Mesh.DownloadPath = Join-Path -Path $ENV:ProgramFiles -ChildPath $TRMM.AgentName
	$Mesh.DownloadExe = Join-Path -Path $Mesh.DownloadPath -ChildPath $Mesh.ExeName
}

if ([Environment]::Is64BitOperatingSystem) {
	$Arch = "amd64"
}
else {
	$Arch = "386"
}

$Body = @{
	goarch = $Arch
	plat   = 'windows'
}

$Headers = @{
	'X-API-KEY' = $TRMM.ApiKey
}

$RestParams = @{
	Uri             = $TRMM.ApiUrl
	Headers         = $Headers
	ContentType     = "application/x-www-form-urlencoded"
	Method          = "POST"
	OutFile         = $Mesh.DownloadExe
	Body            = $Body
	UseBasicParsing = $True
	PassThru        = $True
}

$MeshInstallArgs = @{
	ArgumentList = "-fullinstall"
}

# Adjust TLS for Windows 7, 8.1
if ([Environment]::OSVersion.Version -le (new-object 'Version' 7, 0)) {
	Write-Output "Adjusting TLS version(s) for Windows prior to Win 10"
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
}

# Don't overload existing cmdlets.
function Get-CimService($Name) {
	$Service = Get-CimInstance Win32_Service | Where-Object -Property Name -Match $Name
	if (($Service | Measure-Object).Count -eq 1) {
		return $Service
	}
 else {
		return $False
	}
}

function Stop-CimService($Service) {
	if ($Service | Where-Object { $_.State -Match "Running" }) {
		$Service | Invoke-CimMethod -Name StopService
		return Get-CimService $Service.Name
	}
 else {
		return $False
	}
}

function Start-CimService($Service) {
	if ($Service | Where-Object { $_.State -Match "Stopped" }) {
		$Service | Invoke-CimMethod -Name StartService
		return Get-CimService $Service.Name
	}
 else {
		return $False
	}
}

function Remove-CimService($Service) {
	if ($Service | Where-Object { $_.State -Match "Running" }) {
		Write-Output ("Stopping Service '{0}' before removing it." -f $Service.Name)
		$Result = $Service | Invoke-CimMethod -Name StopService
		if (! $?) {
			Write-Output ("Failed to stop service '{0}'" -f $Service.Name)
			Write-Output ("===== Stacktrace =====")
			Write-Output ($error[0].Exception.ToString())
			$host.SetShouldExit(1)
			Exit
		}
		if ($Result.ReturnValue -ne 0) {
			Write-Output ("Invoke-CimMethod returned non-zero value: '{0}'" -f $Result.ReturnValue)
			Write-Output ("===== Stacktrace =====")
			Write-Output ($error[0].Exception.ToString())
			$host.SetShouldExit(1)
			Exit
		}
		# Write-Output ("Service '{0}' has stopped." -f $Service.Name)
	}
	Write-Output ("Removing Service '{0}'." -f $Service.Name)
	$Service | Remove-CimInstance
	# Write-Output ("Service '{0}' has been removed." -f $Service.Name)
}

function Test-Service($Name) {
	$Service = Get-CimService $Name
	if (!($Service)) {
		# No service
		return $True
	}
	if (($Service | Measure-Object -Property PathName -Character).Characters -eq 0) {
		# Invalid/Zombie service
		return $False
	}
 else {
		# Service exists and is running.
		return $True
	}
}

function Test-File($Filename) {
	<#
		This tries to rename the file to see if it's a "fake" file after AV restores it.
	#>
	if ((Get-Item -Path $Filename -ErrorAction SilentlyContinue).Length -gt 0) {
		# File exists. Try to rename
		$NewName = "{0}.new" -f $Filename
		Rename-Item -Path $Filename -NewName $NewName
		if ((Get-Item -Path $Filename -ErrorAction SilentlyContinue).Length -gt 0) {
			# Old file exists. Check that the new file doesn't exist to make sure.
			if ((Get-Item -Path $NewName -ErrorAction SilentlyContinue).Length -gt 0) {
				# New name does not exist. Rename failed.
				return $False
			}
			else {
				Write-Output "The old filename and new filename both exist. This should not happen."
				Write-Output ("Old filename: '{0}'" -f $Filename)
				Write-Output ("New filename: '{0}'" -f $NewName)
				$host.SetShouldExit(1)
				Exit
			}
		}
		else {
			# Renmae was successful. Rename the file back.
			Rename-Item -Path $NewName -NewName $Filename
			return $True
		}
	}
	# File doesn't exist. Return true
	return $True
}

function Invoke-Process {
	[CmdletBinding(SupportsShouldProcess)]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath,

		[Parameter()]
		[ValidateNotNullOrEmpty()]
		[string]$ArgumentList
	)

	try {
		$PInfo = New-Object System.Diagnostics.ProcessStartInfo
		$PInfo.FileName = $FilePath
		$PInfo.RedirectStandardError = $true
		$PInfo.RedirectStandardOutput = $true
		$PInfo.UseShellExecute = $false
		$PInfo.WindowStyle = 'Hidden'
		$PInfo.CreateNoWindow = $true
		$PInfo.Arguments = $ArgumentList
		$Process = New-Object System.Diagnostics.Process
		$Process.StartInfo = $PInfo
		$Process.Start() | Out-Null
		$Result = [pscustomobject]@{
			Title     = ($MyInvocation.MyCommand).Name
			Command   = $FilePath
			Arguments = $ArgumentList
			StdOut    = $Process.StandardOutput.ReadToEnd()
			StdErr    = $Process.StandardError.ReadToEnd()
			ExitCode  = $Process.ExitCode
		}
		$Process.WaitForExit()
		return $Result
	}
 catch {
		Write-Output ("Failed to run '{0}'" -f $FilePath)
		Write-Output ("===== Stacktrace =====")
		Write-Output ($error[0].Exception.ToString())
		$host.SetShouldExit(1)
		Exit
	}
}

# Prefer to handle the error ourselves rather than fill the screen with red text.
$ErrorActionPreference = 'SilentlyContinue'

# Do not display the progress indicator.
$ProgressPreference = 'SilentlyContinue'

# Check if Mesh is already installed
$Mesh.Service = Get-CimService $Mesh.ServiceName
if (!(Test-Service $Mesh.ServiceName)) {
	# Service is invalid/zombie. Delete it
	Write-Output ("The '{0}' service is invalid. Deleting the service." -f $Mesh.ServiceName)
	Write-Output ("===== Dump of Invalid Service: '{0}' =====" -f $Mesh.ServiceName)
	$Mesh.Service | Format-List *
	Write-Output ("===== End of Dump =====", $Mesh.ServiceName)
	Remove-CimService $Mesh.Service
}

# Service might have been deleted above
$Mesh.Service = Get-CimService $Mesh.ServiceName
if ($Mesh.Service -and !($Mesh.Service | Where-Object { $_.State -Match "Running" })) {
	# Service is not running. Check if the file was restored and thus inaccessible.
	if (!(Text-File $Mesh.InstallExe)) {
		# Executable is not accessible.
		Write-Output "Mesh executable is not accessible. Reboot the computer to restore functionality. This happens if Bitdefender restores the file."
		Write-Output ("Mesh executable: '{0}'" -f $Filename)
		$host.SetShouldExit(1)
		Exit
	}
 else {
		# Executable is accessible. Since the service is not running, delete the file so Mesh can be (re)installed.
		Remove-Item -Path $Mesh.InstallExe
		if ((Get-Item -Path $Mesh.InstallExe -ErrorAction SilentlyContinue).Length -gt 0) {
			Write-Output "Failed to remove file. It could be locked by another process or may not have permission."
			Write-Output ("Mesh executable: '{0}'" -f $Filename)
			$host.SetShouldExit(1)
			Exit
		}
	}
}

if ($Reinstall) {
	Write-Output ("Reinstall switch was provided. Stopping the '{0}' service and removing '{1}'." -f $Mesh.ServiceName, $Mesh.InstallExe)
	$Mesh.Service = Get-CimService $Mesh.ServiceName
	if ($Mesh.Service) {
		# Mesh service exists
		if ($Mesh.Service -and $Mesh.Service | Where-Object { $_.State -Match "Running" }) {
			# ... and is running. Stop the service
			Write-Output ("Stopping the '{0}' service" -f $Mesh.ServiceName)
			Stop-CimService $Mesh.Service
			$Mesh.Service = Get-CimService $Mesh.ServiceName
			if ($Mesh.Service | Where-Object { $_.State -Match "Running" }) {
				Write-Output ("Failed to stop the '{0}' service. Exiting with failure." -f $Mesh.ServiceName)
				$host.SetShouldExit(1)
				Exit
			}
		}

		# Remove the service
		# Write-Output ("Removing the '{0}' service" -f $Mesh.ServiceName)
		Remove-CimService $Mesh.Service
		$Mesh.Service = Get-CimService $Mesh.ServiceName
		if ($Mesh.Service) {
			Write-Output ("Failed to remove the '{0}' service. Exiting with failure." -f $Mesh.ServiceName)
			$host.SetShouldExit(1)
			Exit
		}
		Write-Output ("The '{0}' service has been removed." -f $Mesh.ServiceName)
	}
 else {
		Write-Output ("The '{0}' service does not exist." -f $Mesh.ServiceName)
	}

	Write-Output ("Removing the '{0}' file." -f $Mesh.InstallExe)
	# Check for zombie file
	if (!(Test-File $Mesh.InstallExe)) {
		Write-Output ("File '{0}' is a zombie/inaccessible." -f $Mesh.InstallExe)
		Write-Output ("A reboot is required to restore functionality and the file will be removed.")
		$host.SetShouldExit(1)
		Exit
	}
 else {
		Remove-Item -Path $Mesh.InstallExe
		if ((Get-Item -Path $Mesh.InstallExe -ErrorAction SilentlyContinue).Length -gt 0) {
			Write-Output "Failed to remove file. It could be locked by another process or may not have permission."
			Write-Output ("Mesh executable: '{0}'" -f $Mesh.InstallExe)
			$host.SetShouldExit(1)
			Exit
		}
		else {
			Write-Output ("The '{0}' install file has been deleted." -f $Mesh.InstallExe)
		}
	}
}

# The install won't work if the service is running or the exe exists. This could happen if the service is valid
# and reinstall flag was not provided.
$Mesh.Service = Get-CimService $Mesh.ServiceName
if ($Mesh.Service | Where-Object { $_.State -Match "Running" }) {
	Write-Output ("'{0}' is running and the reinstall flag was not provided. Exiting." -f $Mesh.Name)
	Write-Output ($Mesh.Service)
	$host.SetShouldExit(0)
	Exit
}

# Check for zombie file
if (!(Test-File $Mesh.DownloadExe)) {
	Write-Output ("File '{0}' is a zombie/inaccessible." -f $Mesh.DownloadExe)
	Write-Output ("A reboot is required to restore functionality and the file will be removed.")
	$host.SetShouldExit(1)
	Exit
}

# Check if the file exists.
if (Test-Path $Mesh.DownloadExe) {
	Write-Output ("Removing existing download file: '{0}'." -f $Mesh.DownloadExe)
	Remove-Item -Path $Mesh.DownloadExe
	if ((Get-Item -Path $Mesh.DownloadExe -ErrorAction SilentlyContinue).Length -gt 0) {
		Write-Output "Failed to remove file. It could be locked by another process or may not have permission."
		Write-Output ("Download file: '{0}'" -f $Mesh.DownloadExe)
		$host.SetShouldExit(1)
		Exit
	}
 else {
		Write-Output ("Removed download file '{0}'." -f $Mesh.DownloadExe)
	}
}

try {
	$Response = Invoke-WebRequest @RestParams
	if (! $?) {
		Write-Output ("Failed to download '{0}' from API: {1}" -f $Mesh.ExeName, $error[0].ToString())
		Write-Output ("===== Stacktrace =====")
		Write-Output ($error[0].Exception.ToString())
		$host.SetShouldExit(1)
		Exit
	}

	# Status Code is not "200"
	if ($Response.StatusCode -ne 200) {
		Write-Output ("HTTP Status Code is not 200. StatusCode = '{0}'. Exiting with failure." -f $Response.StatusCode)
		$host.SetShouldExit(1)
		Exit
	}

	# Status Description is not "OK"
	if (!($Response.StatusDescription -match "OK")) {
		Write-Output ("HTTP Status Description is not 'OK'. StatusDescription = '{0}'. Exiting with failure." -f $Response.StatusDescription)
		$host.SetShouldExit(1)
		Exit
	}

	# Downloaded less then 2MB
	if ($Response.RawContentLength -lt 2000000) {
		Write-Output ("Number of bytes downloaded is small. RawContentLength = '{0}'. Exiting with failure." -f $Response.RawContentLength)
		$host.SetShouldExit(1)
		Exit
	}
}
catch [System.UnauthorizedAccessException] {
	Write-Output ("Failed to save the file '{0}': {1}" -f $Mesh.ExeName, $error[0].ToString())
	if (!($UseTemp)) {
		Write-Output ("This can happen if Bitdefender quarantined '{0}' even though the" -f $Mesh.InstallExe)
		Write-Output ("download location is '{0}'" -f $Mesh.DownloadExe)
		Write-Output ("Rebooting is the only way to restore access.")
		Write-Output ("Until then, use the '-UseTemp' flag to this script to save the file in the system temp folder.")
	}
	Write-Output ("" -f $Mesh.ExeName, $error[0].ToString())
	Write-Output ("===== Stacktrace =====")
	Write-Output ($error[0].Exception.ToString())
	Write-Output ("===== Folder listing =====")
	Get-ChildItem $Mesh.DownloadPath
	$host.SetShouldExit(1)
	Exit
}
catch {
	Write-Output ("Caught exception while downloading '{0}' from API: {1}" -f $Mesh.ExeName, $error[0].ToString())
	Write-Output ("===== Stacktrace =====")
	Write-Output ($error[0].Exception.ToString())
	$host.SetShouldExit(1)
	Exit
}

Write-Output ("Installing '{0}'" -f $Mesh.Name)
$Result = Invoke-Process $Mesh.DownloadExe @MeshInstallArgs
if (! $?) {
	Write-Output ("Failed to run '{0}'" -f $Mesh.InstallExe)
	Write-Output ("===== Stacktrace =====")
	Write-Output ($error[0].Exception.ToString())
	$host.SetShouldExit(1)
	Exit
}

if ($Result.ExitCode -ne 0) {
	Write-Output ("Process exited with non-zero exit code: '{0}'" -f $Result.ExitCode)
	Write-Output ("Standard Output: {0}" -f $Result.StdOut)
	Write-Output ("Standard Error:", $Result.StdErr)
	$host.SetShouldExit(1)
	Exit
}

# StdOut could have an error.
if ($Result.StdOut.Length -gt 0) {
	Write-Output ("Checking if the output indicates an error.")
	if ($Result.StdOut -Match '\[ERROR]') {
		Write-Output ("An [ERROR] was found on Standard Output. '{0}' did not install correctly." -f $Mesh.Name)
		Write-Output ("====================")
		Write-Output ("StdOut Length: '{0}'" -f $Result.StdOut.Length)
		Write-Output ("StdErr Length: '{0}'" -f $Result.StdErr.Length)
		Write-Output ("Exit Code: '{0}'" -f $Result.ExitCode)
		Write-Output ("===== Standard Output =====")
		Write-Output ($Result.StdOut)
		Write-Output ("===== Standard Error =====")
		Write-Output ($Result.StdErr)
		$host.SetShouldExit(1)
		Exit
	}
}

# Sleep a second and check if the service is running.
Start-Sleep -Seconds 1
$Mesh.Service = Get-CimService $Mesh.ServiceName
if ($Mesh.Service -and !($Mesh.Service | Where-Object { $_.State -Match "Running" })) {
	Write-Output ("The '{0}' service is not running after 1 second. Is there an error in the output?")
	Write-Output ("StdOut Length: '{0}'" -f $Result.StdOut.Length)
	Write-Output ("StdErr Length: '{0}'" -f $Result.StdErr.Length)
	Write-Output ("Exit Code: '{0}'" -f $Result.ExitCode)
	Write-Output ("===== Standard Output =====")
	Write-Output ($Result.StdOut)
	Write-Output ("===== Standard Error =====")
	Write-Output ($Result.StdErr)
}


if ($Reinstall) {
	Write-Output ("'{0}' has been reinstalled." -f $Mesh.Name)
}
else {
	Write-Output ("'{0}' has been installed." -f $Mesh.Name)
}
$host.SetShouldExit(0)
Exit
