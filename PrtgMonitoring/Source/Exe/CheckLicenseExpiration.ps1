[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$licenseName,
    [Parameter(Mandatory = $true)]
    [string]$expirationDate,
    [string]$minimumDaysValid = 20
)

$expirationRealDate = Get-Date $expirationDate
$today = Get-Date ("{0:yyyy-MM-dd}" -f (Get-Date)) # Compare with 'real days'
$daysDifference = (New-TimeSpan -Start $today -End $expirationRealDate).Days

$msg = switch ($daySwitch) {
    {$_ -gt $minimumDaysValid} {
        ("0:OK, {0} license has {1} days left to expiration. Will expire at {2:dd-MM-yyyy}. Minimum days required: {3}" -f $licenseName, $daysDifference, $expirationRealDate, $minimumDaysValid)
        break
    }
    { $_ -gt 0 } {
        ("1:Take action!. Too few days left! {0} license has {1} days left to expiration. Will expire at {2:dd-MM-yyyy}. Minimum days required: {3}" -f $licenseName, $daysDifference, $expirationRealDate, $minimumDaysValid)
        break
    }
    { $_ -eq 0 } {
        ("1:CALL TO ACTION, {0} license expires TODAY!" -f $licenseName, $daysDifference, $expirationRealDate)
        break
    }
    { $_ -lt 0 } {
        ("1:{0} license expired {1} days ago at {2:dd-MM-yyyy}!" -f $licenseName, (-1 * $daysDifference), $expirationRealDate)
        break
    }
    default {
        "1: Could not determine state properly"
    }
}
$msg
