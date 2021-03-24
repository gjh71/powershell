function New-PrtgObject
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$channel,
        [Parameter(Mandatory=$true)]
        [string]$value,

        [ValidateSet("BytesBandwidth", `
                     "BytesMemory", `
                     "BytesDisk", `
                     "Temperature", `
                     "Percent", `
                     "TimeResponse", `
                     "TimeSeconds", `
                     "TimeHours", `
                     "Count", `
                     "CPU", `
                     "BytesFile", `
                     "SpeedDisk", `
                     "SpeedNet", `
                     "Custom", `
                     "Value Lookup")]
        [string]$unit,

        [string]$customUnit,
        $volumeSize,
        [string]$mode = "Absolute",
        [boolean]$showChart = $true,
        [boolean]$showTable = $true,
        [boolean]$float = $false,
        $LimitMaxError,
        $LimitMinError,
        [string]$LimitErrorMsg,
        $LimitMaxWarning,
        $LimitMinWarning,
        [string]$LimitWarningMsg
    )

    $prtgObject = New-Object PSObject
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "channel" -Value $channel
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "value" -Value $value
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "unit" -Value $unit
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "customUnit" -Value $customUnit
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "volumeSize" -Value $volumeSize
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "mode" -Value $mode
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "showChart" -Value $showChart
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "showTable" -Value $showTable
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "warning" -Value $warning
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "float" -Value $float
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitMaxError" -Value $LimitMaxError
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitMinError" -Value $LimitMinError
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitErrorMsg" -Value $LimitErrorMsg
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitMaxWarning" -Value $LimitMaxWarning
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitMinWarning" -Value $LimitMinWarning
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitWarningMsg" -Value $LimitWarningMsg
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitMode" -Value $false

    if (($prtgObject.LimitErrorMsg + $prtgObject.LimitWarningMsg) -ne "") {
        $prtgObject.LimitMode = $true
    }

    $prtgObject
}

function Get-PrtgXmlFromEvents{
    param(
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
    <customUnit></customUnit>
    <mode></mode>
    <showChart>0</showChart>
    <showTable>0</showTable>
    <float>0</float>
    <LimitMaxError></LimitMaxError>
    <LimitMaxWarning></LimitMaxWarning>
    <LimitMinError></LimitMinError>
    <LimitMinWarning></LimitMinWarning>
    <LimitWarningMsg></LimitWarningMsg>
    <LimitErrorMsg></LimitErrorMsg>
    <LimitMode>0</LimitMode>
    </result>
</prtg>
"@
        $baseNode = $xmldoc.prtg.result
    }
    
    process {
        if ($null -eq $events) {
            $eventNode = $baseNode.CloneNode(1)
            $eventNode.channel = $env:USERNAME
            $eventNode.value = "0"
            $xmldoc.DocumentElement.AppendChild($eventNode) | Out-Null

            $eventNode = $baseNode.CloneNode(1)
            $eventNode.channel = "NO DATA"
            $eventNode.value = "1"
            $xmldoc.DocumentElement.AppendChild($eventNode) | Out-Null
        }
        else {
            foreach ($event in $events) {
                Write-Verbose("Channel: {0} = {1}" -f $event.channel, $event.value)

                $eventNode = $baseNode.CloneNode(1)

                #set the eventvalues; intellisense available
                $eventNode.channel = $event.channel
                $eventNode.value = "{0}" -f $event.value
                $eventNode.unit = $event.unit
                $eventNode.customUnit = $event.customUnit
                $eventNode.mode = $event.mode
                if ($event.showChart -eq $true) {
                    $eventNode.showChart = "1"
                }
                if ($event.showTable -eq $true) {
                    $eventNode.showTable = "1"
                }
                if ($event.float -eq $true) {
                    $eventNode.float = "1"
                }
                #$eventNode.float = "{0}" -f $event.float
                $eventNode.LimitMaxError = "{0}" -f $event.LimitMaxError
                $eventNode.LimitMaxWarning = "{0}" -f $event.LimitMaxWarning
                $eventNode.LimitMinError = "{0}" -f $event.LimitMinError
                $eventNode.LimitMinWarning = "{0}" -f $event.LimitMinWarning
                $eventNode.LimitErrorMsg = $event.LimitErrorMsg
                $eventNode.LimitWarningMsg = $event.LimitWarningMsg
                if ($event.LimitMode -eq $true) {
                    $eventNode.LimitMode = "1"
                }
            
                $xmldoc.DocumentElement.AppendChild($eventNode) | Out-Null
            }
        }
    }
    
    end {
        #remove the template from the returning xml
        $xmldoc.DocumentElement.RemoveChild($baseNode) | Out-Null

        #return xml-doc as xml
        $xmldoc.InnerXml
    }
}
    