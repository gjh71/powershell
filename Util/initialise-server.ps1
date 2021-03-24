$script:logfilepath = Join-Path $env:TEMP -ChildPath ("initialise-server_{0:yyyyMMdd_HHmm}.log" -f (Get-Date))
$script:scriptFolder = if ($PSScriptRoot -eq "") { (Get-Item ".").FullName } else { $PSScriptRoot }

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 #always force using tls1.2

function Write-Log{
    param (
        [Parameter(Mandatory=$true)]
        [string] $logTxt
    )
    $msg = "{0:dd-MM-yyyy HH:mm:ss} [{2}] - {1}" -f (Get-Date), $logTxt, $env:COMPUTERNAME
    Write-Output($msg)
    $msg | Out-File -FilePath $script:logfilepath -Append
}

function Set-RegistryValue{
    param (
        [Parameter(Mandatory=$true)]
        [string] $Path,
        [Parameter(Mandatory=$true)]
        [string] $Name,
        [Parameter(Mandatory=$true)]
        [string] $Value,
        [Parameter(Mandatory=$false)]
        [string] $PropertyType="String"
    )
    Write-Log("Set-RegistryValue - start {0} - {1} = {2}" -f $path, $name, $value)
    if (-not (Test-Path $Path)) {
        $createPath = "HKLM:"
        $pathParts = $path.substring($createPath.Length).Split("\")
        foreach($part in $pathParts){
                $createPath = -join($createPath, "\", $part)
                if (-not (Test-Path $createPath)) {
                    Write-Log("Creating registrypath: {0}" -f $createPath)
                    New-Item $createPath | Out-Null
                }
        }
    }
    $args = @{
        Path = $Path
        Name = $Name
        PropertyType = $PropertyType
        Value = $Value
    }
    New-ItemProperty -Force @args | Out-Null

    Write-Log("Set-RegistryValue - ready")
}

function Install-DotNetFramework {
    Write-Log("Install-DotNetFramework - start")
    choco install -y netfx-4.8
    Write-Log("Install-DotNetFramework - ready")
}

function Install-StandardServerSoftware {
    Write-Log("Install-StandardServerSoftware - start")
    choco install -y microsoftazurestorageexplorer, windirstat, azcopy, notepadplusplus, iiscrypto, iiscrypto-cli
    Write-Log("Install-StandardServerSoftware - ready")
}

function Install-PerformanceCounters {
    Write-Log("Install-PerformanceCounters - start")

    # As Performance counters are not correctly initialised in prtg, skip deletion
    # The script as below works ok, when called from cmd-line
    #[System.Diagnostics.PerformanceCounterCategory]::DELETE("KafkaErrorSuccessCounter")
    #[System.Diagnostics.PerformanceCounterCategory]::DELETE("GroupAlerts")
    #[System.Diagnostics.PerformanceCounterCategory]::DELETE("CowAlerts")

    #region perfcounters-kafka
    $categoryName = "KafkaErrorSuccessCounter"
    $categoryHelp = "Kafka performance counters"
    $categoryType = [System.Diagnostics.PerformanceCounterCategoryType]::MultiInstance

    $categoryExists = [System.Diagnostics.PerformanceCounterCategory]::Exists($categoryName)
    Write-Host("Install-PerformanceCounters: Start {0}" -f $categoryName)
    If (-Not $categoryExists) {
        $objCCDC = New-Object System.Diagnostics.CounterCreationDataCollection
  
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "KafkaSuccessCounterDelta"
        #$objCCD.CounterType = "CounterDelta64"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number succesfull delivered msg to kafka"
        $objCCDC.Add($objCCD) | Out-Null
  
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "KafkaErrorCounterDelta"
        #$objCCD.CounterType = "CounterDelta64"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Failed number of msg to kafka"
        $objCCDC.Add($objCCD) | Out-Null

        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "KafkaSkippedCounterDelta"
        #$objCCD.CounterType = "CounterDelta64"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Skipped number of batches to kafka"
        $objCCDC.Add($objCCD) | Out-Null
  
        [System.Diagnostics.PerformanceCounterCategory]::Create($categoryName, $categoryHelp, $categoryType, $objCCDC) | Out-Null
    }
    $performanceCounterInstance = "cm-cluster"
    $pcSucces = New-Object System.Diagnostics.PerformanceCounter($categoryName, "KafkaSuccessCounterDelta", $performanceCounterInstance, $false)
    $pcError = New-Object System.Diagnostics.PerformanceCounter($categoryName, "KafkaErrorCounterDelta", $performanceCounterInstance, $false)
    $pcSkipped = New-Object System.Diagnostics.PerformanceCounter($categoryName, "KafkaSkippedCounterDelta", $performanceCounterInstance, $false)

    $pcSucces.RawValue = 0
    $pcError.RawValue = 0
    $pcSkipped.RawValue = 0
    start-sleep 1
    $pcSucces.RawValue = 10
    $pcError.RawValue = 2
    $pcSkipped.RawValue = 1
    start-sleep 1
    $pcSucces.RawValue = 200
    $pcError.RawValue = 4
    $pcSkipped.RawValue = 5
    start-sleep 1
    Write-Host("Install-PerformanceCounters: Done {0}" -f $categoryName)
    #endregion

    #region perfcounters-groupalerts
    $categoryName = "GroupAlerts"
    $categoryHelp = "Group alerts performance counters"
    $categoryType = [System.Diagnostics.PerformanceCounterCategoryType]::MultiInstance
    $categoryExists = [System.Diagnostics.PerformanceCounterCategory]::Exists($categoryName)
    Write-Host("Install-PerformanceCounters: Start {0}" -f $categoryName)
    If ($categoryExists) {
        Write-Host("Install-PerformanceCounters: Category {0} exists" -f $categoryName)
    }
    else {
        Write-Host("Install-PerformanceCounters: Adding category {0}" -f $categoryName)
        $objCCDC = New-Object System.Diagnostics.CounterCreationDataCollection
  
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "ErrorsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of errors encounters in running the job"
        $objCCDC.Add($objCCD) | Out-Null

        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "GroupHourMeasuresRetrievedCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of group hour measures retrieved from the database"
        $objCCDC.Add($objCCD)
  
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "GroupAlertsBatchDurationCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Duration counter of the group alerts batch"
        $objCCDC.Add($objCCD)
        
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "UpdatedGroupAlertsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of group alerts updated in the database"
        $objCCDC.Add($objCCD) 
        
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "SuspiciousOrHeatstressAlertsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of group alerts (heat stress) retrieved from the webs service"
        $objCCDC.Add($objCCD) 
		
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "ZeroEventAlertsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of group alerts (low feeding) retrieved from the web service"
        $objCCDC.Add($objCCD) 

        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "IncreasedActivityAlertsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of group alerts (increased activity) retrieved from the web service"
        $objCCDC.Add($objCCD) 
		
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "IncreasedInactivityAlertsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of group alerts (increased inactivity) retrieved from the web service"
        $objCCDC.Add($objCCD) 

        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "GroupStressAlertsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of group alerts (group stress) retrieved from the web service"
        $objCCDC.Add($objCCD) 
		
        [System.Diagnostics.PerformanceCounterCategory]::Create($categoryName, $categoryHelp, $categoryType, $objCCDC) 
        
        $performanceCounterInstance = $categoryName
        $pc0 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "ErrorsCounter", $performanceCounterInstance, $false)
        $pc1 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "GroupHourMeasuresRetrievedCounter", $performanceCounterInstance, $false)
        $pc2 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "GroupAlertsBatchDurationCounter", $performanceCounterInstance, $false)
        $pc3 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "UpdatedGroupAlertsCounter", $performanceCounterInstance, $false)
        $pc4 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "SuspiciousOrHeatstressAlertsCounter", $performanceCounterInstance, $false)
        $pc5 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "ZeroEventAlertsCounter", $performanceCounterInstance, $false)
        $pc6 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "IncreasedActivityAlertsCounter", $performanceCounterInstance, $false)
        $pc7 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "IncreasedInactivityAlertsCounter", $performanceCounterInstance, $false)
        $pc8 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "GroupStressAlertsCounter", $performanceCounterInstance, $false)
        $pc0.RawValue = 0
        $pc1.RawValue = 0
        $pc2.RawValue = 0
        $pc3.RawValue = 0
        $pc4.RawValue = 0
        $pc5.RawValue = 0
        $pc6.RawValue = 0
        $pc7.RawValue = 0
        $pc8.RawValue = 0
    }
    Write-Host("Install-PerformanceCounters: Done {0}" -f $categoryName)
    #endregion

    #region perfcounters-cowalerts
    $categoryName = "CowAlerts"
    $categoryHelp = "Cow alerts performance counters"
    $categoryType = [System.Diagnostics.PerformanceCounterCategoryType]::MultiInstance
    $categoryExists = [System.Diagnostics.PerformanceCounterCategory]::Exists($categoryName)
    Write-Host("Install-PerformanceCounters: Start {0}" -f $categoryName)
    If ($categoryExists) {
        Write-Host("Install-PerformanceCounters: Category {0} exists" -f $categoryName)
    }
    else {
        Write-Host("Install-PerformanceCounters: Adding category {0}" -f $categoryName)
        $objCCDC = New-Object System.Diagnostics.CounterCreationDataCollection
  
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "ErrorsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of errors encounters in running the job"
        $objCCDC.Add($objCCD) | Out-Null

        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "CowDayBehaviorsRetrievedCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of cow day measures retrieved from the database"
        $objCCDC.Add($objCCD)
  
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "CowAlertsBatchDurationCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Duration counter of the cow alerts batch"
        $objCCDC.Add($objCCD)
        
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "UpdatedCowAlertsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of cow alerts updated in the database"
        $objCCDC.Add($objCCD) 
        
        $objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "AtRiskAlertsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of cow alerts (at risk) retrieved from the webs service"
        $objCCDC.Add($objCCD) 
		
		$objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "CowHourMeasuresRetrievedCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of cowhorumeasures retrieved from the database"
        $objCCDC.Add($objCCD) 
		
		$objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "V2HealthAlertsBatchDurationCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Duration counter of the cow V2HealthAlerts batch"
        $objCCDC.Add($objCCD) 
		
		$objCCD = New-Object System.Diagnostics.CounterCreationData
        $objCCD.CounterName = "V2HealthAlertsCounter"
        $objCCD.CounterType = "NumberOfItems64"
        $objCCD.CounterHelp = "Number of cow alerts merged in the database"
        $objCCDC.Add($objCCD) 
		
        [System.Diagnostics.PerformanceCounterCategory]::Create($categoryName, $categoryHelp, $categoryType, $objCCDC) 
        
        $performanceCounterInstance = $categoryName
        $pc0 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "ErrorsCounter", $performanceCounterInstance, $false)
        $pc1 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "CowDayBehaviorsRetrievedCounter", $performanceCounterInstance, $false)
        $pc2 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "CowAlertsBatchDurationCounter", $performanceCounterInstance, $false)
        $pc3 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "UpdatedCowAlertsCounter", $performanceCounterInstance, $false)
        $pc4 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "AtRiskAlertsCounter", $performanceCounterInstance, $false)
		$pc5 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "CowHourMeasuresRetrievedCounter", $performanceCounterInstance, $false)
		$pc6 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "V2HealthAlertsBatchDurationCounter", $performanceCounterInstance, $false)
		$pc7 = New-Object System.Diagnostics.PerformanceCounter($categoryName, "V2HealthAlertsCounter", $performanceCounterInstance, $false)
        $pc0.RawValue = 0
        $pc1.RawValue = 0
        $pc2.RawValue = 0
        $pc3.RawValue = 0
        $pc4.RawValue = 0
		$pc5.RawValue = 0
		$pc6.RawValue = 0
		$pc7.RawValue = 0
    }
    Write-Host("Install-PerformanceCounters: Done {0}" -f $categoryName)
    #endregion

    Write-Log("Install-PerformanceCounters - ready")
}

