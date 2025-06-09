<#
.SYNOPSIS
    Ensures the script is executed using PowerShell 7 or higher.
.DESCRIPTION
    This script verifies whether it is running in a PowerShell 7+ environment. 
    If not, and if PowerShell 7 (pwsh) is available on the system, it re-invokes itself using pwsh, passing along any parameters.
    If pwsh is not found, the script outputs a message and exits with an error code.
    Once running in PowerShell 7 or higher, it sets the output rendering mode to plaintext for consistent formatting.
.NOTES
    Author: PQU
    Date: 29/04/2025
    #public
.CHANGELOG
  22.05.25 SAN Added UTF8 to fix encoding issue with russian & french chars
  06.06.25 PQU Added support for multiple admin emails
#>
if (!($PSVersionTable.PSVersion.Major -ge 7)) {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        pwsh -File "`"$PSCommandPath`"" @PSBoundParameters
        exit $LASTEXITCODE
    } else {
        Write-Output "ERROR: PowerShell 7 is not available. Exiting."
        exit 1
    }
}
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$PSStyle.OutputRendering = "plaintext"

$TargetOU           = $env:TARGET_OU
$SmtpServer         = $env:SMTP_SERVER
$SmtpPort           = [int]$env:SMTP_PORT
$AdminEmails        = $env:ADMIN_EMAIL -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$FromEmail          = $env:FROM_EMAIL
$WarningThreshold   = [int]$env:WARNING_THRESHOLD
$CriticalThreshold  = [int]$env:CRITICAL_THRESHOLD
$EmailSignature     = $env:EMAIL_SIGNATURE

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
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f9f9f9;
            color: #333;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            padding: 30px;
            background-color: #fff;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.05);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        .section {
            margin-bottom: 30px;
        }
        .badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 5px;
            font-weight: bold;
            margin-right: 10px;
        }
        .badge-expired { background-color: #dc3545; color: white; }
        .badge-critical { background-color: #ffc107; color: #333; }
        .badge-warning { background-color: #fd7e14; color: white; }
        .badge-never { background-color: #17a2b8; color: white; }
        .badge-neverlogged { background-color: #adb5bd; }
        .badge-disabled { background-color: #6c757d; color: white; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        th, td {
            padding: 12px;
            border-bottom: 1px solid #ddd;
            text-align: left;
        }
        th {
            background-color: #3498db;
            color: white;
        }
        .footer {
            margin-top: 40px;
            font-size: 0.9em;
            color: #777;
            text-align: center;
        }
    </style>
</head>
<body>
<div class="container">
    <h1>Rapport d'expiration des mots de passe</h1>

    <div class="section">
        <h2>Politique de mot de passe du domaine</h2>
        <p><strong>Durée maximale:</strong> $($passwordPolicy.MaxPasswordAge.Days) jours</p>
        <p><strong>Durée minimale:</strong> $($passwordPolicy.MinPasswordAge.Days) jours</p>
        <p><strong>Longueur minimale:</strong> $($passwordPolicy.MinPasswordLength) caractères</p>
        <p><strong>Complexité requise:</strong> $($passwordPolicy.ComplexityEnabled)</p>
        <p><strong>Historique:</strong> $($passwordPolicy.PasswordHistoryCount) mots de passe</p>
        <p><strong>Verrouillage:</strong> $($passwordPolicy.LockoutThreshold) tentatives (durée: $($passwordPolicy.LockoutDuration.Minutes) min)</p>
    </div>

    <div class="section">
        <h2>Statistiques globales</h2>
        <p>
            <span class="badge badge-expired">Expirés: $($expiredUsers.Count)</span>
            <span class="badge badge-critical">Critiques: $($criticalUsers.Count)</span>
            <span class="badge badge-warning">Avertissements: $($warningUsers.Count)</span>
            <span class="badge badge-never">Expirent jamais: $($neverExpiresUsers.Count)</span>
            <span class="badge badge-neverlogged">Jamais connectés: $($neverLoggedInUsers.Count)</span>
            <span class="badge badge-disabled">Désactivés: $($disabledUsers.Count)</span>
        </p>
    </div>

    @if ($expiredUsers) {
        <div class="section">
            <h2>Comptes expirés</h2>
            $expiredUsers | Select-Object Name, SamAccountName, Email, @{Name="ExpirationDate";Expression={$_.ExpirationDate.ToString("dd/MM/yyyy")}}, DaysLeft, Enabled | ConvertTo-Html -Fragment
        </div>
    }

    @if ($criticalUsers) {
        <div class="section">
            <h2>Comptes critiques</h2>
            $criticalUsers | Select-Object Name, SamAccountName, Email, @{Name="ExpirationDate";Expression={$_.ExpirationDate.ToString("dd/MM/yyyy")}}, DaysLeft, Enabled | ConvertTo-Html -Fragment
        </div>
    }

    @if ($warningUsers) {
        <div class="section">
            <h2>Comptes en avertissement</h2>
            $warningUsers | Select-Object Name, SamAccountName, Email, @{Name="ExpirationDate";Expression={$_.ExpirationDate.ToString("dd/MM/yyyy")}}, DaysLeft, Enabled | ConvertTo-Html -Fragment
        </div>
    }

    @if ($IncludeNeverExpires -and $neverExpiresUsers) {
        <div class="section">
            <h2>Comptes avec mot de passe n'expirant jamais</h2>
            $neverExpiresUsers | Select-Object Name, SamAccountName, Email, Enabled | ConvertTo-Html -Fragment
        </div>
    }

    @if ($neverLoggedInUsers) {
        <div class="section">
            <h2>Comptes jamais connectés</h2>
            $neverLoggedInUsers | Select-Object Name, SamAccountName, Email, Enabled | ConvertTo-Html -Fragment
        </div>
    }

    @if ($IncludeDisabled -and $disabledUsers) {
        <div class="section">
            <h2>Comptes désactivés</h2>
            $disabledUsers | Select-Object Name, SamAccountName, Email, @{Name="ExpirationDate";Expression={if($_.ExpirationDate){$_.ExpirationDate.ToString("dd/MM/yyyy")}else{"N/A"}}}, DaysLeft | ConvertTo-Html -Fragment
        </div>
    }

    <div class="footer">
        <p>Généré le : $(Get-Date -Format "dd/MM/yyyy HH:mm")</p>
        <p>© 2025 Service Informatique</p>
    </div>
</div>
</body>
</html>
"@
    return $html
}

function Get-EmailSignature {
    if ($EmailSignature) {
        return "<div class='email-signature'>$EmailSignature</div>"
    }
    return @"
<div class='email-signature' style='margin-top: 20px; border-top: 1px solid #ccc; padding-top: 10px;'>
    <p style='color: #666; font-size: 12px; margin: 0;'>
        <strong>Service Informatique</strong><br>
        Téléphone : +33 (0)1 XX XX XX XX<br>
        Email : support@domain.com<br>
        <em>Ce message est généré automatiquement, merci de ne pas y répondre directement.</em>
    </p>
</div>
"@
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
    $signature = Get-EmailSignature
    $bodyWithSignature = $Body
    if ($Body -match '(?i)</body>') {
        $bodyWithSignature = $Body -replace '(?i)</body>', "$signature</body>"
    } else {
        $bodyWithSignature = "$Body$signature"
    }
    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $FromAddress
    foreach ($recipient in $Recipients) { $mailMessage.To.Add($recipient) }
    $mailMessage.Subject = $Subject
    $mailMessage.Body = $bodyWithSignature
    $mailMessage.IsBodyHtml = $true
    if ($Attachments) {
        foreach ($att in $Attachments) {
            $mailMessage.Attachments.Add((New-Object System.Net.Mail.Attachment($att)))
        }
    }
    $smtpClient = New-Object System.Net.Mail.SmtpClient($SmtpServer, $Port)
    if ($SmtpCredential) {
        $smtpClient.Credentials = $SmtpCredential
    }
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
    $signature = Get-EmailSignature
    $bodyWithSignature = $Body
    if ($Body -match '(?i)</body>') {
        $bodyWithSignature = $Body -replace '(?i)</body>', "$signature</body>"
    } else {
        $bodyWithSignature = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<body>
$body
$signature
</body>
</html>
"@
    }
    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $FromAddress
    $mailMessage.To.Add($Recipient)
    $mailMessage.Subject = $Subject
    $mailMessage.Body = $bodyWithSignature
    $mailMessage.IsBodyHtml = $true
    $smtpClient = New-Object System.Net.Mail.SmtpClient($SmtpServer, $Port)
    if ($SmtpCredential) {
        $smtpClient.Credentials = $SmtpCredential
    }
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
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f9f9f9;
            color: #333;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 700px;
            margin: 0 auto;
            padding: 30px;
            background-color: #fff;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.05);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        .status {
            font-weight: bold;
            margin-top: 15px;
            display: inline-block;
            padding: 6px 12px;
            border-radius: 5px;
        }
        .expired { background-color: #dc3545; color: white; }
        .critical { background-color: #ffc107; color: #333; }
        .warning { background-color: #fd7e14; color: white; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            border-bottom: 1px solid #ddd;
            text-align: left;
        }
        th {
            background-color: #3498db;
            color: white;
        }
        .footer {
            margin-top: 40px;
            font-size: 0.9em;
            color: #777;
            text-align: center;
        }
    </style>
</head>
<body>
<div class="container">
    <h1>⚠️ Avertissement : Expiration de votre mot de passe</h1>
    <p>Bonjour $($user.Name),</p>
    <p>Votre mot de passe est dans un état <span class='status $user.Status.ToLower()'>$($user.Status)</span>.</p>
    <p><strong>Date d'expiration:</strong> $expirationDate</p>
    <p>Veuillez mettre à jour votre mot de passe dès que possible pour éviter tout problème d'accès.</p>

    <table>
        <tr>
            <th>Nom</th>
            <td>$($user.Name)</td>
        </tr>
        <tr>
            <th>SAM Account Name</th>
            <td>$($user.SamAccountName)</td>
        </tr>
        <tr>
            <th>Email</th>
            <td>$($user.Email)</td>
        </tr>
        <tr>
            <th>Date d'expiration</th>
            <td>$expirationDate</td>
        </tr>
        <tr>
            <th>Jours restants</th>
            <td>$($user.DaysLeft)</td>
        </tr>
    </table>

    <p>Cordialement,<br/>
    Service Informatique</p>
</div>
</body>
</html>
"@
        Send-UserNotification -Recipient $user.Email -Subject $subject -Body $body -SmtpServer $SmtpServer -Port $SmtpPort -FromAddress $FromEmail
    }
    else {
        Write-Warning "L'utilisateur $($user.Name) n'a pas d'adresse email définie dans Active Directory."
    }
}

if ($AdminEmails) {
    if ($reportData.Count -gt 0) {
        $smtpServer = $SmtpServer          
        $smtpPort = $SmtpPort              
        $fromAddress = $FromEmail          
        $subject = "Rapport hebdomadaire d'expiration des mots de passe"
        $body = $htmlReport                
        Send-EmailReport -Recipients $AdminEmails -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -FromAddress $fromAddress -Attachments @()
    }
} else {
    Write-Warning "ADMIN_EMAIL n'est pas défini. Aucun email administrateur ne sera envoyé."
}