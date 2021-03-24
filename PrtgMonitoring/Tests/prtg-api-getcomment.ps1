$usernm=$env:USERNAME
$passhash=$env:passhash
$baseuri="monitor.cowmanager.com:8080"

# $uri="https://$baseuri/api/table.xml?content=sensors&columns=sensor&username=$usernm&passhash=$passhash"
# Write-Host($uri)
# Invoke-WebRequest $uri

$sensorid=4859
$uri = "https://{0}/api/getobjectproperty.htm?username={1}&passhash={2}&show=text&id={3}&name=comments" -f $baseuri, $usernm, $passhash, $sensorid
Write-Host($uri)
Invoke-WebRequest -uri $uri -UseBasicParsing

$uri = "https://{0}/api/getobjectproperty.htm?username={1}&passhash={2}&show=text&id={3}&subtype=channel" -f $baseuri, $usernm, $passhash, $sensorid
Write-Host($uri)
Invoke-WebRequest -uri $uri -UseBasicParsing

