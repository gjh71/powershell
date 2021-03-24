#requires -modules CowManagerUtil

# This sensor expects on the prtg-device:
#  device.HostName = eg. sensor.dev-cowmanager.com (i.e. IPv4 address/dns name in prtg device)
#  device.WindowsDomain = 01234 = accountnr
#  device.WindowsUser = e.g. "usr-account" (= cowmanager account)
#  device.WindowsPassword = "usr-pwd"
# For debugging set variables like:
# $env:prtg_host = "sensor.cowmanager.com"
# $env:prtg_windowsdomain = "01234"
# $env:prtg_windowsuser = ""
# $env:prtg_windowspassword = ""
# swagger url: 
# https://sensor.dev-cowmanager.com/cowmanager.api/swagger/ui/index

param(
    [int]$pagesize=1000,
    [switch]$useInterfaceApi,
    [switch]$emulateAlertExportTool
)
$sensorTimeStart = Get-Date
$events = @()

Import-Module "C:\Program Files\WindowsPowerShell\Modules\CowManagerUtil"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # Powershell uses standard Tls1.0... :'( 

function Get-Token {
    param(
        $apiuri,
        $username,
        $userpwd,
        $accountNumber
    )
    $tokenOk = $false
    #add sensorid to token file: each sensor it's own token!
    $tokenKey = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(("GetPrtgIISApiRequest.token{0}-{1}-{2}" -f $apiuri, $username, $env:prtg_sensorid)))
    $localTokenLocation = Join-Path $env:TEMP -ChildPath $tokenKey
    if (Test-Path $localTokenLocation) {
        $tokenFile = Get-Item $localTokenLocation
        if ($tokenFile.LastWriteTime.AddSeconds(3600) -gt (Get-Date)) {
            $token = Get-Content $localTokenLocation -Raw | ConvertFrom-Json
            $tokenOk = $true
        }
    }

    if (!$tokenOk) {
        $header = @{
            "Content-Type"  = "application/json"; 
            "Api-Version"   = 1;
            "User-Agent"    = "Powershell";
            "Authorization" = ""
        }
        $body = @{
            "grant_type"         = "password";
            "username"           = $username;
            "password"           = $userpwd;
            "company_identifier" = $accountnumber;
        }
        $uri = "{0}/token" -f $apiuri

        $response = Invoke-WebRequest -Headers $header -Uri $uri -Method Post -Body $body -UseBasicParsing
        $response.Content | Out-File $localTokenLocation
        $token = $response | ConvertFrom-Json
    }

    $token.access_token
}

$baseuri = "https://{0}" -f $env:prtg_host
$accountnr = $env:prtg_windowsdomain
$userNm = $env:prtg_windowsuser
$userPwd = $env:prtg_windowspassword

$callStart = Get-Date
$token = Get-Token -apiuri ("{0}/cowmanager.api" -f $baseuri) -username $userNm -userpwd $userPwd -accountNumber $accountnr
$callEnd = Get-Date

$parm = @{
    channel         = ("GetToken-Duration")
    value           = [Math]::Round(((New-TimeSpan -Start $callStart -End $callEnd).TotalMilliseconds), 0)
    unit            = "TimeResponse"
    mode            = "Absolute"
    showChart       = 1
    LimitMaxError   = 2000
    LimitErrorMsg   = "Sensor execution took too long"
    LimitMaxWarning = 1000
    LimitWarningMsg = "Sensor execution time warning"
}
$events += New-PrtgObject @parm

$header = @{
    "Content-Type"  = "application/json"; 
    "Api-Version"   = 1;
    "User-Agent"    = "Powershell";
    "Authorization" = "Bearer {0}" -f $token
}

$page = 1
$callStart = Get-Date
$doLoop = $true
$cnt = 0
$total = 0

$alertsUri = "{0}/cowmanager.api/private/alerts?page={1}&pagesize={2}&prtg=1"   #private api is used by mobile-phone
if ($useInterfaceApi){
    $alertsUri = "{0}/cowmanager.api/alerts?Page={1}&PageSize={2}&prtg=1"       #'public' api is for usage by external parties, and also alertexporttool
}
while ($doLoop) {
    $uri = $alertsUri -f $baseuri, $page, $pagesize
    $response = ( Invoke-WebRequest -Headers $header -Uri $uri -Method Get -UseBasicParsing)
    $result = $response | ConvertFrom-Json
    $total = $result.total
    $alerts = @($result.alerts)
    $cnt += $alerts.Length
    $page += 1
    $doLoop = ($total -gt $cnt)
}
if ($emulateAlertExportTool){
    $uri = $alertsUri -f $baseuri, $page, $pagesize
    $response = ( Invoke-WebRequest -Headers $header -Uri $uri -Method Get -UseBasicParsing)
    $page += 1
}
$callEnd = Get-Date

$parm = @{
    channel         = ("GetAlerts-Duration")
    value           = [Math]::Round(((New-TimeSpan -Start $callStart -End $callEnd).TotalMilliseconds), 0)
    unit            = "TimeResponse"
    mode            = "Absolute"
    showChart       = 1
    LimitMaxError   = 4000
    LimitErrorMsg   = "Sensor execution took too long"
    LimitMaxWarning = 3000
    LimitWarningMsg = "Sensor execution time warning"
}
$events += New-PrtgObject @parm

$parm = @{
    channel   = ("NrAlerts-{0}" -f $accountnr)
    value     = ("{0}" -f $total)
    unit      = "Count"
    showChart = 1
}
$events += New-PrtgObject @parm

$parm = @{
    channel   = ("Pages")
    value     = ("{0}" -f ($page - 1))
    unit      = "Count"
    showChart = 1
}
$events += New-PrtgObject @parm

$parm = @{
    channel   = ("Pagesize")
    value     = ("{0}" -f $pagesize)
    unit      = "Count"
    showChart = 1
}
$events += New-PrtgObject @parm

$sensorTimeStop = Get-Date

$parm = @{
    channel         = ("Execution time")
    value           = [Math]::Round(((New-TimeSpan -Start $sensorTimeStart -End $sensorTimeStop).TotalMilliseconds) , 0)
    unit            = "TimeResponse"
    mode            = "Absolute"
    showChart       = 1
    LimitMaxError   = 5000
    LimitErrorMsg   = "Sensor execution took too long"
    LimitMaxWarning = 4000
    LimitWarningMsg = "Sensor execution time warning"
}
$events += New-PrtgObject @parm

$myXml = Get-PrtgXmlFromEvents -events $events

$myXml