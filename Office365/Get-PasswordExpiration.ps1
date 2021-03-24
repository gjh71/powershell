[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string] $username
)
#Requires -Module msonline
# does not run in powershell core (v7, connect fails)

connect-msolservice

#$users = Get-MsolUser 
$users = Get-MsolUser -UserPrincipalName $username 
$users | Select-Object userprincipalname, LastPasswordChangeTimestamp, @{name = "expires"; e = { ($_.lastpasswordchangetimestamp).addmonths(6) } }
