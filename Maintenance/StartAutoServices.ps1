#Starts services which are not running but have 'Autostart' as startup type
#must be run 'With high privileges (as administrator)'

$LogNm = "Application"
$SrcNm = "Autostart-Services"

#Eventlog source must be present: --> uncomment next line and make sure it exists
#New-EventLog –LogName $LogNm –Source $SrcNm

$msg = "Starting stopped -autostart- services"
Write-EventLog -LogName $LogNm -Source $SrcNm -EntryType Information -EventId 9000 -Message $msg
Write-Host $msg -ForegroundColor Yellow

#start all services with startmode 'auto' and not running
$services = Get-WmiObject Win32_Service | Select-Object Name, State, StartMode, Status
foreach ($service in $services)
{
    if ($service.State -ne "Running" -and $service.Startmode -eq "Auto")
    {
        $msg = "Service {0} not started, now starting..." -f $service.Name
        Write-EventLog -LogName $LogNm -Source $SrcNm -EntryType Information -EventId 9000 -Message $msg
        Write-Host $msg -ForegroundColor Yellow

        $serviceToStart = Get-Service $service.name
        $serviceToStart.Start()

        $msg = "Status of service {0}:{1}" -f $serviceToStart.DisplayName, $serviceToStart.Status
        Write-EventLog -LogName $LogNm -Source $SrcNm -EntryType Information -EventId 9000 -Message $msg
        Write-Host $msg -ForegroundColor Yellow
    }
}

