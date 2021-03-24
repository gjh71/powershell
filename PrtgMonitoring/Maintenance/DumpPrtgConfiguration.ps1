[CmdletBinding()]
param (
    [Parameter()]
    [switch]$skipExportRights
)
#requires -modules prtgapi

$timeStart = Get-Date
if(!(Get-PrtgClient)){
    Write-Host("First initialise prtg-api: _Initialise-prtgapi.ps1") -ForegroundColor White -BackgroundColor Red
    exit 1
}

$global:prtgobjectnames = @{}
$global:prtgobjecttypes = @{}
function Get-PrtgObjectNameCache {
    param(
        $id
    )
    $rv = $global:prtgobjectnames[$id]
    if ($null -eq $rv){
        $prtgobject = get-object -id $id
        $rv=$prtgobject.Name
        $global:prtgobjectnames.add($id, $rv)
    }
    $rv
}

function Get-PrtgObjectRights{
    param(
        $prtgobject,
        $id,
        [switch]$includeInheritedValue
    )
    if ($null -eq $prtgobject){
        $prtgobject = Get-Object -id $id
    }
    $rv = @{}
    $properties = $prtgobject | Get-ObjectProperty -Raw
    foreach($prop in $properties.psobject.properties){
        if ($prop.name -like "accessrights_*"){
            $level = switch ($prop.value){
                -1  {if ($includeInheritedValue) {"Inherited"}; break}
                0  {"None"; break}
                100  {"Read"; break}
                200  {"Write"; break}
                400  {"Full"; break}
            }
            if ($null -ne $level) {
                $rv.Add((Get-PrtgObjectNameCache -id $prop.name.substring(13)), $level)
            }
        }
    }
    $rv
}

function Export-Sensor{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $sensor,
        [Parameter(Mandatory=$true)]
        [string]$dumpfolder
    )
    $searchinfo = @{
        id     = $sensor.Id
        name   = $sensor.Name
        device = $sensor.Device
        probe  = $sensor.Probe
        ps1    = ""
        args   = ""
        devicetags = @()
    }
    $dumpfilenm = Join-Path $dumpfolder -ChildPath ("sensor.json")
    $sensor | ConvertTo-Json | Out-File -FilePath $dumpfilenm -Force

    #sensor properties
    $dumpfilenm = Join-Path $dumpfolder -ChildPath ("properties.json")
    $properties = $sensor | Get-ObjectProperty
    $properties | ConvertTo-Json | Out-File -FilePath $dumpfilenm -Force
    $searchinfo.ps1 = $properties.ExeFile
    $searchinfo.args = $properties.ExeParameters

    # Dump channel information
    $channels = $sensor | Get-Channel | Sort-Object Name
    $dumpfilenm = Join-Path $dumpfolder -ChildPath ("channels.json")
    $channels | ConvertTo-Json | Out-File $dumpfilenm -Force

    # get-device
    $device = get-device -id $sensor.parentid
    $searchinfo.devicetags = $device.Tags

    $searchinfo
}

