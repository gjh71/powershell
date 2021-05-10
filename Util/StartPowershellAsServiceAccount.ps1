param(
[Parameter(Mandatory=$true)]
 [string]$username,
[Parameter(Mandatory=$true)]
 [string]$passwordtxt
)
$password = ConvertTo-SecureString -String $passwordtxt -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password
Start-Process -FilePath PowerShell.exe -Credential $credential -LoadUserProfile