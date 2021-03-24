$sensorName = "Company last communication received"
$sensorGroup = "cm-web01-test"
$sensorDevice = "cm-web01-test"

$sensors = Get-Sensor -Name $sensorName | Where-Object {$_.Group -eq $sensorGroup}
$channels = $sensors[0] | get-channel

$maxval=10*24*3600
foreach ($channel in $channels){
    if ($channel.LastValue -gt $maxval){
        if ($channel.LimitsEnabled -eq $false){
            Write-host ("Already disabled channel: {0}" -f $channel.Name)
        }
        else {
            $channel | Set-ChannelProperty -LimitsEnabled $false
            Write-host ("Disabled channel: {0}" -f $channel.Name)
        }
    }
}

