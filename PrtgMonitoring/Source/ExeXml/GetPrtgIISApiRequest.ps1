# Obsolete! Replaced by: GetPrtgCmApi-GetAlerts
# swagger url: 
# https://sensor.dev-cowmanager.com/cowmanager.api/swagger/ui/index

param(
    [Parameter(Mandatory=$true)]
    [string] $baseuri,
    [Parameter(Mandatory=$true)]
    [string] $userNm,
    [Parameter(Mandatory=$true)]
    [string] $userPwd,
    [Parameter(Mandatory=$true)]
    [string] $accountnr,
    [switch]$test
)
$sensorTimeStart = Get-Date
$events = @()

Import-Module "C:\Program Files\WindowsPowerShell\Modules\CowManagerUtil"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # Powershell uses standard Tls1.0... :'( 

function Get-Token{
    param(
        $apiuri,
        $username,
        $userpwd,
        $accountNumber
    )
    $tokenOk = $false
    $tokenKey = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(("GetPrtgIISApiRequest.token{0}-{1}" -f $apiuri, $username)))
    $localTokenLocation = Join-Path $env:TEMP -ChildPath $tokenKey
    if (Test-Path $localTokenLocation){
        $tokenFile = Get-Item $localTokenLocation
        if ($tokenFile.LastWriteTime.AddSeconds(3600) -gt (Get-Date)){
            $token = Get-Content $localTokenLocation -Raw | ConvertFrom-Json
            $tokenOk = $true
        }
    }

    if (!$tokenOk){
        $header = @{
            "Content-Type" = "application/json"; 
            "Api-Version" = 1;
            "User-Agent" = "Powershell";
            "Authorization" = ""
        }
        $body = @{
            "grant_type" = "password";
            "username" = $username;
            "password" = $userpwd;
            "company_identifier" = $accountnumber;
        }
        $uri = "{0}/token" -f $apiuri

        $response = Invoke-WebRequest -Headers $header -Uri $uri -Method Post -Body $body -UseBasicParsing
        $response.Content | Out-File $localTokenLocation
        $token = $response | ConvertFrom-Json
    }

    $token.access_token
}

$callStart = Get-Date
$token = Get-Token -apiuri ("{0}/cowmanager.api" -f $baseuri) -username $userNm -userpwd $userPwd -accountNumber $accountnr
$callEnd = Get-Date
$ms = [Math]::Round(((New-TimeSpan -Start $callStart -End $callEnd).TotalMilliseconds), 0)
Write-Verbose("ApiUri: {0} -- TokenRetrieved: {1}" -f $baseuri, $token)

$pPrtgObject = New-PrtgObject `
		-channel ("GetToken-Duration") `
		-value $ms `
		-unit "TimeResponse" `
		-mode "Absolute" `
		-showChart 1 `
		-LimitMaxError 2000 `
		-LimitErrorMsg "Sensor execution took too long" `
		-LimitMaxWarning 1000 `
		-LimitWarningMsg "Sensor execution time warning"
$events += $pPrtgObject
Write-Verbose("GetToken-Duration = {0} ms." -f $ms)

$header = @{
    "Content-Type"="application/json"; 
    "Api-Version" = 1;
    "User-Agent" = "Powershell";
    "Authorization" = "Bearer {0}" -f $token
}
$pagesize = 5000
$page = 1
$callStart = Get-Date
$doLoop = $true
$cnt = 0
while ($doLoop){
    $uri = "{0}/cowmanager.api/private/alerts?page={1}&pagesize={2}" -f $baseuri, $page, $pagesize
    Write-Verbose("Calling uri: {0}" -f $uri)
    $response = ( Invoke-WebRequest -Headers $header -Uri $uri -Method Get -UseBasicParsing)
    $result = $response | ConvertFrom-Json
    $total = $result.total
    $alerts = @($result.alerts)
    $cnt += $alerts.Length
    $page += 1
    $doLoop = ($total -gt $cnt)
}
$callEnd = Get-Date

$ms = [Math]::Round(((New-TimeSpan -Start $callStart -End $callEnd).TotalMilliseconds), 0)
$pPrtgObject = New-PrtgObject `
		-channel ("GetAlerts-Duration") `
		-value $ms `
		-unit "TimeResponse" `
		-mode "Absolute" `
		-showChart 1 `
		-LimitMaxError 4000 `
		-LimitErrorMsg "Sensor execution took too long" `
		-LimitMaxWarning 3000 `
		-LimitWarningMsg "Sensor execution time warning"
$events += $pPrtgObject
Write-Verbose("GetAlerts-Duration = {0} ms." -f $ms)

$total = ($response | ConvertFrom-Json).total
Write-Verbose("NrAlerts-{0} = {1}" -f $accountnr, $total)

$pPrtgObject = New-PrtgObject `
    -channel ("NrAlerts-{0}" -f $accountnr) `
    -value ("{0}" -f $total) `
    -unit "Count" `
    -showChart 1
$events += $pPrtgObject

$sensorTimeStop = Get-Date
$ms = [Math]::Round(((New-TimeSpan -Start $sensorTimeStart -End $sensorTimeStop).TotalMilliseconds) ,0)

$pPrtgObject = New-PrtgObject `
		-channel ("Execution time") `
		-value $ms `
		-unit "TimeResponse" `
		-mode "Absolute" `
		-showChart 1 
$events += $pPrtgObject

$myXml = Get-PrtgXmlFromEvents -events $events

if ($test){
    ([xml]($myXml)).prtg.result | Format-Table
}
else{
    $myXml
}