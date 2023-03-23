<#
.Synopsis
   Installs CyberCNS Agent
.DESCRIPTION
   Downloads the CyberCNS Agent executable and installs based on selection.
   Must specify -Type when installing. Probe for the CyberCNS Probe, LightWeight for CyberCNS Lightweight Agent, and Scan for a single scan.
   Tenant expects your CyberCNS tenant name, the mycompany part of mycompany.cybercns.com (unless obtained through a third-party like Pax8, in which ase you may have to analyze your URL more closely).
   Retrieve the CompanyID, ClientID, and ClientSecret from CyberCNS.
.INSTRUCTIONS
	1. Download the CyberCNS executable and upload to a location accessable by your clients.
    2. Navigate to your CyberCNS portal and create a Probe/Agent deployment.
    3. In Tactical RMM, Go to Settings >> Global Settings >> Key Store and create the following custom fields and fill with the required information: 
		a) CyberCNSExeLocation as type text - this is the location of the agent executable that you downloaded in step 1.
        b) CyberCNSTenant as type text - this is your CyberCNS tenant, usually formatted like "tacticalrmm".
		c) CyberCNSPortalHost as type text - this is your CyberCNS hostname from the URL like "portaluswest2.mycybercns.com".
    4. In Tactical RMM, Go to Settings >> Global Settings >> Custom Fields and under Clients, create the following custom fields: 
        a) CyberCNSCompanyID as type text
        b) CyberCNSClientID as type text
        c) CyberCNSClientSecret as type text
    4. In Tactical RMM, Right-click on each client and select Edit. Fill in the CyberCNSCompanyID, CyberCNSClientID, 
        and CyberCNSClientSecret.
    5. Create the follow script arguments
		a) -ExecutableLocation {{global.CyberCNSExeLocation}}
        b) -Tenant {{global.CyberCNSTenant}}
        c) -CompanyID {{client.CyberCNSCompanyID}}
        d) -ClientID {{client.CyberCNSClientID}}
        e) -ClientSecret {{client.CyberCNSClientSecret}}
		f) -Portal {{global.CyberCNSPortalHost}}
        g) -Type Probe|LightWeight|Scan
    6. If you want to trigger an uninstall of the agent, add the following variable:
        a) -Uninstall
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2022-04-07
   Updated 2023-01-25 1.1 bionemesis
#>

Param(

	[Parameter(Mandatory)]
	[string]$ExecutableLocation,

    [Parameter(Mandatory)]
    [string]$Tenant,

    [Parameter(Mandatory)]
    [string]$CompanyID,

    [Parameter(Mandatory)]
    [string]$ClientID,

    [Parameter(Mandatory)]
    [string]$ClientSecret,

	[Parameter(Mandatory)]
	[string]$Portal,

    [Parameter(Mandatory)]
    [ValidateSet("Probe", "LightWeight", "Scan")]
    $Type,

    [switch]$Uninstall
)

function Win_CyberCNS_Install {
    [CmdletBinding()]
    Param(
		[Parameter(Mandatory)]
		[string]$ExecutableLocation,

        [Parameter(Mandatory)]
        [string]$Tenant,

        [Parameter(Mandatory)]
        [string]$CompanyID,

        [Parameter(Mandatory)]
        [string]$ClientID,

        [Parameter(Mandatory)]
        [string]$ClientSecret,

		[Parameter(Mandatory)]
		[string]$Portal,

        [Parameter(Mandatory)]
        [ValidateSet("Probe", "LightWeight", "Scan")]
        $Type,

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
                if (Test-Path "C:\Program Files (x86)\CyberCNSAgentV2\cybercnsagentv2.exe.new") {
                    Move-Item "C:\Program Files (x86)\CyberCNSAgentV2\cybercnsagentv2.exe.new" "C:\Program Files (x86)\CyberCNSAgentV2\cybercnsagentv2.exe"
                }

                $monitor = Get-Service -Name "CyberCNSAgentMonitor" -ErrorAction SilentlyContinue
                if ($monitor.Length -gt 0) {
                    Write-Output "Stopping service..."
                    Stop-Service -Name "CyberCNSAgentMonitor"
                    Write-Output "Removing service..."
                    & "sc.exe" delete 'CyberCNSAgentMonitor'
                }

                $service = Get-Service -Name "CyberCNSAgentV2" -ErrorAction SilentlyContinue
                if ($service.Length -gt 0) {
                    Write-Output "Stopping service..."
                    Stop-Service -Name "CyberCNSAgentV2"
                    & "sc.exe" delete 'CyberCNSAgentV2'
                }
               
                if (Test-Path "C:\Program Files (x86)\CyberCNSAgentV2\cybercnsagentv2.exe") {
                    Write-Output "Running agent uninstaller..."
                    & "C:\Program Files (x86)\CyberCNSAgentV2\cybercnsagentv2.exe" -r
                }

                Write-Output "CyberCNS uninstall complete."
                return
            }

            $source = $ExecutableLocation
            $destination = "C:\packages$random\cybercnsagent.exe"
            Invoke-WebRequest -Uri $source -OutFile $destination
            $arguments = @("-c $CompanyID", "-a $ClientID", "-s $ClientSecret", "-b $Portal", "-e $Tenant", "-i $Type")
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
	ExecutableLocation = $ExecutableLocation
    Tenant       = $Tenant
    CompanyID    = $CompanyID
    ClientID     = $ClientID
    ClientSecret = $ClientSecret
	Portal       = $Portal
    Type         = $Type
    Uninstall    = $Uninstall
}
 
Win_CyberCNS_Install @scriptArgs
