<# 
.SYNOPSIS
    Script permettant de récupérer et analyser les utilisateurs dont le mot de passe est sur le point d'expirer dans Active Directory.
.DESCRIPTION
    Ce script se connecte à Active Directory pour rechercher les utilisateurs dans une unité organisationnelle spécifiée.
    Il récupère la date de dernière mise à jour du mot de passe pour chaque utilisateur et la compare à la politique de mot de passe du domaine.
    En fonction du nombre de jours restant avant l'expiration, les comptes sont classés en trois catégories :
        - Expiré : Le mot de passe a déjà expiré.
        - Critique : Le mot de passe est très proche de l'expiration, selon le seuil critique configuré.
        - Avertissement : Le mot de passe approche de l'expiration, selon le seuil d'avertissement configuré.
    Le script génère un rapport HTML contenant :
        • Les détails de la politique de mot de passe du domaine (durée maximale, durée minimale, longueur minimale, complexité, historique et seuils de verrouillage).
        • Un résumé statistique indiquant le nombre d'utilisateurs par catégorie.
        • Une liste détaillée des comptes répartis par catégorie.
    Les options de test ont été supprimées.
.PARAMETER TargetOU
    Spécifie l'OU dans laquelle rechercher les utilisateurs. Exemple : "OU=Utilisateurs,DC=domaine,DC=local".
.PARAMETER WarningThreshold
    Nombre de jours avant expiration déclenchant un avertissement (par défaut : 15).
.PARAMETER CriticalThreshold
    Nombre de jours avant expiration déclenchant une alerte critique (par défaut : 7).
.PARAMETER IncludeDisabled
    Indique si les comptes désactivés doivent être inclus dans le rapport (false par défaut).
.PARAMETER IncludeNeverExpires
    Indique si les comptes dont le mot de passe n'expire jamais doivent être inclus dans le rapport (false par défaut).
.EXAMPLE
    .\Check-PasswordExpiration.ps1 -TargetOU "OU=Utilisateurs,DC=domaine,DC=local"
    Exécute le script avec l'OU spécifiée et les seuils par défaut.
.EXAMPLE
    .\Check-PasswordExpiration.ps1 -TargetOU "OU=Utilisateurs,DC=domaine,DC=local" -WarningThreshold 20 -CriticalThreshold 10
    Exécute le script avec des seuils personnalisés pour les alertes d’avertissement et critiques.
.NOTES
    Author: Peter Quellennec
    Date: 27/05/25
    #public
#>
{{CallPowerShell7Lite}}

$TargetOU           = $env:TARGET_OU
$SmtpServer         = $env:SMTP_SERVER
$SmtpPort           = [int]$env:SMTP_PORT
$AdminEmail         = $env:ADMIN_EMAIL
$FromEmail          = $env:FROM_EMAIL
$WarningThreshold   = [int]$env:WARNING_THRESHOLD
$CriticalThreshold  = [int]$env:CRITICAL_THRESHOLD

function Convert-ToBoolean($value) {
    return $value -match '^(1|true|yes)$'
}

$IncludeDisabled       = Convert-ToBoolean $env:INCLUDE_DISABLED
$IncludeNeverExpires   = Convert-ToBoolean $env:INCLUDE_NEVER_EXPIRES
$GenerateReportOnly    = Convert-ToBoolean $env:GENERATE_REPORT_ONLY

if ($env:SMTP_CREDENTIAL_USERNAME -and $env:SMTP_CREDENTIAL_PASSWORD) {
    try {
        $SecurePassword = ConvertTo-SecureString $env:SMTP_CREDENTIAL_PASSWORD -AsPlainText -Force
        $SmtpCredential = New-Object System.Management.Automation.PSCredential ($env:SMTP_CREDENTIAL_USERNAME, $SecurePassword)
    } catch {
        Write-Error "Failed to create SMTP credentials: $_"
    }
}

