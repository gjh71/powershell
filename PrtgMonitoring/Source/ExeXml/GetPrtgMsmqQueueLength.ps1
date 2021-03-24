
param(
    [Parameter(Mandatory=$true)]
    [string] $queueNameFilter
)

$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
. $scriptDir\functions\New-PrtgObject.ps1
. $scriptDir\functions\Get-XmlFromEvents.ps1

$events = @()
$msmqs = Get-MsmqQueue | where-object {$_.queuename -like ("{0}" -f $queueNameFilter) } | sort-object queuename
foreach ($queue in $msmqs)
{
    Write-Verbose("Analyse: {0}" -f $queue.QueueName)

    $pPrtgObject = New-PrtgObject `
            -channel $queue.QueueName `
            -value ($queue.MessageCount) `
            -mode "Absolute" `
            -showChart 1 `
            -LimitMaxError 0 `
            -LimitErrorMsg "Too many msg in queue" `
            -LimitMaxWarning 0 `
            -LimitWarningMsg "Many msg in queue"

    $events += $pPrtgObject
}

Write-Verbose ("{0} events read " -f $events.Count)
$myXml = Get-XmlFromEvents -events $events
Write-Verbose ("Xml created length:  " -f $myXml.length)
$myXml
