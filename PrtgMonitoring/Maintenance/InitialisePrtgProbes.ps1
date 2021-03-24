#Requires -Version 7.0.0
###Requires -Modules @{ModuleName="Az.KeyVault";ModuleVersion="3.4.0"}

# To run locally install the PrtgAPI module and connect with your PRTG server, see
# https://github.com/lordmilko/PrtgAPI/wiki/Getting-Started
# The API username and passhash can be found in PRTG - AccountSettings - API Access
#
# Install-Package PrtgAPI -Source PSGallery
# Connect-PrtgServer cowmanager.my-prtg.com (New-Credential <username> <passhash>) -PassHash

if (!(Get-PrtgClient)) {
    Write-Host("First initialize PrtgAPI by running _Initialize--prtgapi.ps1") -ForegroundColor White -BackgroundColor Red
    exit 1
}

#region keyvault-functions
function Get-PrtgKeyVaultValue {
    param(
        $name
    )
    $keyvault = "cm-prtg-kv"
    $rv = Get-AzKeyVaultSecret -VaultName $keyvault -Name $name
    if ($null -eq $rv -or "" -eq $rv){
        Write-Host("KeyVault item {0} not found in {1}" -f $name, $keyvault) -ForegroundColor Blue -BackgroundColor Yellow
        $rv = $null
    }
    $rv
}

function Get-KeyVaultItem {
    param (
        [Parameter(Mandatory=$true)]
        [string]$keyName,
        [Parameter(Mandatory=$true)]
        [string]$environment
    )
    $rv = @{
        name = ""
        value = ""
    }

    $kvNameItem = Get-PrtgKeyVaultValue -Name ("prtg-{0}-{1}-name" -f $keyName, $environment)
    $kvValueItem = Get-PrtgKeyVaultValue -Name ("prtg-{0}-{1}-value" -f $keyName, $environment)

    if ($null -ne $kvNameItem -and $null -ne $kvValueItem){
        $rv.name = $kvNameItem.SecretValue | ConvertFrom-SecureString -AsPlainText
        $rv.value = $kvValueItem.SecretValue | ConvertFrom-SecureString -AsPlainText
    }
    $rv
}

function Get-KeyVaultKeyValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$keyName,
        [Parameter(Mandatory = $true)]
        [string]$environment
    )
    $rv = ""

    $kvValueItem = Get-PrtgKeyVaultValue -Name ("prtg-{0}-{1}" -f $keyName, $environment)
    if ($kvValueItem){
        $rv = $kvValueItem.SecretValue | ConvertFrom-SecureString -AsPlainText
    }
    $rv
}

#endregion

#region sensor-device functions
function Set-Sensor{
    param(
        $device,
        [string]$deviceName,
        [string]$sensorName,
        [string]$psScript,
        [string]$mutexName,
        [string]$exeParameters = "",
        [string]$interval,
        [bool]$usePlaceholders = $false,
        [bool]$useWindowsAuthentication = $false
    )
    if ($null -eq $device){
        $device = Get-Device -Name $deviceName
    }
    # Write-Host("Add {0} to device {1}" -f $psScript, $device.Name) -ForegroundColor DarkMagenta
    $sensor = Get-Sensor -Device $device -Name $sensorName
    if ($null -eq $sensor){
        try {
            $params = $device | Get-SensorTarget ExeXml -Name $psScript -Parameters
            $params.Name = $sensorName
            $params.Mutex = $mutexName
            if ("" -ne $interval) {
                $params.Interval = $interval
            }
            $params.ExeParameters = $exeParameters
            $params.UseWindowsAuthentication = $useWindowsAuthentication
            if ($usePlaceholders) {
                $params.SetExeEnvironmentVariables = $true
            }
            else {
            }
            $sensor = $device | Add-Sensor $params
            Write-Host("New sensor added: ({2}) {0} - {1}" -f $sensor.Device, $sensor.Name, $sensor.Id) -ForegroundColor Yellow
        }
        catch {
            Write-Host("Error adding {1} to {0}: {2}" -f $device.Name, $sensorName, $_.Exception.Message) -ForegroundColor Red -BackgroundColor White
        }
    }
    else {
        # We could update settings, but where lies the 'truth'? Truth is the configuration of PRTG. So do not update-settings.
        # Instead settings should be exported from periodically, and applied if needed.
        Write-Host("Sensor found: {0} - {1} (settings are NOT updated)" -f $deviceName, $sensorName) -ForegroundColor Green
    }
}
#endregion

#region add-servertype-specific devices
function AddMeasurementsDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )

    $deviceName = "{0}-Measurements" -f $probeName

    $device = Get-Device -Name $deviceName
    if ($null -eq $device){
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name 
    }
    $properties = @{
        Interval = "00:15:00"
        Tags     = "stage-{0},measurements" -f $probeEnvironment
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        deviceName = $deviceName
        sensorName = "Measurement files - avg size"
        psScript = "GetPrtgFolderInfoSize.ps1"
        mutexName = "file-powershell"
        exeParameters = "-rootfolder M:\CowManager\CowManager.Device.Process\Measurements"
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Measurement files 2 upload"
        psScript = "GetPrtgFolderInfoSize.ps1"
        mutexName = "file-powershell"
        exeParameters = "-rootFolder S:\CowManager\CowManager.Device.Process\Dump"
    }
    Set-Sensor @param
}

function AddSrvGenericDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )

    $probe = Get-Probe $probeName

    # Some sensor can only be added to the 'probe device'
    $deviceName = "probe device"
    $device = $probe | Get-Device -Name $deviceName

    # $device | get-sensortype --> wmisqlserver2016
    $sensortype = "wmilogicaldiskv2"
    $parameters = $device | New-SensorParameters -RawType $sensortype
    foreach ($instance in $parameters.Targets["datafieldlist__check"]) {
        if ($instance.Name -in ("_Total","HarddiskVolume5")){

        }
        else{
            $sensorName = "Volume IO {0}" -f $instance.Name
            $sensor = $device | Get-Sensor -Name ("{0}*" -f $sensorName)
            if ($null -eq $sensor) {
                Write-host("Adding {0}" -f $sensorName) -ForegroundColor Cyan
                $parameters.Unlock()
                $parameters.datafieldlist__check = $instance.Name
                $parameters.Lock()
                $sensor = $device | Add-Sensor $parameters
                $sensor | Set-ObjectProperty -Name $sensorName
            }
            else{
                Write-host("Sensor found {0}" -f $sensorName) -ForegroundColor Green
            }
        }
    }

    # now proceed with the actual 'generic'
    $deviceName = ("{0}-generic" -f $probe.Name)
    $mutexName = "srv-powershell"

    $device = Get-Device -Name $deviceName
    if ($null -eq $device){
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Interval = "00:15:00"
        Tags     = "stage-{0},system" -f $probeEnvironment
    }
    $device | Set-ObjectProperty @properties
    Write-Host("Configuring device {0}" -f $device.Name) -ForegroundColor Cyan

    $param = @{
        device        = $device
        sensorName    = "Autostart Windows Services check"
        psScript      = "GetPrtgWindowsServicesAutostartStatus.ps1"
        mutexName     = $mutexName
        exeParameters = ""
    }
    Set-Sensor @param

    $param = @{
        device        = $device
        sensorName    = "Scheduled task results"
        psScript      = "GetPrtgWindowsScheduledTasks.ps1"
        mutexName     = $mutexName
        exeParameters = ""
    }
    Set-Sensor @param

    # determination rawsensortype:
    # e.g.: get-device -id 4965 | get-sensortype |?{$_.name -like "*update*"}
    $sensorName = "Windows Updates"
    $sensor = $device | Get-Sensor -Name $sensorName
    if ($null -eq $sensor) {
        $sensorType = "lastwindowsupdate"
        $parameters = $device | New-SensorParameters -RawType $sensorType
        $parameters.Name = $sensorName
        $sensor = $device | Add-Sensor $parameters
    }
    $interval = "1.00:00:00" # =24h
    $sensor | Set-ObjectProperty -Interval $interval
    Write-Host("Sensor {0}" -f $sensor.Name) -ForegroundColor Green
    
    $sensorName = "Uptime"
    $sensor = $device | Get-Sensor -Name $sensorName
    if ($null -eq $sensor) {
        $sensorType = "wmiuptime"
        $parameters = $device | New-SensorParameters -RawType $sensorType
        $parameters.Name = $sensorName
        $sensor = $device | Add-Sensor $parameters
    }
    $interval = "00:10:00"
    $sensor | Set-ObjectProperty -Interval $interval
    Write-Host("Sensor {0}" -f $sensor.Name) -ForegroundColor Green
}

function AddSrvFactoryDevice{
    param(
        [string]$probeName
    )

    $probe = Get-Probe -Name $probeName

    $deviceName = "Probe Device"
    $device = $probe | Get-Device -Name $deviceName

    $factoryDeviceName = "{0}-factory" -f $probe.Name
    $factoryDevice = $probe | Get-Device -Name $factoryDeviceName
    if ($null -eq $factoryDevice) {
        $factoryDevice = Add-Device -Destination $probe -Name $factoryDeviceName -Host $probe.name
    }

    $factorySensorName = "Avg Read Time"
    $factorySensor = $factoryDevice | Get-Sensor -Name $factorySensorName
    $inputSensors = $device | Get-Sensor -name "volume*:"
    if ($null -eq $factorysensor) {
        $channelid = 10  #= avg read time, hardcoded, not really charming
        $channelnametemplate = "Avg Read Time {0}"
        $factorysensor = $inputsensors | new-sensor -factory -name $factorysensorname { ($channelnametemplate -f ($_.name.substring(10))) } -DestinationId $factorydevice.Id -ChannelId $channelid
    }

    $factorysensorname = "Disk Transfer"
    $factorysensor = $factorydevice | get-sensor -name $factorysensorname
    if ($null -eq $factorysensor) {
        $channelid = 17 #= disk transfer
        $channelnametemplate = "Disk Transfer {0}"
        $factorysensor = $inputsensors | new-sensor -factory -name $factorysensorname { ($channelnametemplate -f ($_.name.substring(10))) } -DestinationId $factorydevice.Id -ChannelId $channelid
    } 

    $factorysensorname = "Avg Queue Length"
    $factorysensor = $factorydevice | get-sensor -name $factorysensorname
    if ($null -eq $factorysensor) {
        $channelid = 13 # = avg queue length
        $channelnametemplate = "Avg Queue {0}"
        $factorysensor = $inputsensors | new-sensor -factory -name $factorysensorname { ($channelnametemplate -f ($_.name.substring(10))) } -DestinationId $factorydevice.Id -ChannelId $channelid
    } 
}

function AddWebDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-iis" -f $probe.Name)

    $device = Get-Device -Name $deviceName
    if ($null -eq $device) {
        $device = Add-Device -Destination $probe -Name $deviceName -Host "127.0.0.1"
    }
    $properties = @{
        Interval = "00:01:00"
        Tags     = "stage-{0},iis" -f $probeEnvironment
    }
    $device | Set-ObjectProperty @properties

    #badmail
    $sensorName = "Badmail"
    $sensor = $device | Get-Sensor -Name $sensorName
    if ($null -eq $sensor) {
        $sensorType = "folder"
        $parameters = $device | New-SensorParameters -RawType $sensorType
        $parameters.Name = "{0}" -f $sensorName
        $parameters.foldername = "C:\inetpub\mailroot\Badmail"
        $parameters.recurse = 0
        $sensor = $device | Add-Sensor $parameters
    }

    $domainname = switch ($probeEnvironment) {
        "prod" {
            "cowmanager.com"
            break
        }
        default {
            "{0}-cowmanager.com" -f $probeEnvironment
            break
        }
    }
    #per site IIS traffic sensor
    $hostname = "sensor.{0}" -f $domainname
    $sensorName = "IIS $hostname"
    $sensor = $device | Get-Sensor -Name $sensorName
    if ($null -eq $sensor) {
        $sensorType = "wmiiis"
        $parameters = $device | New-SensorParameters -RawType $sensorType
        $parameters.Name = $sensorName
        $parameters.Unlock()
        $parameters.instancenames__check = $hostname
        $parameters.Lock()
        $sensor = $device | Add-Sensor $parameters
    }
    $hostname = "farmapi.{0}" -f $domainname
    $sensorName = "IIS $hostname"
    $sensor = $device | Get-Sensor -Name $sensorName
    if ($null -eq $sensor) {
        $sensorType = "wmiiis"
        $parameters = $device | New-SensorParameters -RawType $sensorType
        $parameters.Name = $sensorName
        $parameters.Unlock()
        $parameters.instancenames__check = $hostname
        $parameters.Lock()
        $sensor = $device | Add-Sensor $parameters
    }
}
function AddDeviceWebDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-iis" -f $probe.Name)

    $device = Get-Device -Name $deviceName
    if ($null -eq $device) {
        $device = Add-Device -Destination $probe -Name $deviceName -Host "127.0.0.1"
    }
    $properties = @{
        Interval = "00:01:00"
        Tags     = "stage-{0},deviceweb" -f $probeEnvironment
    }
    $device | Set-ObjectProperty @properties

    $domainname = switch($probeEnvironment){
        "prod" {
            "cowmanager.com"
            break
        }
        default {
            "{0}-cowmanager.com" -f $probeEnvironment
            break
        }
    }
    $hostname = "farmapi.{0}" -f $domainname
    $sensorName = "IIS $hostname"
    $sensor = $device | Get-Sensor -Name $sensorName
    if ($null -eq $sensor) {
        $sensorType = "wmiiis"
        $parameters = $device | New-SensorParameters -RawType $sensorType
        $parameters.Name = $sensorName
        $parameters.Unlock()
        $parameters.instancenames__check = $hostname
        $parameters.Lock()
        $sensor = $device | Add-Sensor $parameters
    }
}
function AddMsmqDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-msmq" -f $probe.Name)

    $device = Get-Device -Name $deviceName
    if ($null -eq $device) {
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Interval = "00:01:00"
        Tags     = "stage-{0},msmq" -f $probeEnvironment
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        deviceName    = $deviceName
        sensorName    = "MSMQ Message Age"
        psScript      = "GetPrtgMsmqMessageAge.ps1"
        mutexName     = "msmq-powershell"
        exeParameters = "-queueNameFilter *process"
    }
    Set-Sensor @param

    $param = @{
        deviceName    = $deviceName
        sensorName    = "MSMQ Queue length"
        psScript      = "GetPrtgMsmqQueueLength.ps1"
        mutexName     = "msmq-powershell"
        exeParameters = "-queueNameFilter *process"
    }
    Set-Sensor @param

    $param = @{
        deviceName    = $deviceName
        sensorName    = "MSMQ Error Queue length"
        psScript      = "GetPrtgMsmqQueueLength.ps1"
        mutexName     = "msmq-powershell"
        exeParameters = "-queueNameFilter *process.error"
    }
    Set-Sensor @param

    $param = @{
        deviceName    = $deviceName
        sensorName    = "MSMQ Outgoing Queue length"
        psScript      = "GetPrtgMsmqOutgoingQueueLength.ps1"
        mutexName     = "msmq-powershell"
        exeParameters = "-queueNameFilter *process"
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "NServiceBus msg/sec"
        psScript   = "GetPrtgMsmqProcessedPerSec.ps1"
        mutexName  = "msmq-powershell"
    }
    Set-Sensor @param
}
function AddSqlDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )
    $kvItem = Get-KeyVaultItem -keyName "sqluser" -environment $probeEnvironment
    $windowsusername = $kvItem.name
    $windowspwd = $kvItem.value

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-sql" -f $probe.Name)
    $device = Get-Device -Name $deviceName
    $mutexName = "sql-powershell"
    if ($null -eq $device){
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Interval        = "00:15:00"
        Tags            = "stage-{0},query" -f $probeEnvironment
        WindowsDomain   = $probe.name
        WindowsUserName = $windowsusername
        WindowsPassword = $windowspwd
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        deviceName = $deviceName
        sensorName = "Last table update"
        psScript = "GetPrtgSqlLastTableUpdate.ps1"
        mutexName = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Heat-alert latency"
        psScript = "GetPrtgSqlAlertLatency.ps1"
        mutexName = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Company last communication received"
        psScript = "GetPrtgSqlCompanyCommunication.ps1"
        mutexName = $mutexName
        exeParameters = "-includeAccountNrs 00001;00002"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Alerts per day"
        psScript = "GetPrtgSqlCountAlertTypes.ps1"
        mutexName = $mutexName
        interval = "12:00:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Cows in deleted group"
        psScript = "GetPrtgSqlCountCowInDeletedGroup.ps1"
        mutexName = $mutexName
        interval = "12:00:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Cowdata Synchronisations/provider"
        psScript = "GetPrtgSqlCowDataSync.ps1"
        mutexName = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Cow events"
        psScript = "GetPrtgSqlCowEvent.ps1"
        mutexName = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Cow process latency"
        psScript = "GetPrtgSqlCowProcessLatency.ps1"
        mutexName = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Last communication received from active PC-application"
        psScript = "GetPrtgSqlPcAverageLastTransmit.ps1"
        mutexName = $mutexName
        interval = "00:05:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Salesforce/Exact Sync"
        psScript = "GetPrtgSqlSyncInterfaces.ps1"
        mutexName = $mutexName
        interval = "00:05:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "System sanity checks"
        psScript = "GetPrtgSqlCmSysSanityChecks.ps1"
        mutexName = $mutexName
        interval = "00:05:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Warranty status"
        psScript = "GetPrtgSqlWarrantyStatus.ps1"
        mutexName = $mutexName
        interval = "01:00:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName               = $deviceName
        sensorName               = "Calculations inserted last 1h"
        psScript                 = "GetPrtgSqlCalculationRecordsInserted.ps1"
        mutexName                = $mutexName
        interval                 = "01:00:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName               = $deviceName
        sensorName               = "Calculations inserted (extrapolated)"
        psScript                 = "GetPrtgSqlCalculationRecordsInsertedExtrapolated.ps1"
        mutexName                = $mutexName
        interval                 = "01:00:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param
}

function AddCowDataImportDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )
    $kvItem = Get-KeyVaultItem -keyName "sqluser" -environment $probeEnvironment
    $windowsusername = $kvItem.name
    $windowspwd = $kvItem.value

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-cowdataimport" -f $probe.Name)
    $device = Get-Device -Name $deviceName
    $mutexName = "sql-powershell"
    if ($null -eq $device) {
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Interval        = "00:15:00"
        Tags            = "stage-{0},query" -f $probeEnvironment
        WindowsDomain   = $probe.name
        WindowsUserName = $windowsusername
        WindowsPassword = $windowspwd
    }
    $device | Set-ObjectProperty @properties


    $param = @{
        deviceName               = $deviceName
        sensorName               = "Last details"
        psScript                 = "GetPrtgSqlCowDataImportLastDetails.ps1"
        mutexName                = $mutexName
        interval                 = "00:05:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName               = $deviceName
        sensorName               = "Cowdata Synchronisations/provider"
        psScript                 = "GetPrtgSqlCowDataSync.ps1"
        mutexName                = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName               = $deviceName
        sensorName               = "Import success"
        psScript                 = "GetPrtgSqlImportLogSuccess.ps1"
        mutexName                = $mutexName
        interval                 = "00:05:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName               = $deviceName
        sensorName               = "Import load"
        psScript                 = "GetPrtgSqlCowDataImportLoad.ps1"
        mutexName                = $mutexName
        interval                 = "00:05:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName               = $deviceName
        sensorName               = "Files to import"
        psScript                 = "GetPrtgDataImport.ps1"
        mutexName                = $mutexName
        exeParameters            = "-channelinfoFile s:\temp\cowdataimportfiles.json"
        interval                 = "00:05:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName               = $deviceName
        sensorName               = "Average load time"
        psScript                 = "GetPrtgSqlImportAverageLoadTime.ps1"
        mutexName                = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param
}

