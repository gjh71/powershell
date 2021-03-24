$probeName="agis-db13"
$probe = get-probe -name $probeName

$deviceName = "probe device"
$device = $probe | Get-Device -Name $deviceName

$factorydeviceName = "{0}-factory" -f $probe.Name
$factorydevice = $probe | Get-Device -Name $factorydeviceName
if ($null -eq $factorydevice){
    $factorydevice = Add-Device -Destination $probe -Name $factorydeviceName -Host $probe.name
}

$inputsensors = $device| get-sensor -name "volume*:"

$factorysensorname = "Avg Read Time"
$factorysensor = $factorydevice | get-sensor -name $factorysensorname
$channels = $inputsensors|get-channel "avg read time"
if ($null -eq $factorysensor){
    #$factorysensor = $inputsensors | new-sensor -factory -name $factorysensorname {("Avg Read Time {0}" -f ($_.name.substring(10)))} -DestinationId $factorydevice.Id -ChannelId 10
    $factorysensor = $inputsensors | get-channel "avg read time" | new-sensor -factory -name $factorysensorname {("Avg Read Time {0}" -f ($_.name.substring(10)))} -DestinationId $factorydevice.Id -Expression {}
}

$factorysensorname = "Disk Transfer"
$factorysensor = $factorydevice | get-sensor -name $factorysensorname
$channels = $inputsensors|get-channel "Disk Transfer"
if ($null -eq $factorysensor){
    #$factorysensor = $inputsensors | new-sensor -factory -name $factorysensorname {("Avg Read Time {0}" -f ($_.name.substring(10)))} -DestinationId $factorydevice.Id -ChannelId 10
    $factorysensor = $inputsensors | new-sensor -factory -name $factorysensorname {("Disk Transfer {0}" -f ($_.name.substring(10)))} -DestinationId $factorydevice.Id -ChannelId 17
}
