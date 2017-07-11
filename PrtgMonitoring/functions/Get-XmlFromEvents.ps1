
function Get-XmlFromEvents
{
param(
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
    [PSObject[]]$events
)

    begin {
        $xmldoc = [System.Xml.XmlDocument]@"
<?xml version="1.0" encoding="UTF-8" ?>
<prtg>
    <result>
    <channel>base</channel>
    <value></value>
    <unit></unit>
    <mode></mode>
    <showChart>0</showChart>
    <showTable>0</showTable>
    <float></float>
    <LimitMaxError></LimitMaxError>
    <LimitMaxWarning></LimitMaxWarning>
    <LimitWarningMsg></LimitWarningMsg>
    <LimitErrorMsg></LimitErrorMsg>
    <LimitMode>0</LimitMode>
    </result>
</prtg>
"@
        $baseNode = $xmldoc.prtg.result
    }

    process {
        foreach ($event in $events)
        {
            Write-Verbose("Analyse: {0}" -f $event.channel)

            $eventNode = $baseNode.CloneNode(1)

            #set the eventvalues; intellisense available
            $eventNode.channel = $event.channel
            $eventNode.value = "{0}" -f $event.value
            $eventNode.unit = $event.unit
            $eventNode.mode = $event.mode
            if ($event.showChart -eq $true)
            {
                $eventNode.showChart = "1"
            }
            if ($event.showTable -eq $true)
            {
                $eventNode.showTable = "1"
            }
            $eventNode.float = "{0}" -f $event.float
            $eventNode.LimitMaxError = "{0}" -f $event.LimitMaxError
            $eventNode.LimitMaxWarning = "{0}" -f $event.LimitMaxWarning
            $eventNode.LimitErrorMsg = $event.LimitErrorMsg
            $eventNode.LimitWarningMsg = $event.LimitWarningMsg
            if ($event.LimitMaxError -eq $true)
            {
                $eventNode.LimitMode = "1"
            }
            
            $dummy = $xmldoc.DocumentElement.AppendChild($eventNode)
        }
    }

    end {
        #remove the template from the returning xml
        $dummy = $xmldoc.DocumentElement.RemoveChild($baseNode)

        #return xml-doc as xml
        $xmldoc.InnerXml
    }
}