function AddSqlDeviceDevice{
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )
    $kvItem = Get-KeyVaultItem -keyName "sqluser" -environment $probeEnvironment
    $windowsusername = $kvItem.name
    $windowspwd = $kvItem.value

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-devicesql" -f $probe.Name)
    $mutexName = "sql-powershell"
    $device = Get-Device -Name $deviceName
    if ($null -eq $device){
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Interval        = "00:15:00"
        Tags            = "stage-{0},query" -f $probeEnvironment
        WindowsDomain   = $probe.name
        WindowsUserName = $windowsusername
        WindowsPassword = $windowspwd
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        deviceName = $deviceName
        sensorName = "Linked devices / company"
        psScript = "GetPrtgSqlCompanyLinkedSensors.ps1"
        mutexName = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Software version PC"
        psScript = "GetPrtgSqlDeviceSoftwareVersion.ps1"
        mutexName = $mutexName
        exeParameters = "-deviceType `"PC`""
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Software version Coordinator"
        psScript = "GetPrtgSqlDeviceSoftwareVersion.ps1"
        mutexName = $mutexName
        exeParameters = "-deviceType `"Coordinator`""
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Software version Router"
        psScript = "GetPrtgSqlDeviceSoftwareVersion.ps1"
        mutexName = $mutexName
        exeParameters = "-deviceType `"Router`""
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Software version Sensor"
        psScript = "GetPrtgSqlDeviceSoftwareVersion.ps1"
        mutexName = $mutexName
        exeParameters = "-deviceType `"Sensor`""
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Devices PC"
        psScript = "GetPrtgSqlDeviceStatus.ps1"
        mutexName = $mutexName
        exeParameters = "-deviceType `"PC`""
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Devices Coordinator"
        psScript = "GetPrtgSqlDeviceStatus.ps1"
        mutexName = $mutexName
        exeParameters = "-deviceType `"Coordinator`""
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Devices Router"
        psScript = "GetPrtgSqlDeviceStatus.ps1"
        mutexName = $mutexName
        exeParameters = "-deviceType `"Router`""
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Devices Sensor"
        psScript = "GetPrtgSqlDeviceStatus.ps1"
        mutexName = $mutexName
        exeParameters = "-deviceType `"Sensor`""
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName               = $deviceName
        sensorName               = "AccountChecks - Beef"
        psScript                 = "GetPrtgSqlCmAccountChecks.ps1"
        mutexName                = $mutexName
        exeParameters            = "-beef"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName               = $deviceName
        sensorName               = "AccountChecks - Non-beef"
        psScript                 = "GetPrtgSqlCmAccountChecks.ps1"
        mutexName                = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param
}

function AddSqlSysDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )
    $kvItem = Get-KeyVaultItem -keyName "sqluser" -environment $probeEnvironment
    $windowsusername = $kvItem.name
    $windowspwd = $kvItem.value
    $mutexName = "sql-powershell"

    $probe = Get-Probe $probeName
    $deviceName = ("Probe Device")
    $device = $probe | Get-Device -Name $deviceName
    # $device | get-sensortype --> wmisqlserver2016
    # now determine the installed instances
    $sensortype = "wmisqlserver2019" #first assume sql 2019
    $parameters = $device | New-SensorParameters -RawType $sensortype -ErrorAction SilentlyContinue
    if ($null -eq $parameters){
        $sensortype = "wmisqlserver2016"
        $parameters = $device | New-SensorParameters -RawType $sensortype -ErrorAction SilentlyContinue
    }
    foreach($instance in $parameters.Targets["servicenamelist__check"].Value){
        $deviceName = "{0}-{1}" -f $probe.name, $instance
        $device = $probe | Get-Device -Name $deviceName
        if ($null -eq $device) {
            $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
        }
        $properties = @{
            Tags            = "stage-{0},sql" -f $probeEnvironment
            WindowsDomain   = $probe.name
            WindowsUserName = $windowsusername
            WindowsPassword = $windowspwd
            Interval        = "00:15:00"
        }
        $device | Set-ObjectProperty @properties

        $instanceName = switch ($instance) {
            "MSSQLSERVER" { "localhost"; break }
            default { "{0}\{1}" -f $probe.name, ($_.split("$")[1]); break }
        }
        $param = @{
            deviceName               = $deviceName
            sensorName               = "Last data backup"
            psScript                 = "GetPrtgSqlLastDatabaseBackup.ps1"
            mutexName                = $mutexName
            useWindowsAuthentication = $true
            exeParameters            = "-targetSql {0}" -f $instanceName
        }
        Set-Sensor @param

        $param = @{
            deviceName               = $deviceName
            sensorName               = "Last backup/type"
            psScript                 = "GetPrtgSqlLastBackup.ps1"
            mutexName                = $mutexName
            useWindowsAuthentication = $true
            exeParameters            = "-targetSql {0}" -f $instanceName
        }
        Set-Sensor @param

        $param = @{
            deviceName               = $deviceName
            sensorName               = "Sql Datafile usage"
            psScript                 = "GetPrtgSqlDataFileUsage.ps1"
            mutexName                = $mutexName
            useWindowsAuthentication = $true
            exeParameters            = "-targetSql {0}" -f $instanceName
        }
        Set-Sensor @param

        $param = @{
            deviceName               = $deviceName
            sensorName               = "Tempdb usage"
            psScript                 = "GetPrtgSqlTempDbUsage.ps1"
            mutexName                = $mutexName
            useWindowsAuthentication = $true
            exeParameters            = "-targetSql {0}" -f $instanceName
        }
        Set-Sensor @param

        $param = @{
            deviceName               = $deviceName
            sensorName               = "Remaining days sql-partitions"
            psScript                 = "GetPrtgSqlPartitionRemainingDaysValid.ps1"
            mutexName                = $mutexName
            useWindowsAuthentication = $true
            exeParameters            = "-targetSql {0}" -f $instanceName
        }
        Set-Sensor @param

        $param = @{
            deviceName               = $deviceName
            sensorName               = "SqlServer Health"
            psScript                 = "GetPrtgSql_ServerSysValues.ps1"
            mutexName                = $mutexName
            useWindowsAuthentication = $true
            exeParameters            = "-targetSql {0}" -f $instanceName
        }
        Set-Sensor @param

        $param = @{
            deviceName               = $deviceName
            sensorName               = "Mirroring state"
            psScript                 = "GetPrtgSql_ServerMirroringState.ps1"
            Interval                 = "00:01:00"
            mutexName                = $mutexName
            useWindowsAuthentication = $true
            exeParameters            = "-targetSql {0}" -f $instanceName
        }
        Set-Sensor @param

        # OK, Brave attempt to add the default sql-2016 checks, but that proves to be 
        # quite fiddly with setting the correct parameters.
        # Also: how do you set the sql-sensortype?
        # $sensorName = $parameters.Targets["servicenamelist__check"][$idx].Name
        # $sensor = $device | Get-Sensor -Name ("{0}*" -f $sensorName)
        # if ($null -eq $sensor){
        #     # $parameters is still correct, just adjust
        #     $parameters.Unlock()
        #     $parameters.servicenamelist__check = $parameters.Targets["servicenamelist__check"][$idx].Name
        #     $parameters.Lock()
        #     $sensor = $device | Add-Sensor $parameters
        # }
    }
    $mutexName = "sql-powershell"
    $deviceName = ("{0}-database" -f $probe.Name)

}

function AddBuildDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )
}
function AddConnectivityCheck {
    param(
        [string]$probeName,
        [switch]$octopusDeployServer
    )

    #Add checks for the needed connectivity of the deployment server
    if ($octopusDeployServer){
        $probe = Get-Probe $probeName
        $grpName = ("{0}-connectivity" -f $probe.Name)
        $grp = $probe | Get-Group -name $grpName
        if ($null -eq $grp) {
            $parameters = New-GroupParameters -Name $grpName
            $grp = $probe | Add-Group $parameters
        }
        $properties = @{
            Interval = "00:05:00"
            Tags     = "octopuschecks,connectivity"
        }
        $grp | Set-ObjectProperty @properties


        $octoChecks = @(
            ("cm-app02-test", "cm-app02-test37.westeurope.cloudapp.azure.com", 10933),
            ("cm-web01-test", "cm-web01-test37.westeurope.cloudapp.azure.com", 10933),
            ("cm-app01-beta", "cm-app01-beta.westeurope.cloudapp.azure.com", 10933),
            ("cm-web01-beta", "cm-web01-beta.westeurope.cloudapp.azure.com", 10933),
            ("agis-app04", "10.30.2.21", 10933),
            ("agis-web05", "10.30.2.24", 10933),
            ("agis-web06", "10.30.2.25", 10933),
            ("agis-web12", "10.30.2.26", 10933),
            ("agis-web13", "10.30.2.27", 10933),
            ("agis-db12", "10.30.2.22", 10933),
            ("agis-db13", "10.30.2.23", 10933)
        )
        foreach ($octoCheck in $octoChecks) {
            $deviceName = $octoCheck[0]
            $deviceAddress = $octoCheck[1]
            $devicePort = $octoCheck[2]
            $device = $grp | Get-Device -Name $deviceName
            if ($null -eq $device) {
                $device = $grp | Add-Device -Name $deviceName -Host $deviceAddress
            }
            $sensorName = "Octopus: {0}" -f $devicePort
            $sensor = $device | Get-Sensor -Name $sensorName
            if ($null -eq $sensor) {
                $sensorType = "port"
                $parameters = $device | New-SensorParameters -RawType $sensorType
                $parameters.Name = $sensorName
                $parameters.port = $devicePort
                $sensor = $device | Add-Sensor $parameters
                Write-Host("Added port-check: {0} - {1}:{2}" -f $deviceName, $deviceAddress, $devicePort) -ForegroundColor Yellow
            }
            else {
                Write-Host("Found port-check: {0} - {1}:{2}" -f $deviceName, $deviceAddress, $devicePort) -ForegroundColor Green
            }
        }
    }
}
function AddBehaviorDevice {
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-behavior" -f $probe.Name)
    $mutexName = "behavior-powershell"

    $device = Get-Device -Name $deviceName
    if ($null -eq $device){
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Interval = "00:15:00"
        Tags     = "stage-{0},behavior" -f $probeEnvironment
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        deviceName = $deviceName
        sensorName = "Group alerts"
        psScript = "GetPrtgPerfCount-GroupAlert.ps1"
        mutexName = $mutexName
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Cow alerts"
        psScript   = "GetPrtgPerfCount-CowAlert.ps1"
        mutexName  = $mutexName
    }
    Set-Sensor @param
}
function AddFileUploadDevice{
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-file" -f $probe.Name)
    $mutexName = "file-powershell"

    $device = Get-Device -Name $deviceName
    if ($null -eq $device){
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Interval = "00:05:00"
        Tags     = "stage-{0},azureupload" -f $probeEnvironment
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        deviceName = $deviceName
        sensorName = "Measurementfiles left to upload"
        psScript = "GetPrtgFolderInfo.ps1"
        mutexName = $mutexName
        exeParameters = '-rootFolder "S:\CowManager\CowManager.Device.Process\Dump"'
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Behaviordumpfiles left to upload"
        psScript = "GetPrtgCountProcessFilesToDump.ps1"
        mutexName = $mutexName
        exeParameters = '-rootDumpFolder "S:\CowManager\CowManager.Utilities.CowManager2Azure\Dump"'
    }
    Set-Sensor @param
}
function AddDeviceProcessFileDevice{
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-file" -f $probe.Name)
    $mutexName = "file-powershell"

    $device = Get-Device -Name $deviceName
    if ($null -eq $device){
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Interval = "00:10:00"
        Tags     = "stage-{0},measurements" -f $probeEnvironment
    }
    $device | Set-ObjectProperty @properties

    if ($probeEnvironment -eq "prod"){
        $drives = @("M", "S")
    }
    else {
        $drives = @("S")
    }

    $drives | ForEach-Object{
        $param = @{
            deviceName    = $deviceName
            sensorName    = "Measurement files {0}: - avg size" -f $_
            psScript      = "GetPrtgFolderInfo.ps1"
            mutexName     = $mutexName
            exeParameters = "-rootfolder {0}:\CowManager\CowManager.Device.Process\Measurements" -f $_
        }
        Set-Sensor @param
    }
}
function AddPushNotificationDevice{
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )
    $kvItem = Get-KeyVaultItem -keyName "sqluser" -environment $probeEnvironment
    $windowsusername = $kvItem.name
    $windowspwd = $kvItem.value

    $probe = Get-Probe $probeName
    $deviceName = ("{0}-pushnotifications" -f $probe.Name)
    $mutexName = "push-powershell"

    $device = Get-Device -Name $deviceName
    if ($null -eq $device){
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $properties = @{
        Interval        = "00:15:00"
        Tags            = "stage-{0},notifications" -f $probeEnvironment
        WindowsDomain   = $probe.name
        WindowsUserName = $windowsusername 
        WindowsPassword = $windowspwd
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        deviceName = $deviceName
        sensorName = "Push notifications"
        psScript = "GetPrtgSqlPushNotification.ps1"
        mutexName = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param

    $param = @{
        deviceName = $deviceName
        sensorName = "Push notification Hub registration"
        psScript = "GetPrtgSqlPushNotificationHubRegistration.ps1"
        mutexName = $mutexName
        useWindowsAuthentication = $true
    }
    Set-Sensor @param
}
function AddExportDataDevice{
    param(
        [string]$probeName,
        [string]$probeEnvironment
    )

    $probe = Get-Probe $probeName

    $deviceName = ("{0}-exportdata" -f $probe.Name)
    $mutexName = "sql-powershell"

    $device = Get-Device -Name $deviceName
    if ($null -eq $device){
        $device = Add-Device -Destination $probe -Name $deviceName -Host $probe.name
    }
    $keyName = "sqluser"
    $kvItem = Get-KeyVaultItem -keyName $keyName -environment $probeEnvironment
    $properties = @{
        WindowsDomain   = $probe.Name
        WindowsUserName = $kvItem.name
        WindowsPassword = $kvItem.value
        Tags            = "stage-{0},query" -f $probeEnvironment
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        deviceName = $deviceName
        sensorName = "Exportdata Results"
        psScript = "GetPrtgSqlExportDataResult.ps1"
        mutexName = $mutexName
        interval = "12:00:00"
        useWindowsAuthentication = $true
    }
    Set-Sensor @param
}
#endregion

#region host-probe-environment
function Add-ManufactoorApiDevice {
    param(
        $parent,
        [string]$environment
    )
    Write-Host("Add-ManufactoorApiDevice - started - {0} - {1}" -f $parent.Name, $environment) -ForegroundColor White
    $kvItem = Get-KeyVaultItem -keyName "manufactoor-api" -environment $environment
    $windowsusername = $kvItem.name
    $windowsuserpwd = $kvItem.value

    switch ($environment) {
        "prod" { $baseuri = "manufactoor.cowmanager.com" }
        Default { $baseuri = "manufactoor.{0}-cowmanager.com" -f $environment }
    }

    $deviceName = "Manufactoor.api"
    $mutexName = "powershell-manufactoorapi"

    $device = $parent | Get-Device -Name $deviceName
    if ($null -eq $device) {
        $device = $parent | Add-Device -Name $deviceName -Host ("{0}" -f $baseuri)
    }
    $properties = @{
        Interval        = "00:15:00"
        Tags            = "api,manufactoor"
        WindowsUserName = $windowsusername
        WindowsPassword = $windowsuserpwd
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        device                   = $device
        deviceName               = $deviceName
        sensorName               = "Manufactoor health"
        psScript                 = "GetPrtgManufactoorHealth.ps1"
        mutexName                = $mutexName
        usePlaceHolders          = $true
        useWindowsAuthentication = $false
    }
    Set-Sensor @param 
    Write-Host("Add-ManufactoorApiDevice - ready") -ForegroundColor DarkGray
}

function Add-CowManagerApiDevice {
    param(
        $parent,
        [string]$environment,
        [string]$accountnr
    )
    Write-Host("Add-CowManagerApiDevice - started - {0} - {1} - {2}" -f $parent.Name, $environment, $accountnr) -ForegroundColor White

    switch ($environment) {
        "prod" { $baseuri = "sensor.cowmanager.com" }
        Default { $baseuri = "sensor.{0}-cowmanager.com" -f $environment }
    }

    $accountKeyName = "cowmanager-api-{0}" -f $accountnr

    $kvItem = Get-KeyVaultItem -keyName $accountKeyName -environment $environment
    $windowsusername = $kvItem.name
    $windowsuserpwd = $kvItem.value

    $deviceName = "CowManager.api"
    $mutexName = "powershell-cowmanagerapi"

    $device = $parent | Get-Device -Name $deviceName
    if ($null -eq $device) {
        $device = $parent | Add-Device -Name $deviceName -Host ("https://{0}" -f $baseuri)
    }
    $properties = @{
        Interval        = "00:15:00"
        Tags            = "api"
        WindowsDomain   = $accountnr
        WindowsUserName = $windowsusername 
        WindowsPassword = $windowsuserpwd
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        device                   = $device
        deviceName               = $deviceName
        sensorName               = "GetAlerts-{0}" -f $accountnr
        psScript                 = "GetPrtgCmApi-GetAlerts.ps1"
        mutexName                = $mutexName
        usePlaceHolders          = $true
        useWindowsAuthentication = $false
    }
    Set-Sensor @param 
    Write-Host("Add-CowManagerApiDevice - ready") -ForegroundColor DarkGray
}

function Add-CowManagerWebDevice {
    param(
        $parent,
        [string]$environment,
        [string]$accountnr
    )
    Write-Host("Add-CowManagerWebDevice - started - {0} - {1} - {2}" -f $parent.Name, $environment, $accountnr) -ForegroundColor White

    switch ($environment) {
        "prod" { $baseuri = "sensor.cowmanager.com" }
        Default { $baseuri = "sensor.{0}-cowmanager.com" -f $environment }
    }

    $accountKeyName = "cowmanager-web-{0}" -f $accountnr

    $kvItem = Get-KeyVaultItem -keyName $accountKeyName -environment $environment
    $windowsusername = $kvItem.name
    $windowsuserpwd = $kvItem.value

    $deviceName = "CowManager.web"
    $mutexName = "powershell-cowmanagerweb"

    $device = $parent | Get-Device -Name $deviceName
    if ($null -eq $device) {
        $device = $parent | Add-Device -Name $deviceName -Host ("{0}" -f $baseuri)
    }
    $properties = @{
        WindowsDomain   = $accountnr 
        WindowsUserName = $windowsusername 
        WindowsPassword = $windowsuserpwd
        Interval        = "00:10:00"
        Tags            = "web"
    }
    $device | Set-ObjectProperty @properties

    $param = @{
        device                   = $device
        deviceName               = $deviceName
        sensorName               = "Login and load page - {0}" -f $accountnr
        psScript                 = "GetPrtgCmWeb-Login.ps1"
        mutexName                = $mutexName
        usePlaceHolders          = $true
        useWindowsAuthentication = $false
    }
    Set-Sensor @param 

    Write-Host("Add-CowManagerWebDevice - ready") -ForegroundColor DarkGray
}

function Add-CowManagerGroup {
    param(
        $parent,
        [string]$environment
    )
    $mutexName = "prtg-cowmanager"
    function Add-CowManagerAiDevice {
        param(
            $parent,
            [string]$environment
        )
        Write-Host("Add-CowManagerAiDevice - started - {0} - {1}" -f $parent.Name, $environment) -ForegroundColor White

        $kvItem = Get-KeyVaultItem -keyName "applicationinsights" -environment $environment
        $windowsusername = $kvItem.name
        $windowsuserpwd = $kvItem.value

        $deviceName = "{0}-cowmanager-ai" -f $environment

        $device = $parent | Get-Device -Name $deviceName
        if ($null -eq $device) {
            $device = $parent | Add-Device -Name $deviceName -Host "127.0.0.1"
        }
        $properties = @{
            WindowsDomain   = $accountnr 
            WindowsUserName = $windowsusername 
            WindowsPassword = $windowsuserpwd 
            Interval        = "00:05:00"
            Tags            = "applicationinsights" -f $environment
        }
        $device | Set-ObjectProperty @properties

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "AvgDuration/rolename V2"
            psScript                 = "GetPrtgAi_QueryV2.ps1"
            exeParameters            = "-timespanminutes 5 -query 'requests | extend rolename = iif(cloud_RoleName has `"CowManager.`", substring(cloud_RoleName,11), cloud_RoleName) | extend server = iif(client_Type == `"PC`", cloud_RoleInstance, client_Type) | extend channelName = strcat(rolename, `" (`",server, `")`") | extend channelType = `"TimeResponse`" | summarize channelValue=toint(avg(duration)) by channelName, channelType | order by channelName asc'"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Request/rolename"
            psScript                 = "GetPrtgAi_Query.ps1"
            exeParameters            = "-timespanminutes 5 -query 'requests | extend rolename = iif(cloud_RoleName has `"CowManager.`", substring(cloud_RoleName,11), cloud_RoleName) | extend server = iif(client_Type == `"PC`", cloud_RoleInstance, client_Type) | extend cntName = strcat(rolename, `" (`",server, `")`") | summarize count() by cntName | order by cntName asc'"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "HTTP-Resultcodes"
            psScript                 = "GetPrtgAi_Query.ps1"
            exeParameters            = "-timespanMinutes 5 -query 'requests | where toint(resultCode) >= 200 | summarize count() by resultCode | order by resultCode asc'"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Request queue limit victims"
            psScript                 = "GetPrtgAi_Query.ps1"
            exeParameters            = "-timespanMinutes 15 -query 'exceptions | where innermostMessage == `"The request queue limit of the session is exceeded.`" | summarize count() by tostring(cloud_RoleInstance)'"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Deadlock victims"
            psScript                 = "GetPrtgAi_Query.ps1"
            exeParameters            = "-timespanMinutes 5 -query 'exceptions | where client_Type != `"Browser`" | extend msg = strcat(outerMessage, `" (`", innermostMessage, `")`") | extend source = `"Deadlock-victims`" | summarize cnt = sumif(itemCount, msg has `" was deadlocked `") by source'"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Application exceptions"
            psScript                 = "GetPrtgAi_ApplicationErrors.ps1"
            exeParameters            = "-timespanMinutes 60"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Application unusual exceptions"
            psScript                 = "GetPrtgAi_ApplicationErrorsFiltered.ps1"
            exeParameters            = "-timespanMinutes 60"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Sensor vs sensoor"
            psScript                 = "GetPrtgAi_Query.ps1"
            exeParameters            = "-timespanMinutes 1440 -query 'requests | where cloud_RoleName == `"CowManager.Web`" | where not(url == `"`") | extend channelName = tostring(parse_url(url).Host) | distinct user_Id, channelName | summarize count() by channelName'"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Device500 errors"
            psScript                 = "GetPrtgAi_ErrorsDeviceApi.ps1"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        Write-Host("Add-CowManagerAiDevice - ready") -ForegroundColor DarkGray
    }

    $groupName = "{0}-cowmanager" -f $environment
    $group = $parent | Get-Group -name $groupName
    if ($null -eq $group) {
        $parm = New-GroupParameters -Name $groupName
        $group = $parent | Add-Group $parm
    }
    $properties = @{
        Interval = "00:15:00"
        Tags     = "stage-{0},cowmanager" -f $environment
    }
    $group | Set-ObjectProperty @properties

    Add-CowManagerAiDevice -parent $group -environment $environment
}
function Add-ReadModelGroup{
    param(
        $parent,
        [string]$environment
    )
    $mutexName = "readmodel-powershell"

    function Add-ReadModelAiDevice {
        param(
            $parent,
            [string]$environment
        )
        Write-Host("Add-ReadModelAiDevice - started - {0} - {1}" -f $parent.Name, $environment) -ForegroundColor White

        $kvItem = Get-KeyVaultItem -keyName "readmodel" -environment $environment
        $windowsusername = $kvItem.name
        $windowsuserpwd = $kvItem.value

        $deviceName = "{0}-readmodel-ai" -f $environment

        $device = $parent | Get-Device -Name $deviceName
        if ($null -eq $device) {
            $device = $parent | Add-Device -Name $deviceName -Host "127.0.0.1"
        }
        $properties = @{
            WindowsDomain   = $accountnr 
            WindowsUserName = $windowsusername 
            WindowsPassword = $windowsuserpwd 
            Tags            = "applicationinsights" -f $environment
        }
        $device | Set-ObjectProperty @properties

        $kustoqry = @"
requests 
| extend channelName=strcat("[",substring(cloud_RoleName,18,5),"]",name) 
| extend channelType="Count" 
| summarize channelValue=count() by channelName, channelType 
| order by channelType
"@.Replace("`n", "")
        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Requests/topic"
            psScript                 = "GetPrtgAi_QueryV2.ps1"
            exeParameters            = "-timespanminutes 5 -query '{0}'" -f $kustoqry
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $kustoqry = @"
requests 
| extend channelName="Count" 
| extend channelType="Count" 
| summarize channelValue=dcount(cloud_RoleInstance) by channelName, channelType 
| order by channelType
"@.Replace("`n", "")
        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Function instances"
            psScript                 = "GetPrtgAi_QueryV2.ps1"
            exeParameters            = "-timespanminutes 5 -query '{0}' -defaultChannelValue -1" -f $kustoqry
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $kustoqry = @"
requests 
| extend channelName=strcat("[",substring(cloud_RoleName,18,5),"]",name)
| extend channelType="TimeResponse" 
| summarize channelValue=toint(avg(duration)) by channelName, channelType 
| order by channelType
"@.Replace("`n", "")
        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Duration avg"
            psScript                 = "GetPrtgAi_QueryV2.ps1"
            exeParameters            = "-timespanminutes 5 -query '{0}'" -f $kustoqry
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $kustoqry = @"
requests
| order by timestamp desc
| limit 1
| extend channelName="Last log" 
| extend channelType="TimeSeconds" 
| extend channelValue=round((now() - timestamp) / time(1sec),0)
| project channelName, channelType, channelValue
"@.Replace("`n", "")
        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Application Insights Lag"
            psScript                 = "GetPrtgAi_QueryV2.ps1"
            exeParameters            = "-timespanminutes 5 -query '{0}' -defaultChannelValue -1" -f $kustoqry
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        Write-Host("Add-ReadModelAiDevice - ready") -ForegroundColor DarkGray
    }

    function Add-ServiceBusReadModelDevice {
        param(
            $parent,
            [string]$probeEnvironment
        )
        $subscriptionid = Get-KeyVaultKeyValue -keyName "subscriptionid" -environment $probeEnvironment
        $tenantid = Get-KeyVaultKeyValue -keyName "tenantid" -environment $probeEnvironment

        $kvItem = Get-KeyVaultItem -keyName "appregistration" -environment $probeEnvironment
        $applicationid = $kvItem.name
        $applicationsecret = $kvItem.value
        if ("" -eq $applicationid -or 
            "" -eq $applicationsecret -or 
            "" -eq $subscriptionid -or 
            "" -eq $tenantid) {
            Write-Host("Missing essential variables, skipping servicebus-readmodel sensors") -ForegroundColor Red -BackgroundColor White
        }
        else {
            $deviceName = ("{0}-azure-servicebus-readmodel" -f $probeEnvironment)

            $device = $parent | Get-Device -Name $deviceName
            if ($null -eq $device) {
                $device = Add-Device -Destination $parent -Name $deviceName -Host ("{0}\{1}" -f $subscriptionid, $tenantid)
            }
            $properties = @{
                Tags            = "servicebus" -f $probeEnvironment
                WindowsDomain   = $probe.name
                WindowsUserName = $applicationid
                WindowsPassword = $applicationsecret
            }
            $device | Set-ObjectProperty @properties

            $rg = "cm-readmodel-{0}-rg" -f $probeEnvironment
            $ns = "cm-readmodel-{0}-bus" -f $probeEnvironment
            $param = @{
                deviceName               = $deviceName
                sensorName               = "Readmodel"
                psScript                 = "GetPrtgAzureServiceBusMessageCounts.ps1"
                exeParameters            = "-resourcegroup {0} -namespace {1}" -f $rg, $ns
                mutexName                = $mutexName
                usePlaceHolders          = $true
                useWindowsAuthentication = $false
            }
            Set-Sensor @param 
        }
    }

    function Add-MongoDbMonitoring{
        param(
            $parent,
            [string]$environment
        )
        $projectid = Get-KeyVaultKeyValue -keyName "mongo-projectid" -environment $environment
        $clustername = Get-KeyVaultKeyValue -keyName "mongo-clustername" -environment $environment

        $kvItem = Get-KeyVaultItem -keyName "mongo-api-usr" -environment $environment
        $usernm = $kvItem.name
        $apikey = $kvItem.value
        if ("" -eq $projectid -or 
            "" -eq $clustername -or 
            "" -eq $usernm -or 
            "" -eq $apikey) {
            Write-Host("Missing essential variables, skipping mongodb sensors") -ForegroundColor Red -BackgroundColor White
        }
        else {
            $deviceName = ("{0}-mongodb" -f $environment)

            $device = $parent | Get-Device -Name $deviceName
            if ($null -eq $device) {
                $device = Add-Device -Destination $parent -Name $deviceName -Host "127.0.0.1"
            }
            $properties = @{
                Tags            = "mongodb"
                WindowsDomain   = ("{0}\{1}" -f $projectid, $clustername)
                WindowsUserName = $usernm
                WindowsPassword = $apikey
            }
            $device | Set-ObjectProperty @properties

            $param = @{
                device                   = $device
                deviceName               = $deviceName
                sensorName               = "Connection Metrics"
                psScript                 = "GetPrtgRestAtlasMongoProcessMeasurements.ps1"
                mutexName                = $mutexName
                usePlaceHolders          = $true
                useWindowsAuthentication = $false
            }
            Set-Sensor @param 
        }
    }

    function Add-MongoQueryMonitoring {
        param(
            $parent,
            [string]$environment
        )
        $clustername = Get-KeyVaultKeyValue -keyName "mongo-clustername" -environment $environment
        $databasename = Get-KeyVaultKeyValue -keyName "mongo-databasename" -environment $environment

        $kvItem = Get-KeyVaultItem -keyName "mongo-databaseuser" -environment $environment
        $usernm = $kvItem.name
        $userpwd = $kvItem.value
        if ("" -eq $databasename -or 
            "" -eq $clustername -or 
            "" -eq $usernm -or 
            "" -eq $userpwd) {
            Write-Host("Missing essential variables, skipping mongo query sensors") -ForegroundColor Red -BackgroundColor White
        }
        else {
            $deviceName = ("{0}-mongo-query" -f $environment)

            $device = $parent | Get-Device -Name $deviceName
            if ($null -eq $device) {
                $device = Add-Device -Destination $parent -Name $deviceName -Host "127.0.0.1"
            }
            $properties = @{
                Tags            = "mongodb, query"
                WindowsDomain   = ("{0}\{1}" -f $clustername, $databasename)
                WindowsUserName = $usernm
                WindowsPassword = $userpwd
            }
            $device | Set-ObjectProperty @properties

            $param = @{
                device                   = $device
                deviceName               = $deviceName
                sensorName               = "Delay system down alert"
                psScript                 = "GetPrtgMongo_Communcation_Overdue.ps1"
                mutexName                = $mutexName
                usePlaceHolders          = $true
                useWindowsAuthentication = $false
            }
            Set-Sensor @param 
        }
    }

    $groupName = "{0}-readmodel" -f $environment
    $group = $parent | Get-Group -name $groupName
    if ($null -eq $group){
        $parm = New-GroupParameters -Name $groupName
        $group = $parent | Add-Group $parm
    }
    $properties = @{
        Interval = "00:15:00"
        Tags     = "stage-{0},readmodel" -f $environment
    }
    $group | Set-ObjectProperty @properties
    Add-MongoDbMonitoring -parent $group -environment $environment
    Add-MongoQueryMonitoring -parent $group -environment $environment
    Add-ReadModelAiDevice -parent $group -environment $environment
    Add-ServiceBusReadModelDevice -parent $group -probeEnvironment $environment
}

