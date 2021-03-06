
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
    $oldestArriveTime = (Get-Date)
    if ($queue.MessageCount -gt 0)
    {
        try
        {
            $msgNext = Receive-MsmqQueue -Peek -InputObject $queue
            $oldestArriveTime = $msgNext.ArrivedTime
        }
        catch [System.Messaging.MessageQueueException]#,[Microsoft.Msmq.Runtime.Interop.MsmqInteropException]
        {
            #ignore
            Write-Verbose("*** Ignore message-queue exception: {0}" -f $_.ExceptionMessage)
        }
    }

    $ts = New-TimeSpan -Start $oldestArriveTime -End (Get-Date)
    $pPrtgObject = New-PrtgObject `
            -channel $queue.QueueName `
            -value ([System.Math]::Round($ts.TotalSeconds)) `
            -unit "sec" `
            -mode "Absolute" `
            -showChart 1 `
            -LimitMaxError 600 `
            -LimitErrorMsg "Toooo old" `
            -LimitMaxWarning 300 `
            -LimitWarningMsg "Almost old"

    $events += $pPrtgObject
}

Write-Verbose ("{0} events read " -f $events.Count)
$myXml = Get-XmlFromEvents -events $events
Write-Verbose ("Xml created length:  " -f $myXml.length)
$myXml
