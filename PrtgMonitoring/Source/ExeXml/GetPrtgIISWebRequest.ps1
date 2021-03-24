# Obsolete! Replaced by: GetPrtgCmApi-GetAlerts
param(
    [Parameter(Mandatory=$true)]
    [string] $baseuri,
    [Parameter(Mandatory=$true)]
    [string] $userNm,
    [Parameter(Mandatory=$true)]
    [string] $userPwd,
    [switch]$test
)
$sensorTimeStart = Get-Date
$success = 0
$events = @()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # Powershell uses standard Tls1.0... :'( 
Import-Module "C:\Program Files\WindowsPowerShell\Modules\CowManagerUtil"
$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$htmlAgilityPackDll = Join-Path $scriptDir -ChildPath "\lib\HtmlAgilityPack.dll"
[Reflection.Assembly]::LoadFile($htmlAgilityPackDll) | out-null
$pHAPDoc = New-Object HtmlAgilityPack.HtmlDocument

# First get a - request verification token and a sessionCookie
# $uri = "{0}/cowmanager/account/login?ReturnUrl=%2Fcowmanager%2F" -f $baseuri
$uri = "{0}/cowmanager/account/login?ReturnUrl=%2FCowManager%2FViews%2FKoe%2FAlleKoeien.aspx" -f $baseuri
$response = $null
$requestStart = Get-Date
Write-Verbose("{0:HH:mm:ss} - Start {1}" -f (Get-Date), $uri)
$response = Invoke-WebRequest -Uri $uri -body $body -Method Get -SessionVariable sessionCookie -usebasicparsing
Write-Verbose("{0:HH:mm:ss} - Ready {1}" -f (Get-Date), $uri)
$requestEnd = Get-Date
if ($test) {
	$response | Out-File "c:\temp\resp01.txt"
	$response.content | Out-File "c:\temp\content01.html"
}
$ms = [Math]::Round(((New-TimeSpan -Start $requestStart -End $requestEnd).TotalMilliseconds) ,0)
Write-Verbose("{0:HH:mm:ss} - Loading {1} took {2} ms" -f (Get-Date), $uri, $ms)
$pPrtgObject = New-PrtgObject `
		-channel ("Load 1st page") `
		-value $ms `
		-unit "TimeResponse" `
		-mode "Absolute" `
		-showChart 1 `
		-LimitMaxError 2000 `
		-LimitErrorMsg "Sensor execution took too long" `
		-LimitMaxWarning 1000 `
		-LimitWarningMsg "Sensor execution time warning"
$events += $pPrtgObject

$rvt = $null
foreach($field in $response.InputFields){
    if ($field.name -eq "__RequestVerificationToken"){
        $rvt = $field.value
        break;
    }
}

# Now login 
$body = @{
    __RequestVerificationToken = $rvt
    UserName = $userNm
    Password = $userPwd
}
$response = $null
$requestStart = Get-Date
Write-Verbose("{0:HH:mm:ss} - Start {1}" -f (Get-Date), $uri)
$response = Invoke-WebRequest -Uri $uri -Body $body -Method Post -WebSession $sessionCookie -usebasicparsing
Write-Verbose("{0:HH:mm:ss} - Ready {1}" -f (Get-Date), $uri)
$requestEnd = Get-Date
if ($test) {
	$response | Out-File "c:\temp\resp02.txt"
	$response.content | Out-File "c:\temp\content02.html"
}
$ms = [Math]::Round(((New-TimeSpan -Start $requestStart -End $requestEnd).TotalMilliseconds) ,0)
Write-Verbose("{0:HH:mm:ss} - Loading {1} took {2} ms" -f (Get-Date), $uri, $ms)
$pPrtgObject = New-PrtgObject `
		-channel ("Load 2nd page") `
		-value $ms `
		-unit "TimeResponse" `
		-mode "Absolute" `
		-showChart 1 `
		-LimitMaxError 60000 `
		-LimitErrorMsg "Sensor execution took too long" `
		-LimitMaxWarning 30000 `
		-LimitWarningMsg "Sensor execution time warning"
$events += $pPrtgObject

# And the response should be the company list (if user can log on to multiple companies)

$pHAPDoc.LoadHtml($response)
Write-Verbose("{0:HH:mm:ss} - Loading html done" -f (Get-Date))
$companyName = ""
$companyNode = $pHAPDoc.DocumentNode.SelectNodes("//a[@id='ctl00_ctl00_CompanyNav1_hlBedrijfList']/strong")
if ($null -ne $companyNode){
    $companyName = ($companyNode.InnerText).Trim()
}
if ($companyName -like "*(*)"){
    # finding a companyName, means we've got a successful database connection
    $success = 1
    $summaryNodes = $pHAPDoc.DocumentNode.SelectNodes("//table[@id='ctl00_ctl00_cph1_Ovz_KoeOverzicht_rgCowManagerList_ctl00_Footer']/tbody/tr[@class='rgFooter']/td")
    $nrOfCows = 0
    if (@($summaryNodes).Count -gt 0){
        $nrOfCows = ($summaryNodes[0].InnerText).Substring(3).trim()
    }
    Write-Verbose("{0:HH:mm:ss} - {1} cows" -f (Get-Date), $nrOfCows)
    #Company is known
    $pPrtgObject = New-PrtgObject `
	    -channel ($companyName) `
	    -value ($nrOfCows) `
	    -unit "Count" `
        -LimitMinError 1 `
        -LimitErrorMsg "At least 1 cow should be present" `
        -showChart 1
    $events += $pPrtgObject
}
else {
    #$companyTable = $pHAPDoc.DocumentNode.SelectNodes("//table[@class='rgMasterTable rgClipCells rgClipCells']")
    #$shownCompanies = $pHAPDoc.DocumentNode.SelectNodes("//table[@class='rgMasterTable rgClipCells rgClipCells']/tbody/tr/td/input").count

    $nrOfCompanies = "0"
    $summaryNode = $pHAPDoc.DocumentNode.SelectNodes("//table[@class='rgMasterTable rgClipCells rgClipCells']/tbody/tr[@class='rgPager']/td/table/tbody/tr/td/div/strong")
    if (@($summaryNode).Count -gt 1){
        # if we have a master table, and we can find the summary, the companies have loaded so we have a successful db connection
        $success = 1

        $nrOfCompanies = $summaryNode[$summaryNode.Count-2].InnerText.Trim()
    }
    Write-Verbose("{0:HH:mm:ss} - {1} companies" -f (Get-Date), $nrOfCompanies)

    $pPrtgObject = New-PrtgObject `
	    -channel ("nrOfCompanies") `
	    -value ($nrOfCompanies) `
	    -unit "Count" `
        -LimitMinError 0.5 `
        -LimitErrorMsg "At least 1 company should be found'" `
        -showChart 1
    $events += $pPrtgObject
}
$pPrtgObject = New-PrtgObject `
		-channel ("Data retrieved from DB") `
		-value ("{0}" -f $success) `
		-unit "Count" `
		-mode "Absolute" `
		-showChart 1 `
		-LimitMinError 0.5 `
		-LimitErrorMsg "No valid page retrieved" 
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
Write-Verbose("{0:HH:mm:ss} - Ready" -f (Get-Date))
