$sensorName = "prodsync*"
#$sensorName = "betasync*"

Write-Host("Adjusting channels for sensor: {0}" -f $sensorName) -ForegroundColor Green
$channels = Get-Sensor $sensorName | Get-Channel | Where-Object {$_.name -ne "Execution time"}

$maxErrorval = (28*3600 ) 
$minErrorval = 0 
#$maxErrorval = (2.75*3600 ) 
#$minErrorval = (1.7*3600 ) 
$maxWarningval = [int](0.85*$maxErrorval)
$minWarningval = [int]($minErrorval/0.85)
foreach($channel in $channels){
    if ($channel.LimitsEnabled -eq $true){
        if ($minErrorval -gt 0){
            $channel | Set-ChannelProperty -UpperErrorLimit $maxErrorval -UpperWarningLimit $maxWarningval -LowerErrorLimit $minErrorval -LowerWarningLimit $minWarningval
            Write-Host(" channel: {0}`nlimits set to maxWarning: {1} maxError: {2}`nlimits set to minWarning: {3} minError: {4}" -f $channel.Name, $maxWarningval, $maxErrorval, $minWarningval, $minErrorval) -ForegroundColor Cyan
        }
        else {
            $channel | Set-ChannelProperty -UpperErrorLimit $maxErrorval -UpperWarningLimit $maxWarningval
            Write-Host(" channel: {0}`nlimits set to maxWarning: {1} maxError: {2}" -f $channel.Name, $maxWarningval, $maxErrorval) -ForegroundColor Cyan
        }
    }
    else {
        Write-Host(" channel: {0} has limits disabled" -f $channel.Name) -ForegroundColor Yellow
    }
}