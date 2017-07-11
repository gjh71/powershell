if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
    break
}

$prompt = Read-Host -Prompt "Press 'y' to confirm `n 1. Stop IIS`n 2. Disable routed network adapter"

if ($prompt -eq "y")
{
    Import-Module WebAdministration
    iisreset /stop
    Disable-NetAdapter -name "routed"
}
else {
    Write-Host "Skipped"
}