function Add-DefenderExclusions{
    param (
        [Parameter(Mandatory=$true)]
        [string[]] $excludeFolders
    )
    Write-Log("Add-DefenderExclusions - start")
    $defExclusionPaths = (Get-MpPreference).ExclusionPath
    foreach($fld in $excludeFolders){
        if ($fld -notin $defExclusionPaths){
            Add-MpPreference -ExclusionPath $fld
            Write-Log("Add-DefenderExclusions - Added {0} as DefenderExclusion" -f $fld)
        }
        else {
            Write-Log("Add-DefenderExclusions - {0} Already a defenderExclusion" -f $fld)
        }
    }
    Write-Log("Add-DefenderExclusions - ready")
}

function Get-Cm3rdPartyDownloads {
    Write-Log("Get-Cm3rdPartyDownloads - start")
    $downloadList = @(
        @{name = "FirstResponderKit.zip"; uri = "http://public.brentozar.com/FirstResponderKit.zip" },
        ""
    )

    $downloadFolder = Join-Path $script:scriptFolder -ChildPath "download"
    if ($false -eq (Test-Path $downloadFolder)) {
        New-Item $downloadFolder -ItemType Directory | Out-Null
    }

    foreach ($download in $downloadList) {
        if ($download.name -ne "") {
            $downloadTarget = Join-Path $downloadFolder -ChildPath $download.name
            if (Test-Path $downloadTarget) {
                Write-Log("Already downloaded {0}. Skip." -f $downloadTarget)
            }
            else {
                Write-Log("Downloading {0} from {1}" -f $downloadTarget, $download.uri)
                Invoke-WebRequest -Uri $download.uri -OutFile $downloadTarget
            }
        }
    }
    Write-Log("Get-Cm3rdPartyDownloads - ready")
}

