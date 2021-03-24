$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\_Environment.ps1"

Describe "initialised" {
    It ("host: {0}" -f $env:prtg_host) {
        $env:prtg_host.length | Should BeGreaterThan 1
    }
    It ("applicationid: {0}" -f $env:prtg_windowsuser) {
        $env:prtg_windowsuser.length | Should BeGreaterThan 1
    }
    It ("password set?") {
        $env:prtg_windowspassword.length | Should BeGreaterThan 1
    }
}

$environment = "test"
$resourcegroup = "cm-readmodel-{0}-rg" -f $environment
$namespace = "cm-readmodel-{0}-bus" -f $environment

$result = [xml](. "$here\..\$sut" -resourcegroup $resourcegroup -namespace $namespace)
Describe "initialised" {
    It ("results of {0}" -f $namespace) {
        $result.prtg.result.Count | Should BeGreaterThan 1
    }

    foreach($channel in $result.prtg.result){
        It ("channel {0} value {1} shouldbe less than maxerror {2}" -f $channel.channel, $channel.value, $channel.LimitMaxError) {
            $channel.value | Should BelessThan $channel.LimitMaxError
        }
    }

    $responseTime = ($result.prtg.result | where-object {$_.Channel -eq "Execution time"} )
    It ("Response time {0} shouldbe less than maxerror {1}" -f $responseTime.value, $responseTime.LimitMaxError) {
        $responseTime.value | Should BelessThan $responseTime.LimitMaxError
    }
}

