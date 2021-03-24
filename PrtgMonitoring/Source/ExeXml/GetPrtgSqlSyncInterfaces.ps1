$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
. $scriptDir\functions\New-PrtgObject.ps1
. $scriptDir\functions\Get-XmlFromEvents.ps1

Import-Module SqlServer
$databaseName = "CowManager"
$dbLocation = "SQLSERVER:\sql\{0}\default\databases\{1}" -f $env:COMPUTERNAME, $databaseName

$cowDb = Get-Item ($dbLocation) | Where-Object {$_.Status -eq "Normal"}
if ($cowDb -eq $null)
{
    #this server does not hold an active cowmanager database; exit
    Write-Verbose "CowManager database not found"
    break
}
else
{
    Push-Location $dbLocation
    $sql = @"
select 
	substring([Type], 0, charindex('_LastModifiedDate', [Type])) as channelName,
	datediff(second, [dModify], GETUTCDATE()) as channelValue
from [CowManager].[Koe].[Setting]
where Category =  'DataInterface' 
"@
    $resultset = Invoke-Sqlcmd -Query $sql -QueryTimeout 15
    Pop-Location
}


$events = @()
foreach ($result in $resultset)
{
    Write-Verbose("Analyse: {0}" -f $result.channelName)

    $pPrtgObject = New-PrtgObject `
            -channel $result.channelName `
            -value ($result.channelValue) `
            -unit "Custom" `
            -customUnit "sec" `
            -mode "Absolute" `
            -showChart 1 `
            -LimitMaxError 0 `
            -LimitErrorMsg "CowDataSynchronisation fails" `
            -LimitMaxWarning 0 `
            -LimitWarningMsg "CowDataSynchronisation suspicious"

    $events += $pPrtgObject
}

Write-Verbose ("{0} events read " -f $events.Count)
$myXml = Get-XmlFromEvents -events $events
Write-Verbose ("Xml created length:  " -f $myXml.length)
$myXml