function Install-OctopusClient {
    Write-Log("Install-OctopusClient - start")

    choco install -y octopusdeploy.tentacle

    $tentaclePath = "C:\Program Files\Octopus Deploy\Tentacle\Tentacle.exe"
    if (!(Test-Path $tentaclePath)){
        Write-Log("Install-OctopusClient - Tentacle not found")
    }
    else {
        # NB: if environment variable 'TEMP' is not forced like this, the service uses 'C:\windows\system32\config\systemprofile\AppData\Local\Temp'
        # and then failes to install...
        if ((Test-Path $env:TEMP) -eq $false){
            Write-Log("Install-OctopusClient - {0} not found, now creating" -f $env:TEMP)
            $newFld = New-Item -Path $env:TEMP -ItemType Directory
            Write-Log("Install-OctopusClient - {0} created" -f $newFld.FullName)
        }
        $env:TEMP = "C:\Windows\Temp"
        Write-Log("Install-OctopusClient - Tentacle CreateInstance")
        . $tentaclePath create-instance --instance "Tentacle" --config "C:\Octopus\Tentacle.config"
        Write-Log("Install-OctopusClient - Tentacle NewCertificate")
        . $tentaclePath new-certificate --instance "Tentacle" --if-blank
        Write-Log("Install-OctopusClient - Tentacle resettrust")
        . $tentaclePath configure --instance "Tentacle" --reset-trust
        Write-Log("Install-OctopusClient - Tentacle setapp")
        . $tentaclePath configure --instance "Tentacle" --app "C:\Octopus\Applications" --port "10933" --noListen "False"
        Write-Log("Install-OctopusClient - Tentacle settrust")
        . $tentaclePath configure --instance "Tentacle" --trust "FFB48BB190C2DD17756E4A97E3F3F4148D83930D"
    
        $rule = Get-NetFirewallRule | Where-Object { $_.Name -eq 'OctopusDeployTentacle' }
        if (! $rule) {
            Write-Log("Install-OctopusClient - Add FW rule")
            New-NetFirewallRule -Name 'OctopusDeployTentacle' -DisplayName 'Octopus Deploy Tentacle' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 10933
        }
        Write-Log("Install-OctopusClient - Tentacle install")
        . $tentaclePath service --instance "Tentacle" --install --stop --start

        # Clean up temp-hack
        Write-Log("Install-OctopusClient - Restore temp to orgvalue: {0} (current: {1})" -f $orgTemp, $env:TEMP)
        $env:TEMP = $orgTemp
    }

    Write-Log("Install-OctopusClient - ready")
}

function Set-ServiceStartupType{
    param (
        [Parameter(Mandatory=$true)]
        [string]$serviceName,
        [Parameter(Mandatory=$true)]
        [string]$startupType
    )
    Write-Log("Set-ServiceStartupType - start")
    $service = Get-Service $serviceName
    if ($null -eq $service){
        Write-Log("Set-ServiceStartupType - Service {0} - not found" -f $serviceName)
    }
    else {
        $currentStarttype = [string]$service.StartType
        if ($currentStarttype -eq $startupType){
            Write-Log("Set-ServiceStartupType - starttype already: {0}" -f $startupType)
        }
        else {
            $service | Set-Service -StartupType $startupType
            Write-Log("Set-ServiceStartupType - Starttype of service {0} changed from {1} into {2}" -f $serviceName, $currentStarttype, $startupType)
        }
    }
    Write-Log("Set-ServiceStartupType - ready")
}

function Set-ServerGenericSettings{
    Write-Log("Set-ServerGenericSettings - start")

    Write-Log("Set-ServerGenericSettings - set UAC to true")
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 2 -PropertyType "Dword"
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 1 -PropertyType "Dword"
    Write-Log("Set-ServerGenericSettings - UAC enabled")

    Write-Log("Set-ServerGenericSettings - Check Scheduled task history")
    $logName = 'Microsoft-Windows-TaskScheduler/Operational'
    $log = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration $logName
    if ($log.IsEnabled -eq $false){
        $log.IsEnabled=$true
        $log.SaveChanges()
        Write-Log("Set-ServerGenericSettings - Scheduled task history set to active")
    }
    else {
        Write-Log("Set-ServerGenericSettings - Scheduled task history already active")
    }
    Write-Log("Set-ServerGenericSettings - ready")
}

function Connect-DisksFromStorage {
    param(
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [int]
        $diskNumber,
        [Parameter(Mandatory = $true)]
        [string]
        $driveLetter,
        [Parameter(Mandatory = $true)]
        [string]
        $driveDescription
    )
    Write-Log("Connect-DisksFromStorage {0}, {1}, {2} - start" -f $diskNumber, $driveLetter, $driveDescription)

    $disk = Get-Disk | Where-Object { $_.Number -eq $diskNumber }

    if ($disk -and $disk.PartitionStyle -eq "RAW") {
        Write-Log("Connect-DisksFromStorage - Adding Disk")
        # dirty, but we want to prevent pop-ups...
        Stop-Service -Name ShellHWDetection
        $disk | Initialize-Disk -PartitionStyle GPT
        $partition = $disk | New-Partition -UseMaximumSize -DriveLetter $driveLetter
        Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel $driveDescription -Confirm:$false -Force
        Start-Service -Name ShellHWDetection
    }
    else {
        Write-Log("Connect-DisksFromStorage - Disks already initialised")
    }
    Write-Log("Connect-DisksFromStorage - ready")
}

