param (
    [Parameter(Mandatory=$true)]
    [string]$serviceName
)

Write-Host("81-Post-Deploy")

$service = Get-Service $serviceName
Write-Host("Service: {0} is {1}. Needs to be started again." -f $service.Name, $service.Status)
$service | Start-Service

$service = Get-Service $serviceName
Write-Host("Service: {0} is {1}" -f $service.Name, $service.Status)

