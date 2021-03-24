$smtpCred = (Get-Credential)
$toAddress = "gj.hiddink@cowmanager.com"
$fromAddress = "webapp-beta@cowmanager.com"
$smtpServer = "smtp.office365.com"
$smtpPort = 587

$param = @{
    To = $toAddress
    From = $fromAddress
    Subject = "mail test through office365"
    Body = "test mailtje"
    SmtpServer = $smtpServer
    Port = $smtpPort
    Credential = $smtpCred
}

Send-MailMessage @param -UseSsl

$smtpServer = "cm-web01-beta"
$smtpPort = 25
$param2 = @{
    To = $toAddress
    From = $fromAddress
    Subject = "mail test through office365"
    Body = "relayed test mailtje"
    SmtpServer = $smtpServer
    Port = $smtpPort
}
Send-MailMessage @param2

$toAddress = "gj.hiddink@cowmanager.com"
$fromAddress = "$env:COMPUTERNAME@cowmanager.com"
$smtpServer = "mailman.agishosting.nl"
$smtpPort = 25
$param3 = @{
    To = $toAddress
    From = $fromAddress
    Subject = "mail sent by mailman"
    Body = "relayed test mailtje"
    SmtpServer = $smtpServer
    Port = $smtpPort
}
Send-MailMessage @param3
