<#
.Synopsis
   Installs AutoElevate silently.
.DESCRIPTION
    Downloads the AutoElevate executable and installs silently.
    Navigate to the AutoElevate MSP dashboard > settings and get your license key.
    Fill out the remaining variables based on what you've setup in AutoElevate.
.EXAMPLE
    Win_AutoElevate_Manage -LicenseKey "abcdefg" -CompanyName "MyCompany" -LocationName "Main" -AgentMode live
.EXAMPLE
    Win_AutoElevate_Manage -Uninstall
.EXAMPLE
    Win_AutoElevate_Manage -LicenseKey "abcdefg" -CompanyName "MyCompany" -CompanyInitials "MC" -LocationName "Main" -AgentMode live
.INSTRUCTIONS
    1. In Tactical RMM, Go to Settings >> Global Settings >> Custom Fields and under Clients, create the following custom fields: 
        a) AutoElevateLicenseKey as type text
        b) AutoElevateCompanyName as type text
        c) AutoElevateCompanyInitials as type text
        d) AutoElevateLocationName as type text
        e) AutoElevateAgentMode as type Dropdown Single with options live, policy, audit, and technician
    2. In Tactical RMM, Right-click on each client and select Edit. Fill in the created fields.
    3. Create the follow script arguments
        a) -LicenseKey {{client.AutoElevateLicenseKey}}
        b) -CompanyName {{client.AutoElevateCompanyName}}
        c) -CompanyInitials {{client.AutoElevateCompanyInitials}}
        d) -LocationName {{client.AutoElevateLocationName}}
        e) -AgentMode {{client.AutoElevateAgentMode}}
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2023-04-12
   Updated Date: 2024-03-22
#>

Param(
    [string]$LicenseKey,

    [string]$CompanyName,
    
    [string]$CompanyInitials,
    
    [string]$LocationName,
    
    [ValidateSet("live", "policy", "audit", "technician")]
    $AgentMode,

    [switch]$Uninstall
)

function Win_AutoElevate_Manage {
    [CmdletBinding(DefaultParameterSetName = 'InstallSet')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='InstallSet')]
        [string]$LicenseKey,

        [Parameter(Mandatory=$true, ParameterSetName='InstallSet')]
        [string]$CompanyName,
        
        [string]$CompanyInitials,
        
        [Parameter(Mandatory=$true, ParameterSetName='InstallSet')]
        [string]$LocationName,
        
        [Parameter(Mandatory=$true, ParameterSetName='InstallSet')]
        [ValidateSet("live", "policy", "audit", "technician")]
        $AgentMode,

        [Parameter(Mandatory=$true, ParameterSetName='UninstallSet')]
        [switch]$Uninstall
    )

    Begin {
        $Apps = @()
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        if ($null -ne (Get-Service | Where-Object { $_.DisplayName -Match "AutoElevate" }) -and -Not($Uninstall)) {
            Write-Output "AutoElevate already installed."
            Exit 0
        }

        if($Uninstall -and $null -eq (Get-Service | Where-Object { $_.DisplayName -Match "AutoElevate" })) {
            Write-Output "AutoElevate already uninstalled."
            Exit 0
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
    }

    Process {
        Try {
            if ($Uninstall) {
                Write-Output "Uninstalling AutoElevate"
                $uninstallString = ($Apps | Where-Object { $_.DisplayName -Match "AutoElevate" }).UninstallString
                if ($uninstallString) {
                    $unst = $uninstallString -Split " "
                    $unst[1] = $unst[1] -Replace '/I', '/X'
                    Start-Process $unst[0] -ArgumentList $unst[1], "/quiet", "/qn", "/noreboot" -Wait -NoNewWindow
                    Write-Output "Uninstalled AutoElevate"
                    return
                }
                else {
                    Write-Error "Could not find uninstall string"
                    return
                }
            }

            Write-Output "Installing AutoElevate"
            $source = "https://autoelevate-installers.s3.us-east-2.amazonaws.com/current/AESetup.msi"
            $destination = "C:\packages$random\AESetup.msi"
            Invoke-WebRequest -Uri $source -OutFile $destination
            $arguments = @("/i $destination", "/quiet", "/lv C:\packages$random\AEInstallLog.log", "LICENSE_KEY=`"$LicenseKey`"",
                "COMPANY_NAME=`"$CompanyName`"", "COMPANY_INITIALS=`"$CompanyInitials`"", "LOCATION_NAME=`"$LocationName`"",
                "AGENT_MODE=`"$AgentMode`"")
                
            $process = Start-Process -NoNewWindow "msiexec.exe" -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if ($timedOut) {
                $process | kill
                Write-Error "Install timed out after 300 seconds."
            }
            elseif ($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Error "Install error code: $code."
            }

            Write-Output "AutoElevate installation complete"
        }
        Catch {
            $exception = $_.Exception
            Write-Error "Error: $exception"
        }
    }

    End {
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        if($error) {
            Exit 1
        }

        Exit 0
    }
}

if (-not(Get-Command 'Win_AutoElevate_Manage' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{ }
if($Uninstall) {
    $scriptArgs = @{
        Uninstall = $Uninstall
    }
}
else {
    $scriptArgs = @{
        LicenseKey      = $LicenseKey
        CompanyName     = $CompanyName
        CompanyInitials = $CompanyInitials
        LocationName    = $LocationName
        AgentMode       = $AgentMode
    }
}
 
Win_AutoElevate_Manage @scriptArgs