function Install-MsDtc {
    Write-Log("Install-MsDtc - start")
    Test-Dtc -LocalComputerName $env:COMPUTERNAME
    $dtcFirewallRulesToEnable = Get-NetFirewallRule | Where-Object { $_.DisplayName -like "Distributed*" }

    #now fix
    Set-DtcNetworkSetting -InboundTransactionsEnabled 1 -OutboundTransactionsEnabled 1 -XATransactionsEnabled 1 -LUTransactionsEnabled 0 -AuthenticationLevel NoAuth -Confirm:$false
    $dtcFirewallRulesToEnable | Enable-NetFirewallRule

    Test-Dtc -LocalComputerName $env:COMPUTERNAME
    
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Rpc\Internet' -Name "Ports" -Value "5000-5200" -PropertyType "MultiString"
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Rpc\Internet' -Name "UseInternetPorts" -Value "Y"
    Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Rpc\Internet' -Name "PortsInternetAvailable" -Value "Y"

    # to do: port-range for msdtc 5000-5200
    #$dtcFirewallRulesToEnable = Get-NetFirewallRule | Where-Object {$_.DisplayName -like "Distributed*"}
    Write-Log("Install-MsDtc - ready")

}

function Set-MsmqStorageLocation {
    param(
        # New location of msmq storage
        [Parameter(Mandatory = $true)]
        [string]
        $msmqStorageLocation
    )
    Write-Log("Set-MsMqStorageLocation - start")

    # https://blogs.msdn.microsoft.com/johnbreakwell/2009/02/09/changing-the-msmq-storage-location/
    Write-Log "NOT DONE: ONE SHOULD DO THIS MANUALLY!!!"

    Write-Log("Set-MsMqStorageLocation - ready")
}

function Set-DatabusDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Location,
        [Parameter(Mandatory = $true)]
        [string] $environmentname
    )
    Write-Log("Set-DatabusDirectory - start")
    <#
    if (!(Test-Path $Location)) {
        New-Item -Path $Location -ItemType Directory
    }
    $share = Get-SmbShare -Name "Databus" -ErrorAction Ignore
    if ($share) {
        Write-Log ("Databus-share already created")
    }
    else {
        Write-Log ("Share created, but after deployment of process-services USER cm.process.$environmentname needs to be granted FULL access")
        $share = New-SmbShare -Path $Location -Name "Databus" -ReadAccess "Everyone"
    }
    #>
    Write-Log("Set-DatabusDirectory - ready")
}

