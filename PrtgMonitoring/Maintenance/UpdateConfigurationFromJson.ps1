#requires -modules prtgapi

param(
    [Parameter(Mandatory=$true)]
    [string]$sensorsjsonfile,
    [switch]$WhatIf
)

#region functions

function Set-ChannelPropertiesEqual{
    param(
        $oldChannel,
        $newChannel
    )
    $old = @{
        ShowInGraph         = $oldChannel.ShowInGraph
        # ShowInTable         = $oldChannel.ShowInTable
        # DecimalMode         = $oldChannel.DecimalMode
        # DecimalPlaces       = $oldChannel.DecimalPlaces
        LimitsEnabled       = $oldChannel.LimitsEnabled
        UpperErrorLimit     = $oldChannel.UpperErrorLimit
        UpperWarningLimit   = $oldChannel.UpperWarningLimit
        LowerWarningLimit   = $oldChannel.LowerWarningLimit
        LowerErrorLimit     = $oldChannel.LowerErrorLimit
        ErrorLimitMessage   = $oldChannel.ErrorLimitMessage
        WarningLimitMessage = $oldChannel.WarningLimitMessage
    }
    $new = @{
        ShowInGraph         = $newChannel.ShowInGraph
        # ShowInTable         = $newChannel.ShowInTable
        # DecimalMode         = $newChannel.DecimalMode
        # DecimalPlaces       = $newChannel.DecimalPlaces
        LimitsEnabled       = $newChannel.LimitsEnabled
        UpperErrorLimit     = $newChannel.UpperErrorLimit
        UpperWarningLimit   = $newChannel.UpperWarningLimit
        LowerWarningLimit   = $newChannel.LowerWarningLimit
        LowerErrorLimit     = $newChannel.LowerErrorLimit
        ErrorLimitMessage   = $newChannel.ErrorLimitMessage
        WarningLimitMessage = $newChannel.WarningLimitMessage
    }
    if (($new|ConvertTo-Json) -ne ($old|ConvertTo-Json)){
        if ($WhatIf){
            Write-Host("Channel {0} definition differs" -f $newChannel.Name) -ForegroundColor Cyan
        }
        else{
            Write-Host("Channel {0} definition (re-)set" -f $newChannel.Name) -ForegroundColor Cyan
            $newChannel | Set-ChannelProperty @old
        }
    }
}

function Set-SensorPropertiesEqual{
    param(
        $oldSensor,
        $newSensor,
        $basedir
    )
    #sensor properties
    # $sensorfile = Join-Path $basedir -ChildPath ("{0}\sensor.json" -f $oldSensor.Id)
    # $oldsensor = (Get-Content -path $sensorfile -raw) | ConvertFrom-Json
    # $newsensor = $newSensor
    $old = @{
        # Schedule        = $oldSensor.Schedule
        # Interval        = $oldSensor.Interval
        Comments        = $oldSensor.Comments
    }
    $new = @{
        # Schedule        = $newSensor.Schedule
        # Interval        = $newSensor.Interval
        Comments        = $newSensor.Comments
    }
    if (($old | ConvertTo-Json) -ne ($new | ConvertTo-Json)){
        if ($WhatIf) {
            Write-Host("Sensor {0} definition differs" -f $newChannel.Name) -ForegroundColor Cyan
        }
        else{
            Write-Host("Sensor {0} definition (re-)set" -f $newSensor.Name) -ForegroundColor Cyan
            $newSensor | Set-ObjectProperty @old
        }
    }

    #More properties
    # $propertiesfile = Join-Path $basedir -ChildPath ("{0}\properties.json" -f $oldSensor.Id)
    # $oldproperties = (Get-Content -path $propertiesfile -raw) | ConvertFrom-Json
    # $newproperties = $newSensor | Get-ObjectProperty

    #Verify and set channelSettings
    $channelfile = Join-Path $basedir -ChildPath ("{0}\channels.json" -f $oldSensor.Id)
    $oldChannels = (Get-Content -path $channelfile -raw) | ConvertFrom-Json
    $newChannels = $newSensor | Get-Channel
    foreach ($newChannel in $newChannels) {
        $oldChannel = $oldChannels | Where-Object { $_.Name -eq $newChannel }
        if ($null -ne $oldChannel) {
            if ($oldChannel.Length -gt 1){
                Write-Host("Channel {0} found multiple times on source-sensor" -f $newChannel.Name) -ForegroundColor Red -BackgroundColor White
            }
            else {
                Set-ChannelPropertiesEqual -oldChannel $oldChannel -newChannel $newChannel
            }
        }
        else {
            Write-Host("New channel: {0} not found on old sensor" -f $newChannel.Name) -ForegroundColor Red -BackgroundColor White
        }
    }
}

#endregion

#region main
if (!(Test-Path $sensorsjsonfile)) {
    Write-Host("Configuration file: {0} not found" -f $jsonconfiguration) -ForegroundColor Red -BackgroundColor White
    exit 1
}
$basedir = Split-Path $sensorsjsonfile

$oldSearchFile = Join-Path $basedir -ChildPath "sensor-search.json"
$oldSearchData = Get-Content $oldSearchFile -raw | ConvertFrom-Json
$oldSensorFile = Join-Path $basedir -ChildPath "sensors.json"
$oldSensors = Get-Content $oldSensorFile -raw | ConvertFrom-Json

