<#
.SYNOPSIS
    Sends an email using SMTP commands over a TCP connection.

.DESCRIPTION
    This script sends an email using minimal SMTP commands via a TCP connection. 
    It retrieves configuration details (SMTP server, port, sender, recipient, subject, and body)
    from environment variables.

.EXEMPLE
    SMTP_SERVER=XXXXX.mail.protection.outlook.com
    SMTP_PORT=25
    EMAIL_FROM=whatever@domain1.asdf
    EMAIL_TO=whatever@domain2.asdf
    EMAIL_SUBJECT=Test Email via TCP
    EMAIL_BODY=This is a test email sent using SMTP commands over TCP.

.NOTE
    Author: SAN
    Date: 03.12.24
    #public

.CHANGELOG
    SAN 12.12.24 Fixed HELO to extract domain from "to"
#>


$smtpServer = $env:SMTP_SERVER
$smtpPort = [int]$env:SMTP_PORT
$from = $env:EMAIL_FROM
$to = $env:EMAIL_TO
$subject = $env:EMAIL_SUBJECT
$body = $env:EMAIL_BODY

$domain = ($to -split '@')[1]

$tcpClient = New-Object System.Net.Sockets.TcpClient($smtpServer, $smtpPort)
$stream = $tcpClient.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$reader = New-Object System.IO.StreamReader($stream)

function Send-SMTPCommand {
    param ([string]$command)
    if ($command) {
        $writer.WriteLine($command)
        $writer.Flush()
    }
    $response = $reader.ReadLine()
    Write-Host "SERVER RESPONSE: $response"
    return $response
}

Send-SMTPCommand ""
Send-SMTPCommand "HELO $domain"
Send-SMTPCommand "MAIL FROM:<$from>"
Send-SMTPCommand "RCPT TO:<$to>"
Send-SMTPCommand "DATA"
Send-SMTPCommand @"
From: $from
To: $to
Subject: $subject

$body
.
"@
Send-SMTPCommand "QUIT"

$writer.Close()
$reader.Close()
$stream.Close()
$tcpClient.Close()

Write-Host "Email sent!"