function Export-PrtgObjectRights{
    [CmdletBinding()]
    param (
        $prtgobjects,
        [string] $exportfolder
    )
    if ($null -eq $prtgobjects){
        $prtgobjects = Get-Object
    }

    $devicerights = @{}
    $sensorrights = @{}
    $objectrights = @{}

    $prtgobjects = Get-Object
    $cnt = 0
    $len = $prtgobjects.Length / 100
    foreach ($prtgobject in $prtgobjects) {
        $prtgtype = $prtgobject.DisplayType
        if ($prtgtype -ne "Device") {
            $sensor = get-sensor -id $prtgobject.id
            if ($null -ne $sensor) {
                $prtgtype = "sensor"
                $continue
            }
        }
        Write-Progress -Status ("{3} {2}: {0}-{1}" -f $prtgobject.id, $prtgobject.name, $cnt++, $prtgtype) -PercentComplete ($cnt / $len) -Activity "Exporting rights"
        $rights = Get-PrtgObjectRights -prtgobject $prtgobject
        if ($rights.Length -gt 0) {
            foreach ($right in $rights.GetEnumerator()) {
                $key = "[{0}]-{1}" -f $right.name, $right.value
                switch ($prtgtype) {
                    "device" {
                        $val = $devicerights[$key]
                        if ($null -eq $val) {
                            $devicerights.Add($key, $prtgobject.Name)
                        }
                        else {
                            $devicerights[$key] = "{0}, {1}" -f $val, $prtgobject.Name
                        }
                        break
                    }
                    "sensor" {
                        $val = $sensorrights[$key]
                        if ($null -eq $val) {
                            $sensorrights.Add($key, $prtgobject.Name)
                        }
                        else {
                            $sensorrights[$key] = "{0}, {1}" -f $val, $prtgobject.Name
                        }
                        break
                    }
                    (@("probe", "group", "library", "report", "schedule", "system") -contains $_) {
                        $val = $objectrights[$key]
                        if ($null -eq $val) {
                            $objectrights.Add($key, $prtgobject.Name)
                        }
                        else {
                            $objectrights[$key] = "{0}, {1}" -f $val, $prtgobject.Name
                        }
                        break
                    }
                    Default {
                        $val = $objectrights[$key]
                        if ($null -eq $val) {
                            $objectrights.Add($key, $prtgobject.Name)
                        }
                        else {
                            $objectrights[$key] = "{0}, {1}" -f $val, $prtgobject.Name
                        }
                        break
                    }
                }
            }
        }
    }
    $devicerights | sort-object | convertto-json | out-file ("{0}\device-rights-dump.json" -f $exportfolder) -Force
    $sensorrights | sort-object | convertto-json | out-file ("{0}\sensor-rights-dump.json" -f $exportfolder) -Force
    $objectrights | sort-object | convertto-json | out-file ("{0}\object-rights-dump.json" -f $exportfolder) -Force
}

#region main
$dumpfolder = Join-Path $PSScriptRoot -ChildPath "export"
if (!(Test-Path $dumpfolder)) {
    New-Item $dumpfolder -ItemType Directory | Out-Null
}

if ($skipExportRights){
    Write-Host("Skipping export-rigths")
}
else {
    $prtgobjects = Get-Object
    Export-PrtgObjectRights -prtgobjects $prtgobjects -exportfolder $dumpfolder
}

#$sensors = get-probe -name "cm-app02-test37" | Get-Sensor | sort-object id
$sensors = Get-Sensor | Sort-Object Id
#$sensors = Get-Sensor -id 3995| Sort-Object Id

$dumpfilenm = Join-Path $PSScriptRoot -ChildPath ("export\sensors.json")
$sensors | ConvertTo-Json | Out-File $dumpfilenm -Force

$searchlist = @()

$cnt=0
$cntall=$sensors.length
foreach($sensor in $sensors){
    Write-Progress -Activity ("Dumping sensorid: {0} - {1}" -f $sensor.id, $sensor.name) -PercentComplete ($cnt/$cntall*100) -Status ("{0}/{1}" -f $cnt, $cntall)
    # $dumpname = ("{1}-{0}" -f $sensor.Name, $sensor.Probe).Replace(":", "_").Replace("\", "_").Replace("/", "_").Replace("*","_").Replace("[", "_").Replace("]","_")
    $dumpname = $sensor.Id
    $fld = Join-Path $dumpfolder -ChildPath ("{0}" -f $dumpname)
    if (!(Test-Path $fld)) {
        New-Item $fld -ItemType Directory | Out-Null
    }
    $info = $sensor | Export-Sensor -dumpfolder $fld
    $searchlist+=@($info)
    $cnt++
}
$dumpfilenm = Join-Path $dumpfolder -ChildPath "sensor-search.json"
Write-Host("FileNm: {0}, Searchlist items: {1}" -f $dumpfilenm, $searchlist.length)
$searchList | ConvertTo-Json | Out-File $dumpfilenm -Force

$timeReady = Get-Date
$ts = New-TimeSpan -Start $timeStart -End $timeReady
Write-Host("Done in {0:0.00} sec." -f $ts.TotalSeconds) -ForegroundColor Green

#endregion