param(
	[string] $targetsql = "localhost"
)
$sql = @"
select 
	db.name as ChannelName, 
	db.state_desc,
	sdm.mirroring_role_desc,
	sdm.mirroring_state_desc,
	'Count' as channelType,
    case 
        when sdm.mirroring_state_desc is null then 0
        when sdm.mirroring_state_desc = 'synchronized' then 1
        when sdm.mirroring_state_desc = 'synchronizing' then 21
		else 22
    end as ChannelValue
from sys.databases db
left outer join sys.database_mirroring sdm on sdm.database_id=db.database_id
where db.database_id>4
"@

$sensorTimeStart = Get-Date

Import-Module "C:\Program Files\WindowsPowerShell\Modules\CowManagerUtil"

$connectionstring = Get-ConnectionString -database "master" -targetSql $targetsql
$resultset = Get-SQLDataAsObjectList -connectionstring $connectionstring -sql $sql

$events = @()

foreach ($result in $resultset)
{
	$parm = @{
		channel   = $result.channelName
		value     = ($result.channelValue)
		unit      = ($result.channelType)
		mode      = "Absolute"
		showChart = 1
	}
    $events += New-PrtgObject @parm
}

$sensorTimeStop = Get-Date

$parm = @{
	channel         = ("Execution time")
	value           = [Math]::Round(((New-TimeSpan -Start $sensorTimeStart -End $sensorTimeStop).TotalMilliseconds) ,0)
	unit            = "TimeResponse"
	mode            = "Absolute"
	showChart       = 1
	LimitMaxError   = 2000
	LimitErrorMsg   = "Sensor execution took too long"
	LimitMaxWarning = 1000
	LimitWarningMsg = "Sensor execution time warning"
}
$events += New-PrtgObject @parm
$myXml = Get-PrtgXmlFromEvents -events $events
$myXml