function Set-SqlClientAlias {
    # http://blog.nethouse.se/2015/05/16/avoid-connection-string-transforms-with-sql-client-alias/
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Alias,
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$Instance,
        [Parameter(Position = 2, Mandatory = $false)]
        [int]$Port = -1
    )
    Write-Log("Set-SqlClientAlias - start")
 
    $x86Path = "HKLM:\Software\Microsoft\MSSQLServer\Client\ConnectTo"
    $x64Path = "HKLM:\Software\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo"
    $Value = "DBMSSOCN,$Instance" # DBMSSOCN => TCP/IP
    if ($Port -ne -1) {
        $Value += ",$Port"
    }
 
    Set-RegistryValue -Path $x86Path -Name $Alias -Value $Value
    Set-RegistryValue -Path $x64Path -Name $Alias -Value $Value
    Write-Log("Set-SqlClientAlias - ready")
}
function Install-Redis {
    Write-Log("Install-Redis - start")

    $service = Get-Service Redis -ErrorAction Ignore
    if ($service -and $service.Status -eq "Running") {
        Write-Log("## Redis already installed and running ##")
    }
    else {
        Write-Log("Install-Redis - choco install")
        choco install -y redis-64 

        Write-Log("Install-Redis - configuring")
        Push-Location C:\ProgramData\chocolatey\lib\redis-64
        $redisLogLocation = "S:\Log\Redis"
        if (!(Test-Path $redisLogLocation)) {
            New-Item -Path $redisLogLocation -ItemType Directory
        }
        $configFile = Get-Item -Path "redis.windows-service.conf"
        $fileContent = Get-Content $configFile.FullName
        $find = "Logs/redis_log.txt"
        $replace = "{0}/redis_log.txt" -f ($redisLogLocation.Replace("\", "/"))
            
        ($fileContent -replace $find, $replace) | Set-Content -Path $configFile.FullName
        Write-Log("Install-Redis - install-as-service, config: {0}" -f $configFile.FullName)
        . redis-server.exe --service-install $configFile.FullName
        Write-Log("Install-Redis - start the service")
        . redis-server.exe --service-start
        Pop-Location
    }
    Write-Log("Install-Redis - ready")
}

function Install-SqlSysClrTypes {
    Write-Log("Install-SqlSysClrTypes - start")
    choco install -y sql2016-clrtypes
    Write-Log("Install-SqlSysClrTypes - ready")
}

function Install-NServiceBus {
    Write-Log("Install-NServiceBus - start")
    $modulezip = "NServiceBus.PowerShell.zip"
    if (!(Test-Path $modulezip)){
        Write-Log("*** Install-NServiceBus - {0} not found" -f $modulezip)
    }
    else {
        Expand-Archive -Path $modulezip -DestinationPath "C:\Program Files\WindowsPowerShell\Modules"
        Import-Module NServiceBus.PowerShell
    
        Install-NServiceBusDTC
        Install-NServiceBusMSMQ
        Install-NServiceBusPerformanceCounters
    
        $result = Test-NServiceBusDTCInstallation
        Write-Log("Install-NServiceBus - {0}" -f $result.message)
        $result = Test-NServiceBusMSMQInstallation
        Write-Log("Install-NServiceBus - {0}" -f $result.message)
        $result = Test-NServiceBusPerformanceCountersInstallation
        Write-Log("Install-NServiceBus - {0}" -f $result.message)
    }

    Write-Log("Install-NServiceBus - ready")
}

function Install-Modules {
    param (
        [Parameter()]
        [string] $moduleList
    )
    Write-Log("Install-Modules - start")
    $nuGetProvider = Get-PackageProvider | Where-Object {$_.name -eq "NuGet"}
    if ($null -eq $nuGetProvider){
        Write-Log("Install-Modules - Install NuGetProvider")
        Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.201" -Force
    }
    $modules = $moduleList.Split(";")
    foreach ($module in $modules) {
        if (Get-Module -ListAvailable -Name $module) {
            Write-Log ("{0} Module already installed; skip installation" -f $module)
        }
        else {
            Write-Log ("Installing module: {0}" -f $module)
            Find-Module $module | Install-Module -AllowClobber -Force -Confirm:$false -Verbose
        }
        Import-Module $module
    }
    Write-Log("Install-Modules - ready")
}

function Install-Features {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $featuresToInstall,
        [string[]] $featuresToUninstall
    )
    Write-Log("Install-Features - start")
    Import-Module ServerManager
    $installFeaturesCmd = "install-windowsfeature {0} " -f ($featuresToInstall -join ",")
    Write-Log("Invoking command - installing features: `n{0}" -f $installFeaturesCmd)
    Invoke-Expression $installFeaturesCmd
    $installFeaturesCmd = "uninstall-windowsfeature {0} " -f ($featuresToUninstall -join ",")
    Write-Log("Invoking command - uninstalling features: `n{0}" -f $installFeaturesCmd)
    Invoke-Expression $installFeaturesCmd
    Write-Log("Install-Features - ready")
}

function Add-LoginToLocalPrivilege {
    <#
.SYNOPSIS
Adds the provided login to the local security privilege that is chosen. Must be run as Administrator in UAC mode.
Returns a boolean $true if it was successful, $false if it was not.

.DESCRIPTION
Uses the built in secedit.exe to export the current configuration then re-import
the new configuration with the provided login added to the appropriate privilege.

The pipeline object must be passed in a DOMAIN\User format as string.

This function supports the -WhatIf, -Confirm, and -Verbose switches.

.PARAMETER DomainAccount
Value passed as a DOMAIN\Account format.

.PARAMETER Domain 
Domain of the account - can be local account by specifying local computer name.
Must be used in conjunction with Account.

.PARAMETER Account
Username of the account you want added to that privilege
Must be used in conjunction with Domain

.PARAMETER Privilege
The name of the privilege you want to be added.

This must be one in the following list:
SeManageVolumePrivilege
SeLockMemoryPrivilege

.PARAMETER TemporaryFolderPath
The folder path where the secedit exports and imports will reside. 

The default if this parameter is not provided is $env:USERPROFILE

.EXAMPLE
Add-LoginToLocalPrivilege -Domain "NEIER" -Account "Kyle" -Privilege "SeManageVolumePrivilege"

Using full parameter names

.EXAMPLE
Add-LoginToLocalPrivilege "NEIER\Kyle" "SeLockMemoryPrivilege"

Using Positional parameters only allowed when passing DomainAccount together, not independently.

.EXAMPLE
Add-LoginToLocalPrivilege "NEIER\Kyle" "SeLockMemoryPrivilege" -Verbose

This function supports the verbose switch. Will provide to you several 
text cues as part of the execution to the console. Will not output the text, only presents to console.

.EXAMPLE
("NEIER\Kyle", "NEIER\Stephanie") | Add-LoginToLocalPrivilege -Privilege "SeManageVolumePrivilege" -Verbose

Passing array of DOMAIN\User as pipeline parameter with -v switch for verbose logging. Only "Domain\Account"
can be passed through pipeline. You cannot use the Domain and Account parameters when using the pipeline.

.NOTES
The temporary files should be removed at the end of the script. 

If there is error - two files may remain in the $TemporaryFolderPath (default $env:USERPFORILE)
UserRightsAsTheyExist.inf
ApplyUserRights.inf

These should be deleted if they exist, but will be overwritten if this is run again.

Author:    Kyle Neier
Blog: http://sqldbamusings.blogspot.com
Twitter: Kyle_Neier
#>

    #Specify the default parameterset
    [CmdletBinding(DefaultParametersetName = "JointNames", SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param
    (
        [parameter(
            Mandatory = $true, 
            Position = 0,
            ParameterSetName = "SplitNames")]
        [string] $Domain,

        [parameter(
            Mandatory = $true, 
            Position = 1,
            ParameterSetName = "SplitNames"
        )]
        [string] $Account,

        [parameter(
            Mandatory = $true, 
            Position = 0,
            ParameterSetName = "JointNames",
            ValueFromPipeline = $true
        )]
        [string] $DomainAccount,

        [parameter(Mandatory = $true, Position = 2)]
        [ValidateSet("SeManageVolumePrivilege", "SeLockMemoryPrivilege")]
        [string] $Privilege,

        [parameter(Mandatory = $false, Position = 3)]
        [string] $TemporaryFolderPath = $env:USERPROFILE
        
    )

    #Determine which parameter set was used
    switch ($PsCmdlet.ParameterSetName) {
        "SplitNames" { 
            #If SplitNames was used, combine the names into a single string
            Write-Verbose "Domain and Account provided - combining for rest of script."
            $DomainAccount = "$Domain`\$Account"
        }
        "JointNames" {
            Write-Verbose "Domain\Account combination provided."
            #Need to do nothing more, the parameter passed is sufficient.
        }
    }

    #Created simple function here so I didn't have to re-type these commands
    function Remove-TempFiles {
        #Evaluate whether the ApplyUserRights.inf file exists
        if (Test-Path $TemporaryFolderPath\ApplyUserRights.inf) {
            #Remove it if it does.
            Write-Verbose "Removing $TemporaryFolderPath`\ApplyUserRights.inf"
            Remove-Item $TemporaryFolderPath\ApplyUserRights.inf -Force -WhatIf:$false
        }

        #Evaluate whether the UserRightsAsTheyExists.inf file exists
        if (Test-Path $TemporaryFolderPath\UserRightsAsTheyExist.inf) {
            #Remove it if it does.
            Write-Verbose "Removing $TemporaryFolderPath\UserRightsAsTheyExist.inf"
            Remove-Item $TemporaryFolderPath\UserRightsAsTheyExist.inf -Force -WhatIf:$false
        }
    }

    Write-Verbose "Adding $DomainAccount to $Privilege"

    Write-Verbose "Verifying that export file does not exist."
    #Clean Up any files that may be hanging around.
    Remove-TempFiles
    
    Write-Verbose "Executing secedit and sending to $TemporaryFolderPath"
    #Use secedit (built in command in windows) to export current User Rights Assignment
    $SeceditResults = secedit /export /areas USER_RIGHTS /cfg $TemporaryFolderPath\UserRightsAsTheyExist.inf

    #Make certain export was successful
    if ($SeceditResults[$SeceditResults.Count - 2] -eq "The task has completed successfully.") {

        Write-Verbose "Secedit export was successful, proceeding to re-import"
        #Save out the header of the file to be imported
        
        Write-Verbose "Save out header for $TemporaryFolderPath`\ApplyUserRights.inf"
        
        "[Unicode]
Unicode=yes
[Version]
signature=`"`$CHICAGO`$`"
Revision=1
[Privilege Rights]" | Out-File $TemporaryFolderPath\ApplyUserRights.inf -Force -WhatIf:$false
                                    
        #Bring the exported config file in as an array
        Write-Verbose "Importing the exported secedit file."
        $SecurityPolicyExport = Get-Content $TemporaryFolderPath\UserRightsAsTheyExist.inf

        #enumerate over each of these files, looking for the Perform Volume Maintenance Tasks privilege
        [Boolean]$isFound = $false
        foreach ($line in $SecurityPolicyExport) {
            if ($line -like "$Privilege`*") {
                Write-Verbose "Line with the $Privilege found in export, appending $DomainAccount to it"
                #Add the current domain\user to the list
                $line = $line + ",$DomainAccount"
                #output line, with all old + new accounts to re-import
                $line | Out-File $TemporaryFolderPath\ApplyUserRights.inf -Append -WhatIf:$false
                            
                $isFound = $true
            }
        }

        if ($isFound -eq $false) {
            #If the particular command we are looking for can't be found, create it to be imported.
            Write-Verbose "No line found for $Privilege - Adding new line for $DomainAccount"
            "$Privilege`=$DomainAccount" | Out-File $TemporaryFolderPath\ApplyUserRights.inf -Append -WhatIf:$false
        }

        #Import the new .inf into the local security policy.
        if ($pscmdlet.ShouldProcess($DomainAccount, "Account be added to Local Security with $Privilege privilege?")) {
            # yes, Run the import:
            Write-Verbose "Importing $TemporaryfolderPath\ApplyUserRighs.inf"
            $SeceditApplyResults = SECEDIT /configure /db secedit.sdb /cfg $TemporaryFolderPath\ApplyUserRights.inf

            #Verify that update was successful (string reading, blegh.)
            if ($SeceditApplyResults[$SeceditApplyResults.Count - 2] -eq "The task has completed successfully.") {
                #Success, return true
                Write-Verbose "Import was successful."
                Write-Output $true
            }
            else {
                #Import failed for some reason
                Write-Verbose "Import from $TemporaryFolderPath\ApplyUserRights.inf failed."
                Write-Output $false
                Write-Error -Message "The import from$TemporaryFolderPath\ApplyUserRights using secedit failed. Full Text Below:
$SeceditApplyResults)"
            }
        }
    }
    else {
        #Export failed for some reason.
        Write-Verbose "Export to $TemporaryFolderPath\UserRightsAsTheyExist.inf failed."
        Write-Output $false
        Write-Error -Message "The export to $TemporaryFolderPath\UserRightsAsTheyExist.inf from secedit failed. Full Text Below:
$SeceditResults)"
        
    }
    Write-Verbose "Cleaning up temporary files that were created."
    #Delete the two temp files we created.
    Remove-TempFiles
}
function Initialize-SqlScripts {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential] $sqlCredentials
    )
    Write-Log("Initialize-SqlScripts - start")
    $firstResponderKit = Join-Path $script:scriptFolder -ChildPath "download\FirstResponderKit"
    if (-not (Test-Path $firstResponderKit)){
        Write-Log("Initialize-SqlScripts - {0} - extract" -f $firstResponderKit)
        Expand-Archive -Path ("{0}.zip" -f $firstResponderKit) -DestinationPath $firstResponderKit
    }
    else {
        Write-Log("Initialize-SqlScripts - {0} - already extracted" -f $firstResponderKit)
    }
    Copy-Item -Path (Join-Path $firstResponderKit -ChildPath "Install-All-Scripts.sql") -Destination (Join-Path $script:scriptFolder -ChildPath "Initialize_02_2_BrentOzar_Install-All-Scripts.sql") -Force

    $sqlfiles = Get-ChildItem (Join-Path $script:scriptFolder -ChildPath "Initialize*.sql") | Sort-Object FullName

    $sqlLocation = "SQLSERVER:\sql\{0}\default" -f $env:COMPUTERNAME
    Write-Log("Initialize-SqlScripts - SQLPath: {0}" -f $sqlLocation)
    Push-Location -Path $sqlLocation

    foreach ($sqlfile in $sqlfiles) {
        Write-Log("Executing sql from file: {0} as user {1}" -f $sqlfile.FullName, $sqlCredentials.UserName)
        $sql = Get-Content -Path $sqlfile.FullName -Raw
        Invoke-Sqlcmd $sql -Credential $sqlCredentials -Database master
    }
    Pop-Location
    Write-Log("Initialize-SqlScripts - ready")
}

