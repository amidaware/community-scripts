<#
.Synopsis
   Installs the security program Heimdal (heimdalsecurity.com) silently using key set a client level
.DESCRIPTION
   Create custom field at client level and fill with key (call it Heimdal Key), run "-HeimdalKey {{client.Heimdal Key}}" as script argument. Heimdal will install silently with no interaction.
   #>

param (
    [string] $HeimdalKey
    )
    
#Set custom field at client level with your install key - set "-HeimdalKey {{client.Heimdal Key}} as script arguement"#
###Download and Install Heimdal Client###

##CHANGE THIS##
$downloadURL = "https://prodcdn.heimdalsecurity.com/setup/HeimdalLatestVersion.msi"


#---------------------------------------------------------------#

#Look for Heimdal Folder, if not exist then create
$folderName = "Heimdal Installer"
$Path="C:\"+$folderName

if (!(Test-Path $Path))
{
New-Item -itemType Directory -Path C:\ -Name $FolderName
}
else
{
write-host "Folder already exists"
}

#Download MSI for Heimdal
Invoke-WebRequest -Uri "$downloadURL" -OutFile "C:\Heimdal Installer\Heimdal.msi"

#Install Heimdal Silent
msiexec /qn /i "C:\Heimdal Installer\Heimdal.msi" heimdalkey="$HeimdalKey"