function Test-Prerequisites {
    
    $adFeature = Get-WindowsFeature -Name AD-Domain-Services -ErrorAction Stop
    if ($adFeature.InstallState -ne 'Installed') {
        Write-Error "AD Domain Services ne sont pas installés. Arrêt du script."
        exit 1
    }
    
    if (-not $SmtpServer -or -not $SmtpPort) {
        Write-Error "Les variables `$SmtpServer et `$SmtpPort doivent être définies avant d'appeler cette fonction."
        exit 1
    }

    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Error "Module ActiveDirectory non trouvé. Arrêt du script."
        exit 1
    }

    Import-Module ActiveDirectory -ErrorAction Stop

    try {
        $dc = Get-ADDomainController -Discover -ErrorAction Stop
        Write-Host "Connexion réussie au contrôleur de domaine : $($dc.HostName)"
    }
    catch {
        Write-Error "Impossible de se connecter au contrôleur de domaine. Arrêt du script."
        exit 1
    }

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($SmtpServer, $SmtpPort)
        $tcpClient.Close()
        Write-Host "Connexion réussie au serveur SMTP : $SmtpServer":"$SmtpPort"
    }
    catch {
        Write-Error "Impossible de se connecter au serveur SMTP : $SmtpServer sur le port $SmtpPort. Arrêt du script."
        exit 1
    }
}

function Get-UserPasswordExpirationInfo {
    param (
        $user,
        $maxPasswordAge
    )

    $result = [PSCustomObject]@{
        Name            = $user.Name
        SamAccountName  = $user.SamAccountName
        Email           = $user.EmailAddress
        ExpirationDate  = $null
        DaysLeft        = $null
        Status          = "OK"
        Enabled         = $user.Enabled
        PasswordNeverExpires = $user.PasswordNeverExpires
    }

    if ($user.PasswordLastSet -eq $null) {
        $result.Status = "NeverLoggedIn"
        return $result
    }

    if ($user.PasswordNeverExpires) {
        $result.Status = "NeverExpires"
        return $result
    }

    $passwordExpirationDate = $user.PasswordLastSet + $maxPasswordAge
    $daysLeft = ($passwordExpirationDate - (Get-Date)).Days

    $result.ExpirationDate = $passwordExpirationDate
    $result.DaysLeft = $daysLeft

    if ($daysLeft -lt 0) {
        $result.Status = "Expired"
    }
    elseif ($daysLeft -le $CriticalThreshold) {
        $result.Status = "Critical"
    }
    elseif ($daysLeft -le $WarningThreshold) {
        $result.Status = "Warning"
    }

    return $result
}

