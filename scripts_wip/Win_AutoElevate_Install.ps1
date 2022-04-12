<#
.Synopsis
   Installs AutoElevate silently.
.DESCRIPTION
    Downloads the AutoElevate executable and installs silently.
    Navigate to the AutoElevate MSP dashboard > settings and get your license key.
    Fill out the remaining variables based on what you've setup in AutoElevate.
.EXAMPLE
    Win_AutoElevate_Install -LicenseKey "abcdefg" -CompanyName "MyCompany" -LocationName "Main" -AgentMode live
.EXAMPLE
    Win_AutoElevate_Install -LicenseKey "abcdefg" -CompanyName "MyCompany" -CompanyInitials "MC" -LocationName "Main" -AgentMode live
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
   Creation Date: 2022-04-12
#>

Param(
    [Parameter(Mandatory)]
    [string]$LicenseKey,

    [Parameter(Mandatory)]
    [string]$CompanyName,
    
    [string]$CompanyInitials,
    
    [Parameter(Mandatory)]
    [string]$LocationName,
    
    [Parameter(Mandatory)]
    [ValidateSet("live", "policy", "audit", "technician")]
    $AgentMode
)

function Win_AutoElevate_Install {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$LicenseKey,

        [Parameter(Mandatory)]
        [string]$CompanyName,
        
        [string]$CompanyInitials,
        
        [Parameter(Mandatory)]
        [string]$LocationName,
        
        [Parameter(Mandatory)]
        [ValidateSet("live", "policy", "audit", "technician")]
        $AgentMode
    )

    Begin {
        if ($null -ne (Get-Service | Where-Object { $_.DisplayName -Match "AutoElevate" })) {
            Write-Output "AutoElevate already installed."
            Exit 0
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" }
    }

    Process {
        Try {
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

        Exit 0
    }
}

if (-not(Get-Command 'Win_AutoElevate_Install' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{
    LicenseKey = $LicenseKey
    CompanyName = $CompanyName
    CompanyInitials = $CompanyInitials
    LocationName = $LocationName
    AgentMode = $AgentMode
}
 
Win_AutoElevate_Install @scriptArgs