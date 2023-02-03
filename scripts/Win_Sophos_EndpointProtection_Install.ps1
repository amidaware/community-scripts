<#
.SYNOPSIS
    Installs Sophos Endpoint via the Sophos API https://developer.sophos.com/apis

.REQUIREMENTS
    You will need API credentials to use this script.  The instructions are slightly different depending who you are. 
    (Only Step 1 Required For API Credentials)
    For Partners : https://developer.sophos.com/getting-started 
    For Organizations: https://developer.sophos.com/getting-started-organization 
    For Tenants	: https://developer.sophos.com/getting-started-tenant 

.INSTRUCTIONS
    1. Get your API Credentials (Client Id, Client Secret) using the steps in the Requirements section
    2. In Tactical RMM, Go to Settings >> Global Settings >> Custom Fields and under Clients, create the following custom fields: 
        a) SophosTenantName as type text
        b) SophosClientId as type text
        c) SophosClientSecret as type text
    3. In Tactical RMM, Right-click on each client and select Edit.  Fill in the SophosTenantName, SophosClientId, and SophosClientSecret.  
       Make sure the SophosTenantName is EXACTLY how it is displayed in your Sophos Partner / Central Dashboard.  A partner can find the list of tenants on the left menu under Sophos Central Customers
    4. Create the follow script arguments
        a) -ClientId {{client.SophosClientId}}
        b) -ClientSecret {{client.SophosClientSecret}}
        c) -TenantName {{client.SophosTenantName}}
        d) -Products (Optional Parameter) - A list of products to install, comma-separated.  Available options are: antivirus, intercept, mdr, deviceEncryption or all.  Example - To install Antivirus, Intercept, and Device encryption you would pass "antivirus,intercept,deviceEncryption".  
		
.NOTES
	V1.0 Initial Release by https://github.com/bc24fl/tacticalrmm-scripts/
	V1.1 Added error handling for each Invoke-Rest Call for easier troubleshooting and graceful exit.
	V1.2 Added support for more than 100 tenants.
    V1.3 Removed Chocolately dependency
    v1.4 Fixed logit handling
	
#>

Param(
    [Parameter(Mandatory)]
    [string]$ClientId,

    [Parameter(Mandatory)]
    [string]$ClientSecret,

    [Parameter(Mandatory)]
    [string]$TenantName,

    [string]$Products = "antivirus,intercept",

    [switch]$Uninstall
)

function Get-InstallerUrl {
    Param(
        [Parameter(Mandatory)]
        [string]$ClientId,

        [Parameter(Mandatory)]
        [string]$ClientSecret,

        [Parameter(Mandatory)]
        [int]$ProductType
    )

    $urlAuth = "https://id.sophos.com/api/v2/oauth2/token"
    $urlWhoami = "https://api.central.sophos.com/whoami/v1"
    $urlTenant = "https://api.central.sophos.com/partner/v1/tenants?pageTotal=true"
    $authBody = @{
        "grant_type"    = "client_credentials"
        "client_id"     = $ClientId
        "client_secret" = $ClientSecret
        "scope"         = "token"
    }

    $authResponse = (Invoke-RestMethod -Method 'post' -Uri $urlAuth -Body $authBody)
    $authToken = $authResponse.access_token
    $authHeaders = @{Authorization = "Bearer $authToken" }
    if ($authToken.length -eq 0) {
        throw "Error, no authentication token received.  Please check your api credentials.  Exiting script."
    }

    $whoAmIResponse = (Invoke-RestMethod -Method 'Get' -headers $authHeaders -Uri $urlWhoami)
    $myId = $whoAmIResponse.Id
    $myIdType = $whoAmIResponse.idType
    if ($myIdType.length -eq 0) {
        throw "Error, no Whoami Id Type received.  Please check your api credentials or network connections.  Exiting script."
    }

    $TextInfo = (Get-Culture).TextInfo
    $myIdType = $TextInfo.ToTitleCase($myIdType)

    $requestHeaders = @{
        "Authorization" = "Bearer $authToken"
        "X-$myIdType-ID"  = $myId
    }

    # Cycle through all tenants until a tenant match, or all pages have exhausted.  
    $currentPage = 1
    do {
        Write-Output "Looking for tenant on page $currentPage.  Please wait..."
        
        if ($currentPage -ge 2) {
            Start-Sleep -s 5
            $urlTenant = "https://api.central.sophos.com/partner/v1/tenants?page=$currentPage"
        }
        
        $tenantResponse = (Invoke-RestMethod -Method 'Get' -headers $requestHeaders -Uri $urlTenant)
        $tenants = $tenantResponse.items
        $totalPages	= [int]$tenantResponse.pages.total
        
        foreach ($tenant in $tenants) {
            if ($tenant.name -eq $TenantName) {
                $tenantRegion = $tenant.dataRegion
                $tenantId = $tenant.id
            }
        }
        $currentPage += 1
    } until( $currentPage -gt $totalPages -Or ($tenantId.length -gt 1 ) )

    if ($tenantId.length -eq 0) {
        throw "Error, no tenant found with the provided name.  Please check the name and try again.  Exiting script."
    }

    $requestHeaders = @{
        'Authorization' = "Bearer $authToken"
        'X-Tenant-ID'   = $tenantId 
    }

    $urlEndpoint = "https://api-$tenantRegion.central.sophos.com/endpoint/v1/downloads"
    $endpointDownloadResponse = (Invoke-RestMethod -Method 'Get' -headers $requestHeaders -Uri $urlEndpoint)
    $endpointInstallers = $endpointDownloadResponse.installers

    if ($endpointInstallers.length -eq 0) {
        throw "Error, no installers received.  Please check your api credentials or network connections.  Exiting script."
    }

    $installUrl = ""

    foreach ($installer in $endpointInstallers) {
        if ( ($installer.platform -eq "windows") -And ($installer.productName = "Sophos Endpoint Protection") ) {
            if ( ($ProductType -eq 1) -And ($installer.type = "computer") ) {
                # Workstation Install
                $installUrl = $installer.downloadUrl
            }
            elseif ( ( ($ProductType -eq 2) -Or ($ProductType -eq 3) ) -And ($installer.type = "server") ) {
                # Server Install
                $installUrl = $installer.downloadUrl
            }
            else {
                throw "Error, this script only supports producttype of 1) Work Station, 2) Domain Controller, or 3) Server."
            }
        }
    }

    return $installUrl
}

