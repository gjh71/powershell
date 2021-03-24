param(
    [Parameter(Mandatory=$true)]
    [string] $environmentName,      # eg. test
    [Parameter(Mandatory=$true)]
    [string] $machineDisplayname,   # eg. cm-web01-test42
    [Parameter(Mandatory=$true)]
    [string] $tentacleUri,          # eg. cm-lb01-test42.westeurope.cloudapp.azure.com
    [string] $tentaclePort=10933,   # eg. 11933 
    [Parameter(Mandatory=$true)]
    [string[]] $machineRoles        # eg. web
)
#requires -modules octoposh
if (!((test-path Env:\OctopusApiKey) -and (test-path Env:\OctopusURL))){
    throw "Required environment variables: OctopusApiKey / OctopusURL not found"
}
# then set-octopusconnectioninfo

# Connection properties defined in: C:\Users\gj.hiddink\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
$roleMap = @{
    app = "AppServicesBehavior", "AppServicesCow", "AppServicesOther", "Data Export", "Deploy Database", "PushNotifications", "SalesForce", "cm-reporting", "prtg-probes"
    web = "Behavior Api", "Device Web Services", "Log process", "ManufactOor.Api", "Web", "Web services", "prtg-probes"
    dw = "Device App Services", "Device App Services - DeviceEvents", "Device Web Services", "Log process", "prtg-probes"
    db = "Database", "prtg-probes"
}
$octopusRoles = @()
foreach($machineRole in $machineRoles){
    $octopusRoles += $roleMap[$machineRole]
}

$machine = Get-OctopusMachine -MachineName $machineDisplayName
if ($machine){
    $machine | Remove-OctopusResource | Out-Null
}
$machineEnvironments = $environmentName
$machine = Get-OctopusResourceModel -Resource Machine
$environments = Get-OctopusEnvironment -EnvironmentName $machineEnvironments -ResourceOnly
$machine.name = $machineDisplayName #Display name of the machine on Octopus
foreach($environment in $environments){
    $machine.EnvironmentIds.Add($environment.id) | Out-Null
    Write-host("Added to environment: {0}" -f $environment.Name) -ForegroundColor Yellow
}
foreach ($role in $octopusRoles){
    $machine.Roles.Add($role) |Out-Null
    Write-host("Added role: {0}" -f $role) -ForegroundColor Green
}
$discover = (Invoke-WebRequest "$env:OctopusURL/api/machines/discover?host=$tentacleUri&type=TentaclePassive&port=$tentaclePort" -Headers (New-OctopusConnection).header).content | ConvertFrom-Json
$machineEndpoint = New-Object Octopus.Client.Model.Endpoints.ListeningTentacleEndpointResource
$machine.EndPoint = $machineEndpoint
$machine.Endpoint.Uri = $discover.Endpoint.Uri
$machine.Endpoint.Thumbprint = $discover.Endpoint.Thumbprint
New-OctopusResource -Resource $machine