function Initialize-SqlServer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$dataLocation,
        [Parameter(Mandatory = $true)]
        [string]$logLocation,
        [Parameter(Mandatory = $true)]
        [string]$backupLocation,
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential] $sqlAdminCred
    )
    Write-Log("Initialize-SqlServer - start")
    $sqlServer = $env:COMPUTERNAME
    Write-Log("Initialize-SqlServer - Ensure directory: {0}" -f $dataLocation)
    if (!(Test-Path $dataLocation)) {
        New-Item -Path $dataLocation -ItemType Directory | Out-Null
    }
    Write-Log("Initialize-SqlServer - Ensure directory: {0}" -f $logLocation)
    if (!(Test-Path $logLocation)) {
        New-Item -Path $logLocation -ItemType Directory | Out-Null
    }
    Write-Log("Initialize-SqlServer - Ensure directory: {0}" -f $backupLocation)
    if (!(Test-Path $backupLocation)) {
        New-Item -Path $backupLocation -ItemType Directory | Out-Null
    }
    $modulesRequired = "SqlServer;Az" #;-separated list of required modules
    Install-Modules $modulesRequired

    $sqlLocation = "SQLSERVER:\sql\{0}\default" -f $sqlServer

    Write-Log("Initialize-SqlServer - ConfigureServerInstance: {0}" -f $sqlLocation)
    $serverInstance = Get-Item $sqlLocation
    # http://www.sqlservercentral.com/blogs/si-vis-pacem-para-sql/2016/02/26/mandatory-sql-server-properties-to-configure-on-a-new-instance/
    $serverMemory = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum ).sum
    $reserveGbOs = [Math]::Min($serverMemory, 16GB) / 4GB          #reserve 1gb / 4gb of ram for the os for the first 16gb
    $reserveGbOs += [int](($serverMemory - 4GB * $reserveGbOs) / 8GB)  #add 1gb /8gb of ram for the rest
    $reserveGbOs += 1                                            #add 1 gb
    $sqlMemory = ($serverMemory - $reserveGbOs * 1GB) / 1MB
    Write-Log("Initialize-SqlServer - MemoryMb was: {0}, set to: {1}: " -f $serverInstance.Configuration.MaxServerMemory.ConfigValue, $sqlMemory)
    $serverInstance.Configuration.MaxServerMemory.ConfigValue = $sqlMemory
    $serverInstance.Configuration.DefaultBackupCompression.ConfigValue = 1
    $serverInstance.Configuration.CostThresHoldForParallelism.ConfigValue = 50
    $serverInstance.Configuration.ShowAdvancedOptions.ConfigValue = 1
    $serverInstance.Configuration.RemoteDacConnectionsEnabled.ConfigValue = 1
    $serverInstance.Configuration.ContainmentEnabled.ConfigValue = 1
    $serverInstance.Configuration.Alter()
    
    $serverInstance.DefaultFile = $dataLocation
    $serverInstance.DefaultLog = $logLocation
    $serverInstance.BackupDirectory = $backupLocation

    $serverInstance.LoginMode = "Mixed"

    $serverInstance.Alter()

    $login = Get-Item ("{0}\logins\{1}" -f $sqlLocation, $sqlAdminCred.UserName) -ErrorAction Ignore
    if ($null -eq $login){
        Write-Log("Initialize-SqlServer - Add sqluser: {0}" -f $sqlAdminCred.UserName)
        Add-SqlLogin -ServerInstance $sqlServer -LoginName $sqlAdminCred.UserName -LoginType "SqlLogin" -DefaultDatabase "master" -Enable -GrantConnectSql -LoginPSCredential $sqlAdminCred
        $sysAdminRole = Get-Item ("{0}\roles\sysadmin" -f $sqlLocation)
        $sysAdminRole.AddMember($sqlAdminCred.UserName)
    }
    else {
        Write-Log("Initialize-SqlServer - Sqluser: {0} already exists" -f $sqlAdminCred.UserName)
    }
    $login = Get-Item ("{0}\logins\{1}" -f $sqlLocation, $sqlAdminCred.UserName) -ErrorAction Ignore
    if ($null -eq $login){
        Write-Log("Initialize-SqlServer - {0} NOT FOUND" -f $sqlAdminCred.UserName)
    }
    else {
        Write-Log("Initialize-SqlServer - Sqluser: {0} exists" -f $sqlAdminCred.UserName)
    }
    

    Write-Log("Initialize-SqlServer - Ensure Firewall rule")
    $rule = Get-NetFirewallRule | Where-Object { $_.Name -eq 'SqlServer' }
    if (! $rule) {
        Write-Log("Initialize-SqlServer - Adding Firewall rule")
        New-NetFirewallRule -Name 'SqlServer' -DisplayName 'SQL Server' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433
    }

    Write-Log("Initialize-SqlServer - **** MANUALLY ADD : Add VolumeMaintenance policy to NT Service\MSSQLSERVER ***** ")
    <# does not work unfortunately :'(
    Write-Log("Initialize-SqlServer - Add VolumeMaintenance policy to NT Service\MSSQLSERVER")
    Add-LoginToLocalPrivilege -Domain $env:COMPUTERNAME -Account "NT Service\MSSQLSERVER" -Privilege "SeManageVolumePrivilege" -Verbose -Confirm
    #>

    Add-DefenderExclusions -excludeFolders @("L:\mssql", "S:\mssql")

    Write-Log("Initialize-SqlServer - ready")
}

