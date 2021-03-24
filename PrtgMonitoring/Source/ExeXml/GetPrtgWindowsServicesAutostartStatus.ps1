
param(
)

$sensorTimeStart = Get-Date
Import-Module "C:\Program Files\WindowsPowerShell\Modules\CowManagerUtil"

$events = @()

$services = Get-Service | Where-Object {$_.StartType -eq "Automatic"}
$channelValue = 0
$skiplist = @("CDPUserSvc", "OneSyncSvc", "RemoteRegistry", "sppsvc", "TrustedInstaller", "UALSVC", "tiledatamodelsvc", "wbiosrvc", "mapsbroker", "cdpsvc")
foreach ($service in $services){
    if ($service.name.split("_")[0] -in $skiplist){
        # do not process
        Write-Verbose("Skipping status of: {0}" -f $service.name)
    }
    else {
        switch ($service.Status)
        {
            "Running" { $channelValue = 0 }
            "Stopped" { $channelValue = 5 }
            default { $channelValue = 2 }
        }
        $pPrtgObject = New-PrtgObject `
                -channel $service.Name `
                -value ($channelValue) `
                -unit "Custom" `
                -customUnit "#" `
                -mode "Absolute" `
                -showChart 1 `
                -LimitMaxError 3 `
                -LimitErrorMsg "Service not running" `
                -LimitMaxWarning 1 `
                -LimitWarningMsg "Service state not known"
    
        $events += $pPrtgObject
        Write-Verbose("Channel: {0} = {1}  {2}" -f $pPrtgObject.channel, $pPrtgObject.value, $pPrtgObject.LimitMode)
    }
}

$sensorTimeStop = Get-Date
$ms = [Math]::Round(((New-TimeSpan -Start $sensorTimeStart -End $sensorTimeStop).TotalMilliseconds) ,0)

$pPrtgObject = New-PrtgObject `
		-channel ("Execution time") `
		-value $ms `
		-unit "TimeResponse" `
		-mode "Absolute" `
		-showChart 1 `
		-LimitMaxError 2000 `
		-LimitErrorMsg "Sensor execution took too long" `
		-LimitMaxWarning 1000 `
		-LimitWarningMsg "Sensor execution time warning"
$events += $pPrtgObject

$myXml = Get-PrtgXmlFromEvents -events $events
$myXml
