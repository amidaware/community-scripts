param (
    [string] $huntresskey
)
$tls = "Tls12";
[System.Net.ServicePointManager]::SecurityProtocol = $tls;
$serviceName = 'HuntressAgent'
If (Get-Service $serviceName -ErrorAction SilentlyContinue) {
    $service = Get-Service -Name $serviceName
    $stat = $service.Status
    if ($stat -ne "Running") {
        Start-Service $serviceName
    }
}
Else {
    Write-Host "$serviceName not found - need to install"
    $ErrorCount = 0

    if (!$huntresskey) {
        write-output "Variable not specified Huntress, please create a custom field under Client called Huntress, Example Value: `"cleverit`" `n"
        $ErrorCount += 1
    }

    if (!$ErrorCount -eq 0) {
        exit 1
    }
    Write-Host "Huntress key $huntresskey" 

    # Replace __ACCOUNT_KEY__ with your account secret key
    $AccountKey = "lkjdlkjasflkajsdflkasjdf"

    # Replace __ORGANIZATION_KEY__ with a unique identifier for the organization/client
    $OrganizationKey = "$huntresskey"

    # set to 1 to enable verbose logging
    $DebugPrintEnabled = 0

    ##############################################################################
    ## The following should not need to be adjusted

    # check for an account key specified on the command line
    if ( ! [string]::IsNullOrEmpty($acctkey)) {
        $AccountKey = $acctkey
    }

    # check for an organization key specified on the command line
    if ( ! [string]::IsNullOrEmpty($orgkey)) {
        $OrganizationKey = $orgkey
    }

    # Variables used throughout the Huntress Deployment Script
    $X64 = 64
    $X86 = 32
    $InstallerName = "HuntressAgent.exe"
    $InstallerPath = Join-Path $Env:TMP $InstallerName
    $DownloadURL = "https://huntress.io/download/" + $AccountKey + "/" + $InstallerName
    $HuntressServiceName = "HuntressAgent"

    $ScriptFailed = "Script Failed!"

    function Get-TimeStamp {
        return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    }

    $SupportMessage = "Please send the error message to the Huntress Team for help at support@huntresslabs.com"

    function Confirm-ServiceExists ($service) {
        if (Get-Service $service -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    }

    function Debug-Print ($msg) {
        if ($DebugPrintEnabled -eq 1) {
            Write-Host "$(Get-TimeStamp) [DEBUG] $msg"
        }
    }

    function Get-WindowsArchitecture {
        if ($env:ProgramW6432) {
            $WindowsArchitecture = $X64
        }
        else {
            $WindowsArchitecture = $X86
        }

        return $WindowsArchitecture
    }

    function Get-Installer {
        Debug-Print("downloading installer...")
        $WebClient = New-Object System.Net.WebClient
    
        try {
            $WebClient.DownloadFile($DownloadURL, $InstallerPath)
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Host "$(Get-TimeStamp) $ErrorMessage"
        }
    
        if ( ! (Test-Path $InstallerPath)) {
            $DownloadError = "Failed to download the Huntress Installer from $DownloadURL"
            Write-Host "$(Get-TimeStamp) $DownloadError"
            Write-Host "$(Get-TimeStamp) Verify you set the AccountKey variable to your account secret key."
            throw $ScriptFailed
        }
        Debug-Print("installer downloaded to $InstallerPath...")
    }

    function Install-Huntress ($OrganizationKey) {
        Debug-Print("Checking for HuntressAgent service...")
        if ( Confirm-ServiceExists($HuntressServiceName)) {
            $InstallerError = "The Huntress Agent is already installed. Exiting."
            Write-Host "$(Get-TimeStamp) $InstallerError"
            exit 0
        }

        Debug-Print("Checking for installer file...")
        if ( ! (Test-Path $InstallerPath)) {
            $InstallerError = "The installer was unexpectedly removed from $InstallerPath"
            Write-Host "$(Get-TimeStamp) $InstallerError"
            Write-Host ("$(Get-TimeStamp) A security product may have quarantined the installer. Please check " +
                "your logs. If the issue continues to occur, please send the log to the Huntress " +
                "Team for help at support@huntresslabs.com")
            throw $ScriptFailed
        }

        Debug-Print("Executing installer...")
        Start-Process $InstallerPath "/ACCT_KEY=`"$AccountKey`" /ORG_KEY=`"$OrganizationKey`" /S" -Wait
    }

    function Test-Installation {
        Debug-Print("Verifying installation...")

        # Ensure we resolve the correct Huntress directory regardless of operating system or process architecture.
        $WindowsArchitecture = Get-WindowsArchitecture
        if ($WindowsArchitecture -eq $X86) {
            $HuntressDirPath = Join-Path $Env:ProgramFiles "Huntress"
        }
        elseif ($WindowsArchitecture -eq $X64) {
            $HuntressDirPath = Join-Path $Env:ProgramW6432 "Huntress"
        }
        else {
            $ArchitectureError = "Failed to determine the Windows Architecture. Received $WindowsArchitecure."
            Write-Host "$(Get-TimeStamp) $ArchitectureError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        $HuntressAgentPath = Join-Path $HuntressDirPath "HuntressAgent.exe"
        $HuntressUpdaterPath = Join-Path $HuntressDirPath "HuntressUpdater.exe"
        $WyUpdaterPath = Join-Path $HuntressDirPath "wyUpdate.exe"
        $HuntressKeyPath = "HKLM:\SOFTWARE\Huntress Labs\Huntress"
        $AccountKeyValueName = "AccountKey"
        $OrganizationKeyValueName = "OrganizationKey"
        $TagsValueName = "Tags"

        # Ensure the Huntress installation directory was created.
        if ( ! (Test-Path $HuntressDirPath)) {
            $HuntressInstallationError = "The expected Huntress directory $HuntressDirPath did not exist."
            Write-Host "$(Get-TimeStamp) $HuntressInstallationError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        # Ensure the Huntress agent was created.
        if ( ! (Test-Path $HuntressAgentPath)) {
            $HuntressInstallationError = "The expected Huntress agent $HuntressAgentPath did not exist."
            Write-Host "$(Get-TimeStamp) $HuntressInstallationError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        # Ensure the Huntress updater was created.
        if ( ! (Test-Path $HuntressUpdaterPath)) {
            $HuntressInstallationError = "The expected Huntress updater $HuntressUpdaterPath did not exist."
            Write-Host "$(Get-TimeStamp) $HuntressInstallationError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        # Ensure our wyUpdate dependency was created.
        if ( ! (Test-Path $WyUpdaterPath)) {
            $HuntressInstallationError = "The expected wyUpdate dependency $WyUpdaterPath did not exist."
            Write-Host "$(Get-TimeStamp) $HuntressInstallationError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        # Ensure the Huntress registry key is present.
        if ( ! (Test-Path $HuntressKeyPath)) {
            $HuntressRegistryError = "The expected Huntress registry key '$HuntressKeyPath' did not exist."
            Write-Host "$(Get-TimeStamp) $HuntressRegistryError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        $HuntressKeyObject = Get-ItemProperty $HuntressKeyPath

        # Ensure the Huntress registry key is not empty.
        if ( ! ($HuntressKeyObject)) {
            $HuntressRegistryError = "The Huntress registry key was empty."
            Write-Host "$(Get-TimeStamp) $HuntressRegistryError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        # Ensure the AccountKey value is present within the Huntress registry key.
        if ( ! (Get-Member -inputobject $HuntressKeyObject -name $AccountKeyValueName -Membertype Properties)) {
            $HuntressRegistryError = ("The expected Huntress registry value $AccountKeyValueName did not exist " +
                "within $HuntressKeyPath")
            Write-Host "$(Get-TimeStamp) $HuntressRegistryError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        # Ensure the OrganizationKey value is present within the Huntress registry key.
        if ( ! (Get-Member -inputobject $HuntressKeyObject -name $OrganizationKeyValueName -Membertype Properties)) {
            $HuntressRegistryError = ("The expected Huntress registry value $OrganizationKeyValueName did not exist " +
                "within $HuntressKeyPath")
            Write-Host "$(Get-TimeStamp) $HuntressRegistryError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        # Ensure the Tags value is present within the Huntress registry key.
        if ( ! (Get-Member -inputobject $HuntressKeyObject -name $TagsValueName -Membertype Properties)) {
            $HuntressRegistryError = ("The expected Huntress registry value $TagsKeyValueName did not exist within " +
                "$HuntressKeyPath")
            Write-Host "$(Get-TimeStamp) $HuntressRegistryError"
            Write-Host "$(Get-TimeStamp) $SupportMessage"
            throw $ScriptFailed
        }

        Debug-Print("Installation verified...")
    }

    function main () {
        # make sure we have an account key (either hard coded or from the command line params)
        Debug-Print("Checking for AccountKey...")
        if ($AccountKey -eq "__ACCOUNT_KEY__") {
            Write-Warning "$(Get-TimeStamp) AccountKey not set, exiting script!"
            exit 1
        }
        elseif ($AccountKey.length -ne 32) {
            Write-Warning "$(Get-TimeStamp) Invalid AccountKey specified, exiting script!"
            exit 1
        }

        # make sure we have an org key (either hard coded or from the command line params)
        if ($OrganizationKey -eq "__ORGANIZATION_KEY__") {
            Write-Warning "$(Get-TimeStamp) OrganizationKey not specified, exiting script!"
            exit 1
        }

        # check if huntress disabled on asset
        if ($disablehuntress -eq $true) {
            Write-Warning "Huntress disabled on asset, exiting script!"
            exit 1
        }
        Write-Host "$(Get-TimeStamp) OrganizationKey: " $OrganizationKey
        Get-Installer
        Install-Huntress $OrganizationKey
        Test-Installation
        Write-Host "$(Get-TimeStamp) Huntress Agent successfully installed"
    }

    try {
        main
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "$(Get-TimeStamp) $ErrorMessage"
        exit 1
    }
}