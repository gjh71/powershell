param(
    [Parameter(Mandatory=$true)]
    [string[]]$queueNames
)

begin
{
    $scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    . $scriptDir\functions\New-PrtgObject.ps1
    . $scriptDir\functions\Get-XmlFromEvents.ps1

    $counterMessagesIn = @"
# of msgs pulled from the input queue /sec
"@
    $counterMessagesProcessed = @"
# of msgs successfully processed `/ sec
"@
    $counterTemplateName = @"
\NServiceBus(agis.cowmanager.{0}.process)\{1}
"@
}

process
{
    $resultset = @()
    foreach($queueName in $queueNames)
    {
        $nrMessagesIn = 0
        $nrMessagesProcessed = 0

        $counterName = ($counterTemplateName -f $queueName, $counterMessagesIn)
        Write-Verbose ("Get-Counter {0}" -f $counterName)
        $counter = $null
        try {
            $counter = Get-Counter $counterName
        }
        catch {
            Write-Verbose ($_)
        }

        if ($counter -ne $null)
        {
            $nrMessagesIn = $counter[0].CounterSamples.CookedValue
        }

        $counterName = ($counterTemplateName -f $queueName, $counterMessagesProcessed)
        try {
            $counter = Get-Counter $counterName
        }
        catch {
            Write-Verbose ($_)
        }
        if ($counter -ne $null)
        {
            $nrMessagesProcessed = $counter[0].CounterSamples.CookedValue
        }

        $counterInfo = @{
            "channelName" = "{0} - in" -f $queueName
            "channelValue" = $nrMessagesIn
        }
        $resultset += New-Object -TypeName PSObject -Prop $counterInfo

        $counterInfo = @{
            "channelName" = "{0} - processed" -f $queueName
            "channelValue" = $nrMessagesProcessed
        }
        $resultset += New-Object -TypeName PSObject -Prop $counterInfo

        $counterInfo = @{
            "channelName" = "{0} - delta" -f $queueName
            "channelValue" = ($nrMessagesIn - $nrMessagesProcessed)
        }
        $resultset += New-Object -TypeName PSObject -Prop $counterInfo
    }
}

end
{
    $events = @()
    foreach ($result in $resultset)
    {
        Write-Verbose("Result - Channel: {0} = {1}" -f $result.channelName, $result.channelValue)

        $pPrtgObject = New-PrtgObject `
                -channel $result.channelName `
                -value ($result.channelValue) `
                -unit "Custom" `
                -float 1 `
                -customUnit "msg/s" `
                -mode "Absolute" `
                -showChart 1 

        $events += $pPrtgObject
    }

    Write-Verbose ("{0} events read " -f $events.Count)
    $myXml = Get-XmlFromEvents -events $events
    Write-Verbose ("Xml created length:  " -f $myXml.length)
    $myXml
}
