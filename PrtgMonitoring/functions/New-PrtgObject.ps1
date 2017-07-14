function New-PrtgObject
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$channel,
        [Parameter(Mandatory=$true)]
        [string]$value,
        [ValidateSet("BytesBandwidth", "BytesMemory", "BytesDisk", "Temperature", "Percent", "TimeResponse", "TimeSeconds", "TimeHours", "Count", "CPU", "BytesFile", "SpeedDisk", "SpeedNet", "Custom", "Value Lookup")]
        [string]$unit,
        $customUnit,
        $volumeSize,
    #    [ValidateSet("Absolute")]
        [string]$mode = "Absolute",
        [boolean]$showChart = $true,
        [boolean]$showTable = $true,
        [boolean]$float = $false,
        $LimitMaxError,
        [string]$LimitErrorMsg,
        $LimitMaxWarning,
        [string]$LimitWarningMsg
    )

    $prtgObject = New-Object PSObject
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "channel" -Value $channel
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "value" -Value $value
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "unit" -Value $unit
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "customUnit" -Value $customUnit
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "volumeSize" -Value $volumeSize
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "mode" -Value $mode
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "showChart" -Value $showChart
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "showTable" -Value $showTable
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "warning" -Value $warning
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "float" -Value $float
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitMaxError" -Value $LimitMaxError
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitErrorMsg" -Value $LimitErrorMsg
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitMaxWarning" -Value $LimitMaxWarning
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitWarningMsg" -Value $LimitWarningMsg
    Add-Member -InputObject $prtgObject -MemberType NoteProperty -Name "LimitMode" -Value $false

    if ($prtgObject.LimitMaxError -ne $null -or $prtgObject.LimitMaxWarning -ne $null)
    {
        $prtgObject.LimitMode = $true
    }

    Write-Verbose "Object created"
    $prtgObject
}
