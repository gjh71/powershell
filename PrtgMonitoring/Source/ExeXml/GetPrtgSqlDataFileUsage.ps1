param(
	[string]$targetSql = "localhost"
)

$sql = @"
DECLARE
	@SqlStatement nvarchar(MAX)
	,@DatabaseName sysname;
	
IF OBJECT_ID(N'tempdb..#DatabaseSpace') IS NOT NULL
	DROP TABLE #DatabaseSpace;
	
CREATE TABLE #DatabaseSpace(
	[FileName] nvarchar(100),
	[FillPercentage] decimal(12, 2)
	);
	
DECLARE DatabaseList CURSOR LOCAL FAST_FORWARD FOR
	SELECT name FROM sys.databases where (database_id=2 or database_id>4) and state_desc = 'online' order by 1;
	
OPEN DatabaseList;
WHILE 1 = 1
BEGIN
	FETCH NEXT FROM DatabaseList INTO @DatabaseName;
	IF @@FETCH_STATUS = -1 BREAK;
	SET @SqlStatement = N'USE '
		+ QUOTENAME(@DatabaseName)
		+ CHAR(13)+ CHAR(10)
		+ N'INSERT INTO #DatabaseSpace
		Select ''' + @DatabaseName + ''' + ''.'' + [name] as dataFileName
		, Case
			When [maxsize] < 0 Then -1
			Else 100.0 * (coalesce(FILEPROPERTY(name, ''SpaceUsed''),0.0)/[maxsize])
			End As [FillPercentage]
	From ' + QUOTENAME(@DatabaseName) + '.dbo.sysfiles;';

	EXECUTE(@SqlStatement);
	
END
CLOSE DatabaseList;
DEALLOCATE DatabaseList;

SELECT * FROM #DatabaseSpace order by 1;

DROP TABLE #DatabaseSpace
"@


$sensorTimeStart = Get-Date

Import-Module "C:\Program Files\WindowsPowerShell\Modules\CowManagerUtil"

$connectionstring = Get-ConnectionString -database "master" -targetSql $targetSql
$resultset = Get-SQLDataAsObjectList -connectionstring $connectionstring -sql $sql
$events = @()

foreach ($result in $resultset)
{
	$channelName = $result.FileName
	$channelValue = ("{0}" -f ([Math]::Round(($result.FillPercentage),0)))
	$pPrtgObject = New-PrtgObject `
			-channel $channelName `
			-value $channelValue `
			-unit "Percent" `
			-mode "Absolute" `
			-showChart 1 `
			-showTable 1 `
			-LimitMaxError 90 `
			-LimitErrorMsg "Data file usage too high" `
			-LimitMaxWarning 80 `
			-LimitWarningMsg "Data file usage high"
	
	$events += $pPrtgObject
}

$sensorTimeStop = Get-Date
$ms = [Math]::Round(((New-TimeSpan -Start $sensorTimeStart -End $sensorTimeStop).TotalMilliseconds) ,0)

$pPrtgObject = New-PrtgObject `
		-channel ("Execution time") `
		-value $ms `
		-unit "TimeResponse" `
		-mode "Absolute" `
		-showChart 0 `
		-showTable 0 `
		-LimitMaxError 2000 `
		-LimitErrorMsg "Sensor execution took too long" `
		-LimitMaxWarning 1000 `
		-LimitWarningMsg "Sensor execution time warning"
$events += $pPrtgObject

$myXml = Get-PrtgXmlFromEvents -events $events
$myXml
