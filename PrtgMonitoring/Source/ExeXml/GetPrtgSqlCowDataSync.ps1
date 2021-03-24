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
select c.SourceLastSyncCowData, 
	min(datediff(second, c.DateLastSyncCowData, getutcdate())) as LastSyncInSeconds
from koe.bedrijf b
inner join koe.CompanyStatus c on c.CompanyId = b.PK_Bedrijf
where b.[Status] = 1
and c.SourceLastSyncCowData is not null
group by c.SourceLastSyncCowData
"@
    $resultset = Invoke-Sqlcmd -Query $sql -QueryTimeout 15
    Pop-Location
}


$events = @()
foreach ($result in $resultset)
{
    Write-Verbose("Analyse: {0}" -f $result.SourceLastSyncCowData)

    $pPrtgObject = New-PrtgObject `
            -channel $result.SourceLastSyncCowData `
            -value ($result.LastSyncInSeconds) `
            -unit "sec" `
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
