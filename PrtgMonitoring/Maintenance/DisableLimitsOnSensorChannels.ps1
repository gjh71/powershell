param (
    [Parameter(Mandatory=$false)]
    [string]$deviceName,
    [Parameter(Mandatory=$true)]
    [string]$sensorName,
    [switch]$WhatIf
)
Write-Host("{0:dd-MM-yyyy HH:mm:ss} Start disable limits on {1} - {2}" -f (Get-Date), $deviceName, $sensorName) -ForegroundColor Cyan

$channels = $null
if ($deviceName -ne ""){
    $device = Get-Device -Name $deviceName
    $sensors = Get-Sensor -Device $device -Name $sensorName
}
else {
    $sensors = Get-Sensor -Name $sensorName
}

foreach($sensor in $sensors){
    Write-host ("Getting channels of: {0}.{1} [{2}]  ({3})" -f $sensor.Device, $sensor.Name, $sensor.id, $sensor.Group) -ForegroundColor Green
}
$channels = $sensors | Get-Channel

foreach ($channel in $channels){
    if ($channel.Name -ne "Execution time"){
        if ($channel.LimitsEnabled -eq $false){
            Write-host ("Already disabled channel: {0} (sensorid: {1})" -f $channel.Name, $channel.SensorId) -ForegroundColor Green
        }
        else {
            if ($WhatIf){
                Write-host ("Channel: {0} (sensorid: {1}) would be disabled" -f $channel.Name, $channel.SensorId) -ForegroundColor Cyan
            }
            else {
                $channel | Set-ChannelProperty -LimitsEnabled $false
                Write-host ("Disabled channel: {0} (sensorid: {1})" -f $channel.Name, $channel.SensorId) -ForegroundColor Yellow
            }
        }
    }
}
Write-Host("{0:dd-MM-yyyy HH:mm:ss} Ready." -f (Get-Date)) -ForegroundColor Cyan


