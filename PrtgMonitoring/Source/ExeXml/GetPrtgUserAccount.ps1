$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
. $scriptDir\functions\New-PrtgObject.ps1
. $scriptDir\functions\Get-XmlFromEvents.ps1

$events = @()

Write-Verbose("Analyse: {0}" -f $result.SourceLastSyncCowData)

$events += New-PrtgObject `
        -channel $env:USERDOMAIN `
        -value (1) `
        -mode "Absolute" 
$events += New-PrtgObject `
        -channel $env:USERNAME `
        -value (2) `
        -mode "Absolute" 
$events += New-PrtgObject `
        -channel $env:TEMP `
        -value (3) `
        -mode "Absolute" 

$myXml = Get-XmlFromEvents -events $events
$myXml
