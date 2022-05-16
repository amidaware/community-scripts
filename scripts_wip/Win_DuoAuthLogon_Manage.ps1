<#
.Synopsis
   Installs Duo Authentication for Windows Logon and RDP
.DESCRIPTION
   Downloads the Duo Auth Logon install for Duo.
   Add additional parameters as needed.
.EXAMPLE
    Win_DuoAuthLogon_Manage -IntegrationKey "ikey" -SecretKey "skey" -ApiHost "apihost-hostname"
.EXAMPLE
    Win_DuoAuthLogon_Manage -IntegrationKey "ikey" -SecretKey "skey" -ApiHost "apihost-hostname" -Uninstall
.EXAMPLE
    Win_DuoAuthLogon_Manage -IntegrationKey "ikey" -SecretKey "skey" -ApiHost "apihost-hostname" -AutoPush 1 -FailOpen 0 -RdpOnly 0
.INSTRUCTIONS
    1. Create a Microsoft RDP application in Duo. Copy the values provided in the details.
    2. In Tactical RMM, Go to Settings >> Global Settings >> Custom Fields and under Clients, create the following custom fields: 
        a) DuoIntegrationKey as type text
        b) DuoSecretKey as type text
        c) DuoApiHost as type text
    3. In Tactical RMM, Right-click on each client and select Edit. Fill in the DuoIntegrationKey, DuoSecretKey, and DuoApiHost.
    4. Create the follow script arguments
        a) -IntegrationKey {{client.DuoIntegrationKey}}
        b) -SecretKey {{client.DuoSecretKey}}
        c) -ApiHost {{client.DuoApiHost}}
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2022-04-12
#>

Param(
    [Parameter(Mandatory)]
    [string]$IntegrationKey,

    [Parameter(Mandatory)]
    [string]$SecretKey,

    [Parameter(Mandatory)]
    [string]$ApiHost,

    [ValidateSet("1", "0")]
    $AutoPush = "1",

    [ValidateSet("1", "0")]
    $FailOpen = "0",

    [ValidateSet("1", "0")]
    $RdpOnly = "0",

    [ValidateSet("1", "0")]
    $Smartcard = "0",

    [ValidateSet("1", "0")]
    $WrapSmartcard = "0",

    [ValidateSet("1", "0")]
    $EnableOffline = "1",

    [ValidateSet("2", "1", "0")]
    $UsernameFormat = "1",

    [switch]$Uninstall
)

function ConvertTo-StringData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [HashTable[]]$HashTable
    )
    process {
        $data = ''
        foreach ($item in $HashTable) {
            foreach ($entry in $item.GetEnumerator()) {
                $data += "{0}=`"{1}`" " -f $entry.Key, $entry.Value
            }
        }

        return $data.Trim()
    }
}

function Win_DuoAuthLogon_Manage {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$IntegrationKey,

        [Parameter(Mandatory)]
        [string]$SecretKey,

        [Parameter(Mandatory)]
        [string]$ApiHost,

        [ValidateSet("1", "0")]
        $AutoPush = "1",

        [ValidateSet("1", "0")]
        $FailOpen = "0",

        [ValidateSet("1", "0")]
        $RdpOnly = "0",

        [ValidateSet("1", "0")]
        $Smartcard = "0",

        [ValidateSet("1", "0")]
        $WrapSmartcard = "0",

        [ValidateSet("1", "0")]
        $EnableOffline = "1",

        [ValidateSet("2", "1", "0")]
        $UsernameFormat = "1",

        [switch]$Uninstall
    )

    Begin {
        if ($null -ne (Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -Match "Duo Authentication" }) -and -Not($Uninstall)) {
            Write-Output "Duo Authentication already installed."
            Exit 0
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
    }

    Process {
        Try {
            if ($Uninstall) {
                (Get-WmiObject -Class Win32_Product -Filter "Name = 'Duo Authentication for Windows Logon x64'").Uninstall()
                Write-Output "Uninstalled Duo Authentication for Windows"
                Exit 0
            }

            Write-Output "Starting installation."
            $source = "https://dl.duosecurity.com/duo-win-login-latest.exe"
            $destination = "C:\packages$random\duo-win-login-latest.exe"
            Write-Output "Downloading file."
            Invoke-WebRequest -Uri $source -OutFile $destination
            $options = @{
                IKEY           = $IntegrationKey
                SKEY           = $SecretKey
                HOST           = $ApiHost
                AUTOPUSH       = $AutoPush
                FAILOPEN       = $FailOpen
                RDPONLY        = $RdpOnly
                SMARTCARD      = $Smartcard
                WRAPSMARTCARD  = $WrapSmartcard
                ENABLEOFFLINE  = $EnableOffline
                USERNAMEFORMAT = $UsernameFormat
            }

            $optionsString = ConvertTo-StringData $options
            $arguments = @("/S", "/V`" /qn $optionsString`"")
            Write-Output "Starting install file."
            $process = Start-Process -NoNewWindow -FilePath $destination -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if ($timedOut) {
                $process | kill
                Write-Output "Install timed out after 300 seconds."
                Exit 1
            }
            elseif ($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Output "Install error code: $code."
                Exit 1
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
            Exit 1
        }
    }

    End {
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        Write-Output "Installation complete."
        Exit 0
    }
}

if (-not(Get-Command 'Win_DuoAuthLogon_Manage' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{
    IntegrationKey = $IntegrationKey
    SecretKey      = $SecretKey
    ApiHost        = $ApiHost
    AutoPush       = $AutoPush
    FailOpen       = $FailOpen
    RdpOnly        = $RdpOnly
    Smartcard      = $Smartcard
    WrapSmartcard  = $WrapSmartcard
    EnableOffline  = $EnableOffline
    UsernameFormat = $UsernameFormat
    Uninstall      = $Uninstall
}
 
Win_DuoAuthLogon_Manage @scriptArgs