$probeName="agis-db13"
$probe = get-probe -name $probeName

$deviceName = "probe device"
$device = $probe | Get-Device -Name $deviceName

# $device | get-sensortype --> wmisqlserver2016
$idx=0
$sensortype = "wmisqlserver2016"
$parameters = $device | New-SensorParameters -RawType $sensortype
foreach($instance in $parameters.Targets["servicenamelist__check"].Value){
    $deviceName = "{0}-{1}" -f $probe.name, $instance
    $device = $probe | Get-Device -Name $deviceName
    if ($null -eq $device) {
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Tags            = "stage-{0},sql" -f $probeEnvironment
        WindowsDomain   = $probe.name
        WindowsUserName = $windowsusername
        WindowsPassword = $windowspwd
        Interval        = "00:15:00"
    }
    $device | Set-ObjectProperty @properties

    $instanceName = switch ($instance) {
        "MSSQLSERVER" { "localhost"; break }
        default { "{0}\{1}" -f $probe.name, ($_.split("$")[1]); break }
    }

    $sensorName = "{0} General Statistics" -f $parameters.Targets["servicenamelist__check"][$idx].Name
    $sensor = $device | Get-Sensor -Name ("{0}*" -f $sensorName)
    if ($null -eq $sensor){
        # $parameters is still correct, just adjust
        $parameters.Unlock()
        $parameters.servicenamelist__check = $sensorName
        $parameters.Lock()
        $sensor = $device | Add-Sensor $parameters
    }
    $idx++
}

<#
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
#>

# OK, Brave attempt to add the default sql-2016 checks, but that proves to be 
# quite fiddly with setting the correct parameters.
# Also: how do you set the sql-sensortype?
# $sensorName = $parameters.Targets["servicenamelist__check"][$idx].Name
# $sensor = $device | Get-Sensor -Name ("{0}*" -f $sensorName)
# if ($null -eq $sensor){
#     # $parameters is still correct, just adjust
#     $parameters.Unlock()
#     $parameters.servicenamelist__check = $parameters.Targets["servicenamelist__check"][$idx].Name
#     $parameters.Lock()
#     $sensor = $device | Add-Sensor $parameters
# }
