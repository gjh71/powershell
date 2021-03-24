param (
    [Parameter(Mandatory=$true)]
    [string]$deviceName,
    [Parameter(Mandatory=$true)]
    [int]$priority
)
$device = Get-Device -Name $deviceName
if (@($device).Length -lt 0){
    Write-Host("No device found") -ForegroundColor Red -BackgroundColor White
    exit 1
}

$prtgPriorities = @("-", "One", "Two", "Three", "Four", "Five")

$priorityName = $prtgPriorities[$priority]

$sensors = $device | Get-Sensor

foreach($sensor in $sensors){
    if ($sensor.Priority -eq $priorityName){
        Write-Host("{0} ({1}) already ok" -f $sensor.Name, $sensor.Id)
    }
    else {
        Write-Host("{0} ({1}) priority changed from {2} into {3}" -f $sensor.Name, $sensor.Id, $sensor.Priority, $priorityName) -ForegroundColor Yellow
        $sensor | Set-ObjectProperty Priority $priorityName
    }
}
Write-Host("Done")