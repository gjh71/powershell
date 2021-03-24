<#
# NOTE: this sensor can only be added to a PRTG DEVICE having the following properties set:
1. Credentials for Windows Systems are specified
2. Windows username = applicationid for the concerning application-insights
3. Password = ApiKey for application-insights workspace

!!! Sensor should have 'Environment' set to 'Set placeholders as environment values' !!!

Then add parameters eg.
-timespanMinutes 5 -query '--kusto query text on 1 line--'

Example query one could use:
requests 
| extend rolename = iif(cloud_RoleName has "CowManager.", substring(cloud_RoleName,11), cloud_RoleName) 
| extend server = iif(client_Type == "PC", cloud_RoleInstance, client_Type) 
| extend channelName = strcat(rolename, " (",server, ")") 
| extend channelType = "TimeResponse"
| summarize channelValue=toint(avg(duration)) by channelName, channelType
| order by channelName asc

Note:
1. 'channelName', 'channelType' and 'channelValue' are defined in the query
2. the query should be converted to a single line before assigning it as parameter

$env:prtg_windowsuser = (Get-AzKeyVaultSecret -VaultName "cm-prtg-kv" -name "prtg-applicationinsights-prod-name").secretvaluetext
$env:prtg_windowspassword = (Get-AzKeyVaultSecret -VaultName "cm-prtg-kv" -name "prtg-applicationinsights-prod-value").secretvaluetext
.\GetPrtgAi_QueryV2.ps1 -timespanMinutes 5 -query 'requests | extend rolename = iif(cloud_RoleName has "CowManager.", substring(cloud_RoleName,11), cloud_RoleName) | extend server = iif(client_Type == "PC", cloud_RoleInstance, client_Type) | extend channelName = strcat(rolename, " (",server, ")") | extend channelType = "TimeResponse" | summarize channelValue=toint(avg(duration)) by channelName, channelType | order by channelName asc'
requests | extend rolename = iif(cloud_RoleName has "CowManager.", substring(cloud_RoleName,11), cloud_RoleName) | extend server = iif(client_Type == "PC", cloud_RoleInstance, client_Type) | extend channelName = strcat(rolename, " (",server, ")") | extend channelType = "TimeResponse" | summarize channelValue=toint(avg(duration)) by channelName, channelType | order by channelName asc
#>


param(
    [Parameter(Mandatory=$true)]
    [int] $timespanMinutes,
    [Parameter(Mandatory=$true)]
    [string] $query,
    [int] $defaultChannelValue = 0
)
$sensorTimeStart = Get-Date

#$workspaceid   = $env:prtg_windowsdomain
$applicationid  = $env:prtg_windowsuser
$apikey         = $env:prtg_windowspassword

Import-Module "C:\Program Files\WindowsPowerShell\Modules\CowManagerUtil"
# force usage of tls1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$channelListFileDirty = $false
$channelListFile = Join-Path $env:TEMP -ChildPath ("{0}-{1}.lst" -f ($MyInvocation.MyCommand.Name).split(".")[0], $env:prtg_sensorid)
if (Test-Path($channelListFile)) {
    $channelList = (Get-Content -Path $channelListFile -Raw)|ConvertFrom-Json
}
else {
    $channelList = @()
    $channelListFileDirty = $true
}

function Get-ParamForUrl{
    param(
        $hashtable
    )
    $urlparam = ""
    foreach($key in $hashtable.Keys){
        $urlparam += "&{0}={1}" -f $key, [System.Web.HttpUtility]::UrlEncode($hashtable.Item($key))
    }
    $urlparam.Substring(1)
}

$baseurl = "https://api.applicationinsights.io"
$header = @{
    "accept" = "application/json"
    "x-api-key" = $apikey
}

$params = @{
    timespan = "PT{0:00}M" -F $timespanMinutes
    query = $query
}
$uri = "{0}/v1/apps/{1}/query?{2}" -f $baseurl, $applicationid, (Get-ParamForUrl -hashtable $params)
$result = Invoke-WebRequest -Uri $uri -Headers $header -Method Get -UseBasicParsing
$tables = ($result | ConvertFrom-Json).tables

$events = @()

foreach($row in $tables[0].rows){
    $parm = @{
        channel   = ("{0}" -f $row[0])
        unit      = $row[1]
        value     = $row[2]
        mode      = "Absolute"
        showTable = 1
        showChart = 1
    }
    $events += New-PrtgObject @parm
    
    if ($parm.channel -notin $channelList){
        $channelList += @($parm.channel)
        $channelListFileDirty = $true
    }
}

$missingChannels = $channelList | Where-Object {$_ -notin ($events.channel)}
foreach($channel in $missingChannels){
    $events += New-PrtgObject -channel $channel -value $defaultChannelValue #no other properties needed as the channel is already defined
}

if ($channelListFileDirty){
    $channelList | ConvertTo-Json | Out-File $channelListFile    
}

$sensorTimeStop = Get-Date

$parm = @{
    channel   = "Execution time"
    unit      = "TimeResponse"
    value     = [Math]::Round(((New-TimeSpan -Start $sensorTimeStart -End $sensorTimeStop).TotalMilliseconds) , 0)
    mode      = "Absolute"
    showChart = 0
    showTable = 1
}
$events += New-PrtgObject @parm

$events = $events | Sort-Object channel
$myXml = Get-PrtgXmlFromEvents -events $events
$myXml