function Win_Sophos_EndpointProtection_Install {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$ClientId,

        [Parameter(Mandatory)]
        [string]$ClientSecret,

        [Parameter(Mandatory)]
        [string]$TenantName,

        [string]$Products,

        [switch]$Uninstall
    )

    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $random = ([char[]]([char]'a'..[char]'z') + 0..9 | sort { get-random })[0..12] -join ''
        if (-not(Test-Path "C:\packages$random")) { New-Item -ItemType Directory -Force -Path "C:\packages$random" | Out-Null }
    }

    Process {
        Try {
            $software = "Sophos Endpoint Agent";
            $installed = ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*).DisplayName -Match $software).Length -gt 0
            if ($installed -and -Not($Uninstall)) {
                Write-Output "Sophos already installed."
                return
            }

            if ($installed -and $Uninstall) {
                Write-Output "Uninstalling $software..."
                & "C:\Program Files\Sophos\Sophos Endpoint Agent\SophosUninstall.exe" --quiet
                return
            }

            if (-Not($installed) -and $Uninstall) {
                Write-Output "Sophos isn't installed."
                return
            }

            Write-Output "Sophos wasn't detected. Starting setup..."
            $error.clear()

            #check for class, default to workstation if can't get
            $osInfo = @{
                ProductType = 1
            }
            
            if (Get-CimClass | Where-Object { $_.CimCLassName -eq "Win32_OperatingSystem" }) {
                $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
            }

            Write-Output "Getting installer URL from API..."
            $installUrl = Get-InstallerUrl -ClientId $ClientId -ClientSecret $ClientSecret -ProductType $osInfo.ProductType
            Write-Output "Saving installer..."
            $outputPath = "C:\packages$random\SophosSetup.exe"
            Invoke-WebRequest -Uri $installUrl[-1] -OutFile $outputPath
            Write-Output "Starting Sophos Setup. Please wait, this will take a while..."
            $arguments = @("--products=" + ($Products -join ","), "--quiet")
            $process = Start-Process -NoNewWindow -FilePath $outputPath -ArgumentList $arguments -PassThru
            $timedOut = $null
            $process | Wait-Process -Timeout 1200 -ErrorAction SilentlyContinue -ErrorVariable timedOut
            if($timedOut) {
                $process | kill
                Write-Output "Install timed out after 1200 seconds."
            }
            elseif ($process.ExitCode -ne 0) {
                $code = $process.ExitCode
                Write-Output "Install error code: $code"
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

if (-not(Get-Command "Win_Sophos_EndpointProtection_Install" -ErrorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}

$scriptArgs = @{
    ClientId     = $ClientId
    ClientSecret = $ClientSecret
    TenantName   = $TenantName
    Products     = $Products
    Uninstall    = $Uninstall
}

Win_Sophos_EndpointProtection_Install @scriptArgs
