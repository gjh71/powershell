$probeName="agis-db13"
$probe = get-probe -name $probeName

$deviceName = "probe device"
$device = $probe | Get-Device -Name $deviceName

# $device | get-sensortype --> wmisqlserver2016
$sensortype = "wmilogicaldiskv2"
$parameters = $device | New-SensorParameters -RawType $sensortype
foreach ($instance in $parameters.Targets["datafieldlist__check"]) {
    $sensorName = "Volume IO {0}" -f $instance.Name
    Write-host("{0}" -f $sensorName) -ForegroundColor Yellow
    $sensor = $device | Get-Sensor -Name ("{0}*" -f $sensorName)
    if ($null -eq $sensor -and 1 -eq 2){
        # $parameters is still correct, just adjust
        $parameters.Unlock()
        $parameters.datafieldlist__check = $instance.Name
        $parameters.Lock()
        $sensor = $device | Add-Sensor $parameters
        $sensor | Set-ObjectProperty -Name $sensorName
    }
}