function ConvertTo-HtmlReport {
    param (
        $expiredUsers,
        $criticalUsers,
        $warningUsers,
        $neverExpiresUsers,
        $neverLoggedInUsers,
        $disabledUsers,
        $targetOU,
        $passwordPolicy,
        $warningThreshold,
        $criticalThreshold
    )

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Rapport d'expiration des mots de passe</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        h2 { color: #333; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        th { background-color: #3498db; color: white; padding: 10px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        .expired { background-color: #ffdddd; }
        .critical { background-color: #fff3cd; }
        .warning { background-color: #ffe8cc; }
        .never-expires { background-color: #e7f3fe; }
        .never-logged { background-color: #f1f1f1; }
        .disabled { background-color: #f8f9fa; }
        .summary { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .policy { background-color: #e8f4f8; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .badge { padding: 3px 8px; border-radius: 3px; font-weight: bold; }
        .badge-expired { background-color: #dc3545; color: white; }
        .badge-critical { background-color: #ffc107; }
        .badge-warning { background-color: #fd7e14; color: white; }
        .badge-never { background-color: #17a2b8; color: white; }
        .badge-disabled { background-color: #6c757d; color: white; }
        .badge-neverlogged { background-color: #adb5bd; }
    </style>
</head>
<body>
    <h1>Rapport d'expiration des mots de passe</h1>
    
    <div class="policy">
        <h2>Politique de mot de passe du domaine</h2>
        <p><strong>Durée maximale du mot de passe:</strong> $($passwordPolicy.MaxPasswordAge.Days) jours</p>
        <p><strong>Durée minimale du mot de passe:</strong> $($passwordPolicy.MinPasswordAge.Days) jours</p>
        <p><strong>Longueur minimale:</strong> $($passwordPolicy.MinPasswordLength) caractères</p>
        <p><strong>Complexité requise:</strong> $($passwordPolicy.ComplexityEnabled)</p>
        <p><strong>Historique du mot de passe:</strong> $($passwordPolicy.PasswordHistoryCount) mots de passe</p>
        <p><strong>Verrouillage de compte:</strong> $($passwordPolicy.LockoutThreshold) tentatives (durée: $($passwordPolicy.LockoutDuration.Minutes) minutes, observation: $($passwordPolicy.LockoutObservationWindow.Minutes) minutes)</p>
    </div>
    
    <div class="summary">
        <p><strong>Seuil d'avertissement :</strong> $warningThreshold jours</p>
        <p><strong>Seuil critique :</strong> $criticalThreshold jours</p>
        <p><strong>Statistiques :</strong>
            <span class="badge badge-expired">Expirés: $($expiredUsers.Count)</span>
            <span class="badge badge-critical">Critiques: $($criticalUsers.Count)</span>
            <span class="badge badge-warning">Avertissement: $($warningUsers.Count)</span>
            <span class="badge badge-never">Expirent jamais: $($neverExpiresUsers.Count)</span>
            <span class="badge badge-neverlogged">Jamais connectés: $($neverLoggedInUsers.Count)</span>
            <span class="badge badge-disabled">Désactivés: $($disabledUsers.Count)</span>
        </p>
    </div>
"@

    if ($expiredUsers) {
        $html += "<h2>Comptes expirés <span class='badge badge-expired'>$($expiredUsers.Count)</span></h2>"
        $html += $expiredUsers | Select-Object Name, SamAccountName, Email, @{Name="ExpirationDate";Expression={$_.ExpirationDate.ToString("dd/MM/yyyy")}}, DaysLeft, Enabled | ConvertTo-Html -Fragment
    }

    if ($criticalUsers) {
        $html += "<h2>Comptes critiques <span class='badge badge-critical'>$($criticalUsers.Count)</span></h2>"
        $html += $criticalUsers | Select-Object Name, SamAccountName, Email,  @{Name="ExpirationDate";Expression={$_.ExpirationDate.ToString("dd/MM/yyyy")}}, DaysLeft, Enabled | ConvertTo-Html -Fragment
    }

    if ($warningUsers) {
        $html += "<h2>Comptes en avertissement <span class='badge badge-warning'>$($warningUsers.Count)</span></h2>"
        $html += $warningUsers | Select-Object Name, SamAccountName, Email,  @{Name="ExpirationDate";Expression={$_.ExpirationDate.ToString("dd/MM/yyyy")}}, DaysLeft, Enabled | ConvertTo-Html -Fragment
    }

    if ($IncludeNeverExpires -and $neverExpiresUsers) {
        $html += "<h2>Comptes avec mot de passe n expirant jamais <span class='badge badge-never'>$($neverExpiresUsers.Count)</span></h2>"
        $html += $neverExpiresUsers | Select-Object Name, SamAccountName, Email, Enabled | ConvertTo-Html -Fragment
    }

    if ($neverLoggedInUsers) {
        $html += "<h2>Comptes jamais connectés <span class='badge badge-neverlogged'>$($neverLoggedInUsers.Count)</span></h2>"
        $html += $neverLoggedInUsers | Select-Object Name, SamAccountName, Email, Enabled | ConvertTo-Html -Fragment
    }

    if ($IncludeDisabled -and $disabledUsers) {
        $html += "<h2>Comptes désactivés <span class='badge badge-disabled'>$($disabledUsers.Count)</span></h2>"
        $html += $disabledUsers | Select-Object Name, SamAccountName, Email,  @{Name="ExpirationDate";Expression={if($_.ExpirationDate){$_.ExpirationDate.ToString("dd/MM/yyyy")}else{"N/A"}}}, DaysLeft | ConvertTo-Html -Fragment
    }

    $html += @"
    <p style="margin-top: 30px; font-size: 0.9em; color: #666;">Généré le : $(Get-Date -Format "dd/MM/yyyy HH:mm")</p>
</body>
</html>
"@

    return $html
}

function Send-EmailReport {
    param(
        [string[]]$Recipients,
        [string]$Subject,
        [string]$Body,
        [string]$SmtpServer,
        [int]$Port = 25,
        [string]$FromAddress,
        [string[]]$Attachments
    )

    if ((Get-Date).DayOfWeek -ne 'Monday') {
        Write-Host "Les emails ne sont envoyés que le lundi. Arrêt de l'envoi."
        return
    }
    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $FromAddress
    foreach ($recipient in $Recipients) { $mailMessage.To.Add($recipient) }
    $mailMessage.Subject = $Subject
    $mailMessage.Body = $Body
    $mailMessage.IsBodyHtml = $true
     if ($Attachments) {
        foreach ($att in $Attachments) {
            $mailMessage.Attachments.Add((New-Object System.Net.Mail.Attachment($att)))
        }
    }
    $smtpClient = New-Object System.Net.Mail.SmtpClient($SmtpServer, $Port)
    try {
        $smtpClient.Send($mailMessage)
        Write-Host "Email sent successfully."
    }
    catch {
        Write-Error "Failed to send email: $_"
    }
}

function Send-UserNotification {
    param(
        [string]$Recipient,
        [string]$Subject,
        [string]$Body,
        [string]$SmtpServer,
        [int]$Port = 25,
        [string]$FromAddress
    )
    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $FromAddress
    $mailMessage.To.Add($Recipient)
    $mailMessage.Subject = $Subject
    $mailMessage.Body = $Body
    $mailMessage.IsBodyHtml = $true
    $smtpClient = New-Object System.Net.Mail.SmtpClient($SmtpServer, $Port)
    try {
        $smtpClient.Send($mailMessage)
        Write-Host "Notification sent to $Recipient."
    }
    catch {
        Write-Error "Failed to send notification to ${Recipient}: $_"
    }
}

try {
    $passwordPolicy = Get-ADDefaultDomainPasswordPolicy
    $maxPasswordAge = $passwordPolicy.MaxPasswordAge
    
    Write-Host "Politique de mot de passe du domaine:"
    Write-Host "  - Durée maximale: $($maxPasswordAge.Days) jours"
    Write-Host "  - Durée minimale: $($passwordPolicy.MinPasswordAge.Days) jours"
    Write-Host "  - Longueur minimale: $($passwordPolicy.MinPasswordLength) caractères"
    Write-Host "  - Complexité: $($passwordPolicy.ComplexityEnabled)"
}
catch {
    Write-Error "Erreur lors de la récupération de la politique de mot de passe : $_"
    exit 1
}

try {
    $ouExists = Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction Stop
}
catch {
    Write-Error "L'OU spécifiée n'existe pas ou est inaccessible : $TargetOU"
    exit 1
}

$filter = "PasswordNeverExpires -eq `$false"
if ($IncludeDisabled) {
    $filter = "($filter) -or (Enabled -eq `$false)"
}
if ($IncludeNeverExpires) {
    $filter = "PasswordNeverExpires -eq `$true -or ($filter)"
}

try {
    Write-Host "Recherche des utilisateurs dans l'OU: $TargetOU"
    $users = Get-ADUser -SearchBase $TargetOU -Filter * -Properties Name, SamAccountName, EmailAddress, PasswordLastSet, PasswordNeverExpires, Enabled | Where-Object {
        if ($IncludeDisabled -and $IncludeNeverExpires) { $true }
        elseif ($IncludeDisabled) { -not $_.PasswordNeverExpires }
        elseif ($IncludeNeverExpires) { $_.Enabled }
        else { $_.Enabled -and (-not $_.PasswordNeverExpires) }
    }
    
    Write-Host "Nombre d'utilisateurs trouvés: $($users.Count)"
}
catch {
    Write-Error "Erreur lors de la récupération des utilisateurs : $_"
    exit 1
}

if (-not $users) {
    Write-Host "Aucun utilisateur trouvé dans l'OU spécifiée avec les critères actuels."
    exit
}

$reportData = foreach ($user in $users) {
    if ($user.PasswordNeverExpires -or ($user.PasswordLastSet -eq $null -and -not $IncludeNeverExpires)) {
        [PSCustomObject]@{
            Name            = $user.Name
            SamAccountName  = $user.SamAccountName
            Email           = $user.EmailAddress
            ExpirationDate  = $null
            DaysLeft        = $null
            Status          = if ($user.PasswordNeverExpires) { "NeverExpires" } else { "NeverLoggedIn" }
            Enabled         = $user.Enabled
            PasswordNeverExpires = $user.PasswordNeverExpires
        }
    }
    else {
        Get-UserPasswordExpirationInfo -user $user -maxPasswordAge $maxPasswordAge
    }
}

$expiredUsers = $reportData | Where-Object { $_.Status -eq "Expired" } | Sort-Object DaysLeft
$criticalUsers = $reportData | Where-Object { $_.Status -eq "Critical" } | Sort-Object DaysLeft
$warningUsers = $reportData | Where-Object { $_.Status -eq "Warning" } | Sort-Object DaysLeft
$neverExpiresUsers = $reportData | Where-Object { $_.Status -eq "NeverExpires" }
$neverLoggedInUsers = $reportData | Where-Object { $_.Status -eq "NeverLoggedIn" }
$disabledUsers = $reportData | Where-Object { $_.Enabled -eq $false }

$reportFileName = "PasswordExpirationReport_$(Get-Date -Format 'yyyyMMdd_HHmm').html"
$htmlReport = ConvertTo-HtmlReport -expiredUsers $expiredUsers -criticalUsers $criticalUsers -warningUsers $warningUsers -neverExpiresUsers $neverExpiresUsers -neverLoggedInUsers $neverLoggedInUsers -disabledUsers $disabledUsers -targetOU $TargetOU -passwordPolicy $passwordPolicy -warningThreshold $WarningThreshold -criticalThreshold $CriticalThreshold
$htmlReport | Out-File $reportFileName -Encoding UTF8

Write-Host "Rapport généré avec succès : $reportFileName"
Write-Host "Résumé :"
Write-Host "  - Comptes expirés: $($expiredUsers.Count)"
Write-Host "  - Comptes critiques: $($criticalUsers.Count)"
Write-Host "  - Comptes en avertissement: $($warningUsers.Count)"
Write-Host "  - Comptes expirant jamais: $($neverExpiresUsers.Count)"
Write-Host "  - Comptes jamais connectés: $($neverLoggedInUsers.Count)"
Write-Host "  - Comptes désactivés: $($disabledUsers.Count)"

if ($GenerateReportOnly) {
    Write-Host "Option GenerateReportOnly activée, rapport généré uniquement. Arrêt du script."
    exit 0
}

foreach ($user in $reportData | Where-Object { $_.Status -in @("Warning", "Critical", "Expired") }) {
    if ($user.Email) {  
        $expirationDate = if ($user.ExpirationDate) { $user.ExpirationDate.ToString("dd/MM/yyyy") } else { "N/A" }
        $subject = "Avertissement: Expiration de votre mot de passe"
        $body = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; }
        .warning { color: #fd7e14; }
        .critical { color: #dc3545; }
        .expired { color: #6c757d; }
    </style>
</head>
<body>
    <p>Bonjour $($user.Name),</p>
    <p>Votre mot de passe est dans un état <strong class='$($user.Status.ToLower())'>$($user.Status)</strong>.</p>
    <p><strong>Date d'expiration:</strong> $expirationDate</p>
    <p>Veuillez mettre à jour votre mot de passe dès que possible pour éviter tout problème d'accès.</p>
    <p>Cordialement,</p>
    <p>Équipe IT</p>
</body>
</html>
"@
        Send-UserNotification -Recipient $user.Email -Subject $subject -Body $body -SmtpServer $SmtpServer -Port $SmtpPort -FromAddress $FromEmail
    }
    else {
        Write-Warning "L'utilisateur $($user.Name) n'a pas d'adresse email définie dans Active Directory."
    }
}

if ($reportData.Count -gt 0) {
    $adminEmails = $AdminEmail      
    $smtpServer = $SmtpServer          
    $smtpPort = $SmtpPort              
    $fromAddress = $FromEmail          
    $subject = "Rapport hebdomadaire d'expiration des mots de passe"
    $body = $htmlReport                
    Send-EmailReport -Recipients $adminEmails -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -FromAddress $fromAddress -Attachments @()
}