function Install-DbServer {
    Write-Log("Install-DbServer - start")
    $wantedFeatureList = @()
    $unwantedFeatureList = (
        "PowerShell-V2", 
        "Net-framework-features", 
        "NET-WCF-Services45")
    Install-Features -featuresToInstall $wantedFeatureList -featuresToUninstall $unwantedFeatureList

    $disks = Get-Disk | Where-Object { $_.PartitionStyle -eq "RAW" } | Sort-Object Size
    if ($disks.length -eq 2) {
        Connect-DisksFromStorage -diskNumber $disks[0].Number -driveLetter "L" -driveDescription "Log"
        Connect-DisksFromStorage -diskNumber $disks[1].Number -driveLetter "S" -driveDescription "Data"
    }

    $sqlUser = "sqladmin"
    $sqlPass = ConvertTo-SecureString -String "sqlCr3d." -AsPlainText -Force
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sqlUser, $sqlPass
    Initialize-SqlServer -dataLocation "S:\mssql\data" -logLocation "L:\mssql\log" -backupLocation "S:\backup" -sqlAdminCred $cred
    Install-StandardServerSoftware
    Install-OctopusClient
    Get-Cm3rdPartyDownloads
    Initialize-SqlScripts -sqlCredentials $cred
    # Install-MsDtc
    Get-Service MSSQLServer | Restart-Service 
    Set-ServerGenericSettings
    Write-Log("Install-DbServer - ready")
}

function Install-DeviceWebServer {
    param(
        [Parameter(Mandatory = $true)]
        [string] $environmentName
    )

    Write-Log("Install-DeviceWebServer - start")
    $wantedFeatureList = @(
        "FileAndStorage-Services",
        "Storage-Services",
        "Web-Server",
        "Web-WebServer",
        "Web-Common-Http",
        "Web-Default-Doc",
        "Web-Dir-Browsing",
        "Web-Http-Errors",
        "Web-Static-Content",
        "Web-Health",
        "Web-Http-Logging",
        "Web-Log-Libraries",
        "Web-Request-Monitor",
        "Web-Http-Tracing",
        "Web-Performance",
        "Web-Stat-Compression",
        "Web-Dyn-Compression",
        "Web-Filtering",
        "Web-IP-Security",
        "Web-Net-Ext45",
        "Web-Asp-Net45",
        "NET-Framework-45-Core",
        "NET-Framework-45-ASPNET",
        "MSMQ",
        "MSMQ-Services",
        "MSMQ-Server",
        "Windows-Defender",
        "Windows-Defender-Gui",
        "PowerShellRoot",
        "PowerShell",
        "PowerShell-ISE",
        "WoW64-Support")
        $unwantedFeatureList = (
            "PowerShell-V2", 
            "Net-framework-features", 
            "NET-WCF-Services45")
        Install-Features -featuresToInstall $wantedFeatureList -featuresToUninstall $unwantedFeatureList

    Install-DotNetFramework
    Install-StandardServerSoftware

    Install-PerformanceCounters
    Install-OctopusClient
    # Install-MsDtc
    Install-SqlSysClrTypes
    Connect-DisksFromStorage -diskNumber 2 -driveLetter "S" -driveDescription "Data"
    #Set-MsmqStorageLocation "S:\msmq" # we used to have special -fast- storage for msmq
    Set-SqlClientAlias -Alias "SqlServerAlias" -Instance ("cm-db01-{0}" -f $environmentName)
    #Set-DatabusDirectory -Location "S:\Databus" -EnvironmentName $environmentName
    Set-ServerGenericSettings
    Write-Log("Install-DeviceWebServer - ready")
}

