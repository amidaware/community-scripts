<#
.Synopsis
   Installs CyberCNS Agent
.DESCRIPTION
   Downloads the CyberCNS Agent executable and installs based on selection.
   Must specify -Type when installing. Probe for the CyberCNS Probe, LightWeight for CyberCNS Lightweight Agent, and Scan for a single scan.
   Tenant expects your CyberCNS tenant name, the mycompany part of mycompany.cybercns.com.
   Retrieve the CompanyID, ClientID, and ClientSecret from CyberCNS.
.EXAMPLE
    Win_CyberCNS_Install -Type Probe
.EXAMPLE
    Win_CyberCNS_Install -Type Agent
.EXAMPLE
    Win_CyberCNS_Install -Type Scan
.INSTRUCTIONS
	1. Download the CyberCNS executable and upload to a location accessable by your clients.
    2. Navigate to your CyberCNS portal and create a Probe/Agent deployment.
    3. In Tactical RMM, Go to Settings >> Global Settings >> Custom Fields and under Clients, create the following custom fields: 
		a) ExecutableLocation as type text
        b) CyberCNSTenant as type text
        c) CyberCNSCompanyID as type text
        d) CyberCNSClientID as type text
        e) CyberCNSClientSecret as type text
		f) Portal as type text
        g) CyberCNSType as type Dropdown Multiple with options Probe, LightWeight, and Scan
    4. In Tactical RMM, Right-click on each client and select Edit. Fill in the CyberCNSTenant, CyberCNSCompanyID, CyberCNSClientID, 
        and CyberCNSClientSecret.
    5. Create the follow script arguments
		a) -ExecutableLocation {{client.ExecutableLocation}}
        b) -Tenant {{client.CyberCNSTenant}}
        c) -CompanyID {{client.CyberCNSCompanyID}}
        d) -ClientID {{client.CyberCNSClientID}}
        e) -ClientSecret {{client.CyberCNSClientSecret}}
		f) -Portal {{client.Portal}}
        g) -Type {{client.CyberCNSType}}
.NOTES
   Version: 1.0
   Author: redanthrax
   Creation Date: 2022-04-07
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
    $Type
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
        $Type
    )

    Begin {
        if ($null -ne (Get-Service | Where-Object { $_.DisplayName -Match "CyberCNS" })) {
            Write-Output "CyberCNS already installed."
            Exit 0
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" }
    }

    Process {
        Try {
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
}
 
Win_CyberCNS_Install @scriptArgs
