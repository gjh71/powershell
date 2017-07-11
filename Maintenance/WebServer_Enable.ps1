if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
    break
}

$prompt = Read-Host -Prompt "Press 'y' to confirm `n 1. Start IIS`n 2. Enable routed network adapter"

if ($prompt -eq "y")
{
    #note: first start IIS, so when loadbalancers detects up and running 'machine', the machine is ready
    Import-Module WebAdministration
    iisreset /start
    Enable-NetAdapter -name "routed"
}
else {
    Write-Host "Skipped"
}