function Install-WebServer {
    param(
        [Parameter(Mandatory = $true)]
        [string] $environmentName
    )
    Write-Log("Install-WebServer - start")

    $wantedFeatureList = @(
        "Web-Server",
        "Web-WebServer",
        "Web-Common-Http",
        "Web-Dir-Browsing",
        "Web-Http-Errors",
        "Web-Static-Content",
        "Web-Http-Redirect",
        "Web-Health",
        "Web-Http-Logging",
        "Web-Log-Libraries",
        "Web-Request-Monitor",
        "Web-Http-Tracing",
        "Web-Performance",
        "Web-Stat-Compression",
        "Web-Dyn-Compression",
        "Web-Security",
        "Web-Filtering",
        "Web-IP-Security",
        "Web-App-Dev",
        "Web-Net-Ext45",
        "Web-Asp-Net45",
        "Web-Mgmt-Tools",
        "Web-Mgmt-Console",
        "Web-Metabase",
        "Web-Lgcy-Mgmt-Console",
        "Web-Mgmt-Compat",
        "Web-Scripting-Tools",
        "NET-Framework-45-Features",
        "NET-Framework-45-Core",
        "NET-Framework-45-ASPNET",
        "MSMQ-Server",
        "RSAT",
        "RSAT-Feature-Tools",
        "RSAT-SMTP",
        "SMTP-Server",
        "Windows-Defender-Features",
        "Windows-Defender",
        "Windows-Defender-Gui",
        "PowerShellRoot",
        "PowerShell",
        "PowerShell-ISE",
        "WoW64-Support")
    $unwantedFeatureList = (
        "PowerShell-V2", 
        "Net-framework-features", 
        "NET-WCF-Services45")
    Install-Features -featuresToInstall $wantedFeatureList -featuresToUninstall $unwantedFeatureList

    Get-Cm3rdPartyDownloads
    Install-StandardServerSoftware

    #Connect-DisksFromStorage -diskNumber 2 -driveLetter "M" -driveDescription "Msmq"
    Connect-DisksFromStorage -diskNumber 2 -driveLetter "S" -driveDescription "Data"
    #Set-MsmqStorageLocation "m:\msmq"
    Set-SqlClientAlias -Alias "SqlServerAlias" -Instance ("cm-db01-{0}" -f $environmentName)
    Set-DatabusDirectory -Location "S:\Databus" -EnvironmentName $environmentName
    Set-ServiceStartupType -serviceName "SMTPSVC" -startupType "Automatic"
    Install-DotNetFramework

    Install-OctopusClient
    # Install-MsDtc
    Install-Redis
    Install-SqlSysClrTypes

    Write-Log("Install-WebServer - verify iiscrypto")
    if ((Test-Path "iiscrypto_*.bak") -eq $false) {
        $cmd = "iiscryptocli.exe /backup iiscrypto_{0:yyyyMMdd_HHmm}.bak /template .\iiscrypto_server12_client10.ictpl" -f (Get-Date)
        Write-Log("IISCryptoCmd: {0}`nREBOOT NEEDED`n" -f $cmd)
        Invoke-Command $cmd
    }
    else {
        Write-Log("IISCrypto settings were already applied. Settings can be verified using .\download\iiscrypto.exe")
    }
    Set-ServerGenericSettings

    Write-Log("Install-WebServer - ready")
}

function Install-AppServer {
    param(
        [Parameter(Mandatory = $true)]
        [string] $environmentName
    )
    Write-Log("Install-AppServer - start")
    $wantedFeatureList = @(
        "MSMQ"
    )
    $unwantedFeatureList = (
        "PowerShell-V2", 
        "Net-framework-features", 
        "NET-WCF-Services45")
    Install-Features -featuresToInstall $wantedFeatureList -featuresToUninstall $unwantedFeatureList

    Install-DotNetFramework
    
    Install-PerformanceCounters
    Install-OctopusClient
    # Install-MsDtc
    Connect-DisksFromStorage -diskNumber 2 -driveLetter "S" -driveDescription "Data"
    Set-SqlClientAlias -Alias "SqlServerAlias" -Instance ("cm-db01-{0}" -f $environmentName)
    Set-ServerGenericSettings

    Write-Log("Install-AppServer - ready")
}

function Install-Chocolatey {
    Write-Log("Install-Chocolatey - start")
    [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Write-Log("Install-Chocolatey - ready")
}

### Start of main ###

Write-Log("Initialize server -- START")

Set-ExecutionPolicy Unrestricted -Force
$exp = (Get-ExecutionPolicy).ToString()
Write-Log("Execution policy: {0}" -f $exp)

Install-Chocolatey

$nameparts = $env:COMPUTERNAME -split ("-")
$servertype = $nameparts[1].substring(0, $nameparts[1].length - 2)
$environmentname = $nameparts[2]
if ($nameparts[0] -eq "AGIS") {
    $environmentname = "PROD"
}
Write-Log("Initialize server -- servertype: {0}" -f $servertype)
switch ($servertype) {
    "APP" { Install-AppServer -environmentName $environmentname; break }
    "DW" { Install-DeviceWebServer -environmentName $environmentname; break }
    "WEB" { Install-WebServer -environmentName $environmentname; break }
    "DB" { Install-DbServer; break }
    default { Write-Log ("Unknown servertype: {0}" -f $servertype) }
}
Write-Log("Initialize server -- READY")
