<#
.Synopsis
   Check IIS on Windows Server for Certificates expiring "soon"
.DESCRIPTION
   Checks the IIS sites for https bindings and then checks the associated
   SSL certificate to see if it is expiring "soon".  "Soon" is set to 60 days
   as the default.
.EXAMPLE
   CheckIISCerts
.INSTRUCTIONS
   Add this as a script check to your Windows Server that has IIS installed.
.NOTES
   Version: 1.1
   Author: ebdavison (nalantha on discord)
   Creation Date: 2022-08-08
   Updated: 2024-07-25 styx-tdo
#>

param
(
    $NumDays = 60
)

Import-Module WebAdministration

# $NumDays= 60

$days = (Get-Date).AddDays($NumDays)
$TxtBindings = (& netsh http show sslcert) | select-object -skip 3 | out-string
$nl = [System.Environment]::NewLine
$Txtbindings = $TxtBindings -split "$nl$nl"
$BindingsList = foreach ($Binding in $Txtbindings) {
    if ($Binding -ne "") {
        $Binding = $Binding -replace "  ", "" -split ": "
        [pscustomobject]@{
            IPPort          = ($Binding[1] -split "`n")[0]
            CertificateHash = ($Binding[2] -split "`n" -replace '[^a-zA-Z0-9]', '')[0]
            AppID           = ($Binding[3] -split "`n")[0]
            CertStore       = ($Binding[4] -split "`n")[0]
        }
    }
}

if ($BindingsList.Count -eq 0) {
    $CertState = "Healthy - No certificate bindings found."
    Write-Output $CertState
    exit 0
}

$CertState = foreach ($bind in $bindingslist) {

    $bindsite = $bind.ipport.Split(":")[0]
    
    $CertFileWH = Get-ChildItem -path "CERT:LocalMachine\WebHosting" | Where-Object -Property ThumbPrint -eq $bind.CertificateHash

    $CertFileMY = Get-ChildItem -path "CERT:LocalMachine\MY" | Where-Object -Property ThumbPrint -eq $bind.CertificateHash

    if ($bindsite -eq "0.0.0.0") {
        continue
    }
    
    if ($certFileWH.NotAfter) {
        if ($certFileWH.NotAfter -lt $Days) { 
	    if (certfileWH.FriendlyName) {
                "$($bindsite) = $($certfileWH.FriendlyName) / $($certfileWH.thumbprint) will expire on $($certfileWH.NotAfter)" 
	    }else{
                "$($bindsite) = $($certfileWH.Subject) / $($certfileWH.thumbprint) will expire on $($certfileWH.NotAfter)" 
            }
        }
    }

    if ($certFileMY.NotAfter) {
        if ($certFileMY.NotAfter -lt $Days) { 
	    if (certfileMY.FriendlyName) {
                "$($bindsite) = $($certfileMY.FriendlyName) / $($certfileMY.thumbprint) will expire on $($certfileMY.NotAfter)" 
	    }else{
                "$($bindsite) = $($certfileMY.Subject) / $($certfileMY.thumbprint) will expire on $($certfileMY.NotAfter)" 
            }
        }
    }
}

if (!$certState){
    $CertState = "Healthy - No Expiring Certificates"; 
    Write-Output $CertState
    exit 0
} else {
    Write-Output $CertState
    exit 1
}