function Add-TimeSeriesGroup{
    param(
        $parent,
        [string]$environment
    )
    function Add-TimeSeriesAiDevice {
        param(
            $parent,
            [string]$environment
        )
        Write-Host("Add-TimeSeriesAiDevice - started - {0} - {1}" -f $parent.Name, $environment) -ForegroundColor White

        $kvItem = Get-KeyVaultItem -keyName "timeseries" -environment $environment
        $windowsusername = $kvItem.name
        $windowsuserpwd = $kvItem.value

        $deviceName = "{0}-timeseries-ai" -f $environment
        $mutexName = "prtg-ai"

        $device = $parent | Get-Device -Name $deviceName
        if ($null -eq $device) {
            $device = $parent | Add-Device -Name $deviceName -Host "127.0.0.1"
        }
        $properties = @{
            WindowsDomain   = $accountnr 
            WindowsUserName = $windowsusername 
            WindowsPassword = $windowsuserpwd 
            Tags            = "applicationinsights" -f $environment
        }
        $device | Set-ObjectProperty @properties

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Timeseries ingress"
            psScript                 = "GetPrtgAi_Timeseries.ps1"
            # exeParameters            = "-timespanminutes 5 -query 'requests | extend rolename = iif(cloud_RoleName has `"CowManager.`", substring(cloud_RoleName,11), cloud_RoleName) | extend server = iif(client_Type == `"PC`", cloud_RoleInstance, client_Type) | extend cntName = strcat(rolename, `" (`",server, `")`") | summarize count() by cntName | order by cntName asc'"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Response times"
            psScript                 = "GetPrtgAi_QueryV2.ps1"
            exeParameters            = "-timespanminutes 5 -query 'requests | extend channelName = cloud_RoleName | extend channelType = `"TimeResponse`" | summarize channelValue=toint(avg(duration)) by channelName, channelType | order by channelName asc'"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        Write-Host("Add-TimeSeriesAiDevice - ready") -ForegroundColor DarkGray
    }
    function Add-ServiceBusDeviceTimeSeries {
        param(
            $parent,
            [string]$probeEnvironment
        )
        $subscriptionid = Get-KeyVaultKeyValue -keyName "subscriptionid" -environment $probeEnvironment
        $tenantid = Get-KeyVaultKeyValue -keyName "tenantid" -environment $probeEnvironment

        $kvItem = Get-KeyVaultItem -keyName "appregistration" -environment $probeEnvironment
        $applicationid = $kvItem.name
        $applicationsecret = $kvItem.value
        if ("" -eq $applicationid -or 
            "" -eq $applicationsecret -or 
            "" -eq $subscriptionid -or 
            "" -eq $tenantid) {
            Write-Host("Missing essential variables, skipping readmodel sensors") -ForegroundColor Red -BackgroundColor White
        }
        else {
            $deviceName = ("{0}-azure-servicebus-timeseries" -f $probeEnvironment)
            $mutexName = "servicebus-powershell"

            $device = Get-Device -Name $deviceName
            if ($null -eq $device) {
                $device = Add-Device -Destination $parent -Name $deviceName -Host ("{0}\{1}" -f $subscriptionid, $tenantid)
            }
            $properties = @{
                WindowsDomain   = $probe.name
                WindowsUserName = $applicationid
                WindowsPassword = $applicationsecret
            }
            $device | Set-ObjectProperty @properties

            $rg = "cm-timeseries-{0}-rg" -f $probeEnvironment
            $ns = "cm-timeseries-{0}-bus" -f $probeEnvironment
            $param = @{
                deviceName               = $deviceName
                sensorName               = "Timeseries"
                psScript                 = "GetPrtgAzureServicebusMessageCounts.ps1"
                exeParameters            = "-resourcegroup {0} -namespace {1}" -f $rg, $ns
                mutexName                = $mutexName
                usePlaceHolders          = $true
                useWindowsAuthentication = $false
            }
            Set-Sensor @param 
        }
    }

    $groupName = "{0}-timeseries" -f $environment
    $group = $parent | Get-Group -name $groupName
    if ($null -eq $group) {
        $parm = New-GroupParameters -Name $groupName
        $group = $parent | Add-Group $parm
    }
    $properties = @{
        Interval = "00:15:00"
        Tags     = "stage-{0},timeseries" -f $environment
    }
    $group | Set-ObjectProperty @properties
    Add-TimeSeriesAiDevice -parent $group -environment $environment
    Add-ServiceBusDeviceTimeSeries -parent $group -probeEnvironment $environment
}

function Add-DeviceEventsGroup {
    param(
        $parent,
        [string]$environment
    )

    function Add-DeviceEventsAiDevice {
        param(
            $parent,
            [string]$environment
        )
        Write-Host("Add-DeviceEventsAiDevice - started - {0} - {1}" -f $parent.Name, $environment) -ForegroundColor White

        $kvItem = Get-KeyVaultKeyValue -keyName "deviceevents-lag-uri" -environment $environment
        # $windowsusername = $kvItem.name
        $uri = $kvItem.value

        $deviceName = "{0}-deviceevents-ai" -f $environment
        $mutexName = "prtg-ai"

        $device = $parent | Get-Device -Name $deviceName
        if ($null -eq $device) {
            $device = $parent | Add-Device -Name $deviceName -Host "127.0.0.1"
        }
        $properties = @{
            # WindowsUserName = $windowsusername 
            # WindowsPassword = $windowsuserpwd 
            Interval = "00:05:00"
            Tags     = "applicationinsights,deviceevents" -f $environment
        }
        $device | Set-ObjectProperty @properties

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Deviceevents lag"
            psScript                 = "GetPrtgDeviceeventsPipelineLag.ps1"
            exeParameters            = "-uri {0}" -f $uri
            mutexName                = $mutexName
            # usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        Write-Host("Add-DeviceEventsAiDevice - ready") -ForegroundColor DarkGray
    }

    function Add-DeviceEventsDwsDevice {
        param(
            $parent,
            [string]$environment
        )
        Write-Host("Add-DeviceEventsDwsDevice - started - {0} - {1}" -f $parent.Name, $environment) -ForegroundColor White

        $value = Get-KeyVaultKeyValue -keyName "deviceevents-dws-token" -environment $environment
        $windowsusername = ""
        $windowsuserpwd = $value

        $deviceName = "{0}-deviceevents-dws" -f $environment
        $mutexName = "prtg-dws"

        $device = $parent | Get-Device -Name $deviceName
        if ($null -eq $device) {
            $device = $parent | Add-Device -Name $deviceName -Host "127.0.0.1"
        }
        $properties = @{
            WindowsUserName = $windowsusername 
            WindowsPassword = $windowsuserpwd 
            Interval = "00:05:00"
            Tags     = "dws,deviceevents" -f $environment
        }
        $device | Set-ObjectProperty @properties

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Databricks job status"
            psScript                 = "GetPrtgDatabricks_JobStatus.ps1"
            exeParameters            = ""
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        Write-Host("Add-DeviceEventsDwsDevice - ready") -ForegroundColor DarkGray
    }

    $groupName = "{0}-deviceevents" -f $environment
    $group = $parent | Get-Group -name $groupName
    if ($null -eq $group) {
        $parm = New-GroupParameters -Name $groupName
        $group = $parent | Add-Group $parm
    }
    $properties = @{
        Interval = "00:15:00"
        Tags     = "deviceevents" -f $environment
    }
    $group | Set-ObjectProperty @properties
    Add-DeviceEventsAiDevice -parent $group -environment $environment
    Add-DeviceEventsDwsDevice -parent $group -environment $environment
}

function Add-SiteToGroup {
    param (
        [string]$basehostName,
        [string]$siteName,
        $parentGroup
    )
    Write-Host("AddSiteToGroup: {1}.{0}" -f $basehostName, $siteName)
    Write-Host("Add-SiteToGroup - started - {0} - {1} - {2}" -f $basehostName, $siteName, $parentGroup.Name) -ForegroundColor White

    $deviceNm = "{1}.{0}" -f $basehostName, $siteName
    $device = Get-Device -ParentId $parentGroup.id -Name $deviceNm
    if ($null -eq $device){
        $device = Add-Device -Name $deviceNm -Destination $parentGroup -Host $deviceNm
    }
    $properties = @{
        Interval = "00:01:00"
        Tags     = "web-{0}" -f $siteName
    }
    $device | Set-ObjectProperty @properties

    if ($siteName -in @("sensor", "farmapi")) {
        $sensorName = "HTTP-Alive"
        $sensor = $device | Get-Sensor -Name $sensorName
        if ($null -eq $sensor) {
            $sensorType = "httpadvanced"
            $parameters = $device | New-SensorParameters -RawType $sensorType
            $parameters.Name = "{0}" -f $sensorName
            $parameters.httpurl = "https://{0}/alive.html?monitor=prtg" -f $deviceNm
            $sensor = $device | Add-Sensor $parameters
        }
    }
    elseif ($siteName -in @("www", "portal")) {
        $sensorName = "HTTP-Alive"
        $sensor = $device | Get-Sensor -Name $sensorName
        if ($null -eq $sensor) {
            $sensorType = "httpadvanced"
            $parameters = $device | New-SensorParameters -RawType $sensorType
            $parameters.Name = "{0}" -f $sensorName
            $parameters.httpurl = "https://{0}/?monitor=prtg" -f $deviceNm
            $sensor = $device | Add-Sensor $parameters
        }
    }

    $sensorName = "SSL Certificate"
    $sensor = $device | Get-Sensor -Name $sensorName
    if ($null -eq $sensor) {
        $sensorType = "sslcertificate"
        $parameters = $device | New-SensorParameters -RawType $sensorType
        $parameters.Name = "{0}" -f $sensorName
        $parameters.sni = "{0}" -f $deviceNm
        $parameters.cncheck = 1
        $sensor = $device | Add-Sensor $parameters
    }

    $sensorName = "SSL Security Check"
    $sensor = $device | Get-Sensor -Name $sensorName
    if ($null -eq $sensor) {
        $sensorType = "ssl"
        $parameters = $device | New-SensorParameters -RawType $sensorType
        $parameters.Name = "{0}" -f $sensorName
        $parameters.sni = "{0}" -f $deviceNm
        $sensor = $device | Add-Sensor $parameters
    }

    Write-Host("Add-SiteToGroup - ready") -ForegroundColor DarkGray
}

function Add-FactoryToGroup{
    param (
        $parentGroup,
        [string]$environment
    )
    Write-Host("Adding factory sensors to host probe - start") -ForegroundColor White

    $factoryDeviceName = "Factory"
    $factoryDevice = $parentGroup | Get-Device -name $factoryDeviceName
    if ($null -eq $factoryDevice){
        $factoryDevice = Add-Device -Name $factoryDeviceName -Host "127.0.0.1" -Destination $parentGroup
    }
    $inputsensors = get-probe -Tags ("stage-{0}" -f $environment) | get-sensor -name "System Health"

    $factorysensorname = "CPU/server"
    $factorysensor = $factorydevice | Get-Sensor -name $factorysensorname
    if ($null -eq $factorysensor) {
        # $factorysensor = $inputsensors | New-Sensor -Factory -Name $factorySensorName { ("{0}" -f ($_.Probe)) } -DestinationId $factoryDevice.Id -ChannelId 1
    }
    $factorysensorname = "Memory/server"
    $factorysensor = $factorydevice | Get-Sensor -name $factorysensorname
    if ($null -eq $factorysensor) {
        # $factorysensor = $inputsensors | New-Sensor -Factory -Name $factorySensorName { ("{0}" -f ($_.Probe)) } -DestinationId $factoryDevice.Id -ChannelId 2
    }

    Write-Host("Adding factory sensors to host probe - ready") -ForegroundColor DarkGray
}

function Add-MLDevice {
    param (
        $probe
    )
    Write-Host("ML-Device to {0}" -f $probe.Name)

    $deviceNm = "ML-Device"
    $device = $probe | Get-Device -Name $deviceNm
    if ($null -eq $device) {
        $device = Add-Device -Name $deviceNm -Destination $probe -Host "127.0.0.1"
    }
    $properties = @{
        Interval = "00:01:00"
        Tags     = "ML"
    }
    $device | Set-ObjectProperty @properties

    $models = @("heatstress", "groupstress", "zero-events")
    foreach($model in $models){
        $sensorName = "{0}-healthy" -f $model
        $sensor = $device | Get-Sensor -Name $sensorName
        if ($null -eq $sensor) {
            # e.g. prtg-ml-model-heatstress-uri-ml
            $keynm = ("ml-model-{0}-uri" -f $model)
            $url = Get-KeyVaultKeyValue -keyName $keynm -environment "ml"
            write-host("Check url: {0}" -f $url)

            $sensorType = "httpadvanced"
            $parameters = $device | New-SensorParameters -RawType $sensorType
            $parameters.Name = "{0}" -f $sensorName
            $parameters.httpurl = $url
            $parameters.httpmustneeded = 1
            $parameters.includemust = "Healthy"
            $sensor = $device | Add-Sensor $parameters
        }
    }
}
function Initialize-HostProbe{
    param (
        [string[]] $environment
    )
    Write-Host("Initialize-HostProbe - start") -ForegroundColor White

    $mainProbe = Get-Probe -id 1
    foreach($env in $environment){
        $grp = Get-Group -Probe $mainProbe -Name $env
        if ($null -eq $grp){
            $parameters = New-GroupParameters -Name $env
            $parameters.Tags = @("stage-{0}" -f $env)
            $grp = $mainProbe | Add-Group $parameters
            if ($env -eq "production") {
                $grp | Set-ObjectProperty -Priority 3
            }
            else {
                $grp | Set-ObjectProperty -Priority 1
            }
        }
        
        $sites = @()
        $basehost = ""
        switch ($env){
            "production" {
                $sites = @("www", "sensor", "farmapi", "portal", "manufactoor", "sensoor", "sensor-01")
                $basehost = "cowmanager.com"
                break
            }
            "sandbox" {
                $sites = @("sensor", "farmapi", "sensoor")
                $basehost = "{0}-cowmanager.com" -f $env
                break
            }
            default {
                $sites = @("sensor", "farmapi", "manufactoor", "sensoor", "sensor-01")
                $basehost = "{0}-cowmanager.com" -f $env
                break
            }
        }
        foreach($site in $sites){
            Add-SiteToGroup -basehostName $basehost -siteName $site -parentGroup $grp
        }
        Add-FactoryToGroup -parentGroup $grp -environment $env
    }

    Add-MLDevice -probe $mainProbe
    Write-Host("Initialize-HostProbe - ready") -ForegroundColor DarkGray
}

function Initialize-ControlledHostProbe {
    param(
        [string] $probeName
    )

    $mutexName = "prtg-generic"
    function Add-AppcenterMSDevice {
        param(
            $parent
        )
        $kvItem = Get-KeyVaultItem -keyName "appcenterms" -environment "generic"
        $windowsusername = $kvItem.name  # owner
        $windowsuserpwd = $kvItem.value  # apikey

        $deviceName = "appcenter-ms"

        $device = $parent | Get-Device -Name $deviceName
        if ($null -eq $device) {
            $device = $parent | Add-Device -Name $deviceName 
        }
        $properties = @{
            Interval        = "00:15:00"
            Tags            = "mobile"
            WindowsUserName = $windowsusername
            WindowsPassword = $windowsuserpwd
        }
        $device | Set-ObjectProperty @properties

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Mobile app crashes and errors"
            psScript                 = "GetPrtgAppCenterMobileErrors.ps1"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 
    }

    function Add-ApplicationInsightsGenericDevice {
        param(
            $parent
        )
        Write-Host("Add-ApplicationInsightsGenericDevice - started") -ForegroundColor White
        $kvItem = Get-KeyVaultItem -keyName "applicationinsights" -environment "generic"
        $windowsusername = $kvItem.name  # owner
        $windowsuserpwd = $kvItem.value # apikey

        $deviceName = "generic-applicationinsights"

        $device = $parent | Get-Device -Name $deviceName
        if ($null -eq $device) {
            $device = $parent | Add-Device -Name $deviceName 
        }
        $properties = @{
            Interval        = "00:15:00"
            Tags            = "applicationinsights" -f $probeEnvironment
            WindowsUserName = $windowsusername 
            WindowsPassword = $windowsuserpwd
        }
        $device | Set-ObjectProperty @properties

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Latency/region"
            psScript                 = "GetPrtgAi_PingResults.ps1"
            mutexName                = $mutexName
            usePlaceHolders          = $true
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        Write-Host("Add-ApplicationInsightsGenericDevice - ready") -ForegroundColor DarkGray
    }

    function Add-LicenseDevice{
        param(
            $parent
        )
        Write-Host("Add-LicenseDevice - started") -ForegroundColor White

        $deviceName = "Licenses"

        $device = $parent | Get-Device -Name $deviceName
        if ($null -eq $device) {
            $device = $parent | Add-Device -Name $deviceName 
        }
        $properties = @{
            Interval        = "12:00:00"
            Tags            = "license"
        }
        $device | Set-ObjectProperty @properties

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "system.mailer-password"
            psScript                 = "CheckLicenseExpiration.ps1"
            mutexName                = $mutexName
            exeParameters            = "-licenseName `system.mailer` -expirationDate `{0:yyyy-MM-dd}` -minimumDaysValid 20" -f (Get-Date)
            usePlaceHolders          = $false
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "NServiceBus"
            psScript                 = "CheckLicenseExpiration.ps1"
            mutexName                = $mutexName
            exeParameters            = "-licenseName `NServiceBus` -expirationDate `{0:yyyy-MM-dd}` -minimumDaysValid 20" -f (Get-Date)
            usePlaceHolders          = $false
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        $param = @{
            device                   = $device
            deviceName               = $deviceName
            sensorName               = "Octopus"
            psScript                 = "CheckLicenseExpiration.ps1"
            mutexName                = $mutexName
            exeParameters            = "-licenseName `Octopus` -expirationDate `{0:yyyy-MM-dd}` -minimumDaysValid 20" -f (Get-Date)
            usePlaceHolders          = $false
            useWindowsAuthentication = $false
        }
        Set-Sensor @param 

        Write-Host("Add-LicenseDevice - ready") -ForegroundColor DarkGray
    }

    Write-Host("Initialize-ControlledHostProbe - start") -ForegroundColor White

    $mainProbe = Get-Probe -Name $probeName
    $grpName = "Generic"
    $grp = $mainProbe | Get-Group -Name $grpName
    if ($null -eq $grp) {
        $parameters = New-GroupParameters -Name $grpName
        $grp = $mainProbe | Add-Group $parameters
    }
    Add-AppCenterMsDevice -parent $grp
    Add-ApplicationInsightsGenericDevice -parent $grp

    $environments = @(
        @{
            name      = "test"
            longname  = "test"
            priority  = 1
            accountnr = "08554"
            agents    = @("cm-app02-test37.westeurope.cloudapp.azure.com:10933", "cm-web01-test37.westeurope.cloudapp.azure.com:10933", "cm-db01-test37.westeurope.cloudapp.azure.com:10933")
        },
        @{
            name      = "beta"
            longname  = "beta"
            priority  = 2
            accountnr = "04519"
            agents    = @("cm-web01-beta.westeurope.cloudapp.azure.com:10933","cm-app01-beta.westeurope.cloudapp.azure.com:10933")
        },
        @{
            name      = "prod"
            longname  = "production"
            priority  = 3
            accountnr = "03122"
            #              agis-app04          agis-db13           agis-web05          agis-web06          agis-web12          agis-web13
            agents    = @("10.30.2.21:10933", "10.30.2.23:10933", "10.30.2.24:10933", "10.30.2.25:10933", "10.30.2.26:10933", "10.30.2.27:10933")
        }
        )
    foreach ($env in $environments) {
        $environment = $env.name
        $accountnr = $env.accountnr

        $grpName = "{0}" -f $environment
        $grp = $mainProbe | Get-Group -Name $grpName
        if ($null -eq $grp) {
            $parameters = New-GroupParameters -Name $grpName
            $parameters.Tags = @("stage-{0},functional" -f $env.longname)
            $grp = $mainProbe | Add-Group $parameters
        }
        $tags = "stage-{0},cowmanager" -f $env.longname
        $interval = "00:01:00"
        $grp | Set-ObjectProperty -Priority $env.priority -Interval $interval -Tags $tags

        Add-CowManagerGroup -parent $grp -environment $environment
        Add-ReadModelGroup -parent $grp -environment $environment
        Add-TimeSeriesGroup -parent $grp -environment $environment
        Add-DeviceEventsGroup -parent $grp -environment $environment

        $grpName = "{0}-functional" -f $environment
        $fugrp = $grp | Get-Group -Name $grpName
        if ($null -eq $fugrp) {
            $parameters = New-GroupParameters -Name $grpName
            $fugrp = $grp | Add-Group $parameters
        }
        $tags = "functional" -f $env.longname
        $interval = "00:01:00"
        $fugrp | Set-ObjectProperty -Priority $env.priority -Interval $interval -Tags $tags

        Add-ManufactoorApiDevice -parent $fugrp -environment $environment
        Add-CowManagerApiDevice -parent $fugrp -environment $environment -accountnr $accountnr
        Add-CowManagerWebDevice -parent $fugrp -environment $environment -accountnr $accountnr
    }
    Write-Host("Initialize-ControlledHostProbe - ready") -ForegroundColor DarkGray
}
#endregion


function AddSensorsToProbe {
    param(
        [Parameter(Mandatory = $true)]
        $probeName,
        [Parameter(Mandatory = $true)]
        $probeEnvironment,
        [Parameter(Mandatory = $true)]
        $probeTypes
    )
    $probe = get-probe -name $probeName
    if ($null -ne $probe){
        $probe | Set-ObjectProperty -Tags ("stage-{0}" -f $probeEnvironment)
    }
    foreach ($type in $probeTypes) {
        Write-host("Adding {1} sensors to {0}" -f $probeName, $type) -ForegroundColor Cyan
        switch ($type) {
            "srv" { 
                AddSrvGenericDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "web" { 
                AddWebDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "msmq" { 
                AddMsmqDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "sql" { 
                AddSqlDevice -probeName $probeName  -probeEnvironment $probeEnvironment
                AddCowDataImportDevice -probeName $probeName  -probeEnvironment $probeEnvironment
                break
            }
            "sqlsys" { 
                AddSqlSysDevice -probeName $probeName -probeEnvironment $probeEnvironment
                AddSrvFactoryDevice -probeName $probeName
                break
            }
            "device-web" { 
                AddDeviceWebDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "device-process" { 
                AddDeviceProcessFileDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "device-sql" { 
                AddSqlDeviceDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "behavior" { 
                AddBehaviorDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "file-upload" { 
                AddFileUploadDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "pushnotification" { 
                AddPushNotificationDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "exportdata" { 
                AddExportDataDevice -probeName $probeName -probeEnvironment $probeEnvironment
                break
            }
            "octochecks" {
                AddConnectivityCheck -probeName $probeName -octopusDeployServer
                break
            }
            default {
                Write-Host("NOT DEFINED")
            }
        }
    }
}

#region main
$timeStart = Get-Date

# AddSensorsToProbe -probeName "cm-web01-sb02" -probeEnvironment "sandbox" -probeTypes ("srv", "web", "msmq", "device-process", "sql", "pushnotification", "device-sql", "behavior", "exportdata")
# AddSensorsToProbe -probeName "cm-db01-sb02" -probeEnvironment "sandbox" -probeTypes ("srv", "sqlsys")
# AddSensorsToProbe -probeName "cm-web01-mnt54" -probeEnvironment "maintenance" -probeTypes ("srv", "web", "msmq", "device-process", "sql", "pushnotification", "device-sql", "behavior", "exportdata")
# AddSensorsToProbe -probeName "cm-db01-mnt54" -probeEnvironment "maintenance" -probeTypes ("srv", "sqlsys")
# AddSensorsToProbe -probeName "cm-web01-test37" -probeEnvironment "test" -probeTypes ("srv", "web", "msmq", "device-process")
# AddSensorsToProbe -probeName "cm-app02-test37" -probeEnvironment "test" -probeTypes ("srv", "msmq", "sql", "pushnotification", "device-sql", "behavior", "exportdata")
# AddSensorsToProbe -probeName "cm-db02-test37" -probeEnvironment "test" -probeTypes ("srv", "sqlsys")
# AddSensorsToProbe -probeName "cm-web01-beta" -probeEnvironment "beta" -probeTypes ("srv", "web", "msmq", "device-process")
# AddSensorsToProbe -probeName "cm-app01-beta" -probeEnvironment "beta" -probeTypes ("srv", "msmq", "sql", "pushnotification", "device-process", "device-sql", "behavior", "exportdata")
# AddSensorsToProbe -probeName "cm-db01-beta" -probeEnvironment "beta" -probeTypes ("srv", "sqlsys")
# AddSensorsToProbe -probeName "agis-man01" -probeEnvironment "devops" -probeTypes ("srv")
# AddSensorsToProbe -probeName "agis-app04" -probeEnvironment "prod" -probeTypes ("srv", "msmq", "file-upload", "sql", "device-sql", "pushnotification", "exportdata", "behavior")
# AddSensorsToProbe -probeName "agis-web05" -probeEnvironment "prod" -probeTypes ("srv", "msmq", "device-process", "device-web")
# AddSensorsToProbe -probeName "agis-web06" -probeEnvironment "prod" -probeTypes ("srv", "msmq", "device-process", "device-web")
# AddSensorsToProbe -probeName "agis-web12" -probeEnvironment "prod" -probeTypes ("srv", "web")
# AddSensorsToProbe -probeName "agis-web13" -probeEnvironment "prod" -probeTypes ("srv", "web")
# AddSensorsToProbe -probeName "agis-db12" -probeEnvironment "prod" -probeTypes ("srv", "sqlsys")
# AddSensorsToProbe -probeName "agis-db13" -probeEnvironment "prod" -probeTypes ("srv", "sqlsys")
# AddSensorsToProbe -probeName "cm-db03" -probeEnvironment "prodsync" -probeTypes ("srv", "sqlsys")
# AddSensorsToProbe -probeName "cm-db01-prd" -probeEnvironment "prod" -probeTypes ("srv", "sqlsys")

# AddSensorsToProbe -probeName "cm-hyperv01" -probeEnvironment "devops" -probeTypes ("srv")
# AddSensorsToProbe -probeName "devsvr02" -probeEnvironment "devops" -probeTypes ("srv")
# AddSensorsToProbe -probeName "buildsvr01" -probeEnvironment "devops" -probeTypes ("srv", "build", "octochecks")
# AddSensorsToProbe -probeName "cm-build02" -probeEnvironment "devops" -probeTypes ("srv", "build")

# Initialize-HostProbe -environment ("production", "beta", "test", "sandbox") #, "maintenance")
Initialize-ControlledHostProbe -probeName "cm-build02"

$a = get-sensor
$a.Count

$timeReady = Get-Date
$ts = New-TimeSpan -Start $timeStart -End $timeReady
Write-Host("Execution took: {0} seconds" -f [Math]::Round($ts.TotalSeconds,0))
#endregion