# $newSensors = Get-Sensor
$newSensors = get-sensor *servicebus-msgs*
#$newSensors = get-probe -name *beta* | get-sensor
# $newSensors = get-probe -name *agis-web0* | get-sensor
#$newSensors = get-device -Name cm-web01-sb02-sql | Get-Sensor
# $newSensors = get-probe -Name "cm-app02-test37" | Get-Sensor
# $newSensors = get-probe -Name "cm-*-test37" | Get-Sensor
# $newSensors = get-probe -Name "cm-build02" | get-device -name "*timeser*" | Get-Sensor
# $newSensors = get-device -name "cm-app02-test37-devicesql" | get-sensor
# $newSensors = get-device -Name application-insights | Get-Sensor | sort-object id

foreach($newSensor in $newSensors){
    $found = $false
    if ($newSensor.Active){
        #can we find it on 'name'?
        $search = $oldSearchData | Where-Object { $_.name -eq $newsensor.name }
        $stagetag = ""
        if (@($search).length -eq 1) { $found = $true }
        if ($found -eq $false) {
            #can we identify by name + device?
            $search = $oldSearchData | Where-Object { $_.name -eq $newsensor.name -and $_.device -eq $newsensor.device }
            if (@($search).length -eq 1) { $found = $true }
        }
        if ($found -eq $false) {
            #can we identify by name + probe?
            $search = $oldSearchData | Where-Object { $_.name -eq $newsensor.name -and $_.probe -eq $newsensor.probe }
            if (@($search).length -eq 1) { $found = $true }
        }
        if ($found -eq $false) {
            #can we identify by name + device + probe?
            $search = $oldSearchData | Where-Object { $_.name -eq $newsensor.name -and $_.device -eq $newsensor.device -and $_.probe -eq $newsensor.probe}
            if (@($search).length -eq 1) { $found = $true }
        }
        if ($found -eq $false) {
            #can we identify by name + stage-tag?
            $stagetag = $newSensor.Tags | Where-Object {$_ -like "stage-*"} | Sort-Object {$_.length} -desc | Select-Object -First 1
            $search = $oldSearchData | Where-Object { $_.name -eq $newsensor.name -and $_.DeviceTags -contains $stagetag }
            if (@($search).length -eq 1) { $found = $true }
        }
        if ($found -eq $false) {
            if ($newSensor.Type.stringvalue -eq "exexml") {
                $sensorproperties = $newSensor | Get-ObjectProperty
                $search = $oldSearchData | Where-Object { $_.ps1.Name -eq $sensorproperties.ExeFile.Name }
                if (@($search).length -eq 1) { 
                    #can we identify by powershell script?
                    $found = $true
                }
                elseif (@($search).length -gt 1) {
                    #powershell + arguments?
                    $search = $oldSearchData | Where-Object { $_.ps1.Name -eq $sensorproperties.ExeFile.Name -and $_.args -eq $sensorproperties.ExeParameters }
                    if (@($search).length -eq 1) { 
                        $found = $true
                    }
                    elseif ($search.length -gt 1){
                        $search = $search | Where-Object {$_.Tags -contains $stagetag }
                        if (@($search).length -eq 1) { $found = $true }
                    }
                }
                if ($found -eq $false){
                    #powershell + device-tags
                    $device = get-device -id $sensor.parentid
                    $search = $oldSearchData | Where-Object { $_.ps1 -eq $sensorproperties.ExeFile.Name -and $_.devicetags -eq $device.Tags}
                    if (@($search).length -eq 1) { 
                        $found = $true
                    }
                }
            }
        }
        if ($found) {
            # $oldSensor = $search
            $oldSensor = $oldSensors | Where-Object {$_.Id -eq $search.Id}
            Write-Host("New: {0}\{1}\{2}({3}) `tSrc: {4}\{5}\{6}({7})" -f $newSensor.Probe, $newSensor.Device, $newSensor.Name, $newSensor.Id, $oldSensor.Probe, $oldSensor.Device, $oldSensor.Name, $oldSensor.Id) -ForegroundColor Green
            if ($oldSensor.Comments -ne $newSensor.Comments){
                if ($WhatIf){
                    Write-Host("New comment [{0}] would be set to [{1}]" -f $newSensor.Comments, $oldSensor.Comments) -ForegroundColor Yellow
                }
                else {
                    Write-Host("New comment [{0}] will be set to [{1}]" -f $newSensor.Comments, $oldSensor.Comments) -ForegroundColor Yellow
                    $newSensor | Set-ObjectProperty -Comments $oldSensor.Comments
                }
            }
            Set-SensorPropertiesEqual -oldSensor $oldSensor -newSensor $newSensor -basedir $basedir
        }
        else {
            Write-Host("New sensor {0}\{1}\{2} ({3}) not matched" -f $newSensor.Probe, $newSensor.Device, $newSensor.Name, $newSensor.Id) -ForegroundColor Magenta
        }
    }
    else{
        Write-Host("Sensor {0}\{1}\{2} ({3}) not active" -f $newSensor.Probe, $newSensor.Device, $newSensor.Name, $newSensor.Id) -ForegroundColor DarkGreen
    }
}
#endregion 