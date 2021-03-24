#requires -modules prtgapi
# install-module prtgapi

# Passwordhash: go to prtg-site, setup - account settings, click on show passhash, then make this part of your environment variables
# Then set the environment variable (e.g. in your profile: $env:passhash = 1234 )
# $prtgserver = "monitor.cowmanager.com:8080"
# $prtgCredential = New-Credential "$env:USERNAME" $env:passhash
$prtgserver = "cowmanager.my-prtg.com"
$prtgCredential = New-Credential "$env:USERNAME@cowmanager.com" $env:passhash

Disconnect-PrtgServer
if(!(Get-PrtgClient)){
    # Connect-PrtgServer -Server $prtgserver -Credential $prtgCredential -PassHash -IgnoreSSL #needed for the 'old' as that certificate was no longer valid
    Connect-PrtgServer -Server $prtgserver -Credential $prtgCredential -PassHash 
}