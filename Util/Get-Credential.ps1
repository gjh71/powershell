# get-credential without prompt:
# get-credential -username "testje"

$usernm = "{0}\testje" -f $env:computername
$usernm = "testje2" -f $env:computername
$userpwd = "8la53g.&ILObFxYo/uZh"

$credentials = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $usernm, (ConvertTo-SecureString -String $userpwd -AsPlainText -Force)

$credentials