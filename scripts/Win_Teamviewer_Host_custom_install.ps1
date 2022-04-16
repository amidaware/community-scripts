<#
.SYNOPSIS
    Installs TeamViewer Host customized with API and CustomID, only TeamViewer Corporate.

.REQUIREMENTS
    You will need API and custom ID to use this script.
    You will need to upload TeamViewer Host msi on a web url

.INSTRUCTIONS
    1. Create TeamViewer Customized Host with assignment of Host.
    2. Take notes of token of assignation and of configuration ID.
    3. Download MSI file and upload it on your website.
    4. In Tactical RMM, Global Settings -> Custom Fields, create custom fields for clients, so that you can create customized hosts for clients and not for users.
    5. Fill in:
        a) TeamViewerAPI -> Text
        b) CUSTOMIDTW -> Text
        c) LinkMSITW -> Text -> the only to fill in on global settings with your link to MSI, this will be the same for all clients.
    6. Compile for clients:
        a) TeamViewerAPI with token of assignation.
        b) CUSTOMIDTW with custom ID.
    7. Now when you will launch the script it will install TeamViewer customized Host with auto assignation and easy access already activated.

.NOTES
	V1.0 Initial Release
	
#>
param (
   [string] $urlmsitw,
   [string] $customidtw,
   [string] $apitw
)

(New-Object Net.WebClient).Downloadfile("$urlmsitw", "$env:Temp\TeamViewer_Host.msi")
msiexec.exe /i "$env:Temp\TeamViewer_Host.msi" /qn CUSTOMCONFIGID=$customidtw APITOKEN=$apitw ASSIGNMENTOPTIONS="--grant-easy-access"
