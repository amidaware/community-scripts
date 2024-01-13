<#
.Synopsis
   Installs CyberCNS Agent
.DESCRIPTION
   Downloads the CyberCNS Agent executable and installs.
.INSTRUCTIONS
    1. Navigate to your CyberCNS portal and create a Probe/Agent deployment.
    2. In Tactical RMM, Go to Settings >> Global Settings >> Custom Fields and under Clients,
        create the following custom fields: 
        a) CyberCNSCompanyID as type text
        b) CyberCNSTenantID as type text
    3. In Tactical RMM, Right-click on each client and select Edit. Fill in the 
        CyberCNSCompanyID and CyberCNSTenantID.
    4. Create the follow script arguments
        a) -CompanyID {{client.CyberCNSCompanyID}}
        b) -TenantID {{client.CyberCNSTentantID}}
    5. If you want to trigger an uninstall of the agent, add the following variable:
        a) -Uninstall
.NOTES
   Version: 1.2
   Author: redanthrax
   Creation Date: 2022-04-07
   Updated 2023-01-25 1.1 bionemesis
   Updated 2024-01-01 redanthrax for ConnectSecure v4
#>

Param(
    [Parameter(Mandatory)]
    [string]$CompanyID,

    [Parameter(Mandatory)]
    [string]$TenantID,

    [switch]$Uninstall
)

function Win_CyberCNS_Install {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$CompanyID,

        [Parameter(Mandatory)]
        [string]$TenantID,

        [switch]$Uninstall
    )

    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
    }

    Process {
        Try {
            if ($null -ne (Get-Service | Where-Object { $_.DisplayName -Match "CyberCNS" }) -and -Not($Uninstall)) {
                Write-Output "CyberCNS already installed."
                return
            }
            if ($Uninstall) {
                $service = Get-Service -Name "CyberCNSAgent" -ErrorAction SilentlyContinue
                if ($service.Length -gt 0) {
                    Write-Output "Stopping service..."
                    Stop-Service -Name "CyberCNSAgent"
                    & "sc.exe" delete 'CyberCNSAgent'
                }
               
                if (Test-Path "C:\Program Files (x86)\CyberCNSAgent\cybercnsagent.exe") {
                    Write-Output "Running agent uninstaller..."
                    & "C:\Program Files (x86)\CyberCNSAgent\cybercnsagent.exe" -r
                }

                Write-Output "CyberCNS uninstall complete."
                return
            }


            $source = Invoke-RestMethod "https://configuration.myconnectsecure.com/api/v4/configuration/agentlink?ostype=windows"
            $destination = "C:\packages$random\cybercnsagent.exe"
            Invoke-WebRequest -Uri $source -OutFile $destination
            $arguments = @("-c $CompanyID", "-e $TenantID", "-i")
            $process = Start-Process -NoNewWindow -FilePath $destination -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if ($timedOut) {
                $process | kill
                Write-Output "Install timed out after 300 seconds."
            }
            elseif ($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Output "Install error code: $code."
            }
        }
        Catch {
            $exception = $_.Exception
            Write-Output "Error: $exception"
        }
    }

    End {
        if (Test-Path "C:\packages$random") {
            Remove-Item -Path "C:\packages$random" -Recurse -Force
        }

        if ($error) {
            Exit 1
        }

        Exit 0
    }
}

if (-not(Get-Command 'Win_CyberCNS_Install' -errorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}
 
$scriptArgs = @{
    CompanyID          = $CompanyID
    TenantID           = $TenantID
    Uninstall          = $Uninstall
}
 
Win_CyberCNS_Install @scriptArgs
