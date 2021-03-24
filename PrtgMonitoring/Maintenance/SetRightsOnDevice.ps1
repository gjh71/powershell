
function Set-PrtgUserAccess {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Device,

        [Parameter(Position = 0)]
        $UserId,

        [Parameter(Position = 1)]
        $Access
    )

    Process {

        $properties = @(($Device | Get-ObjectProperty -Raw).PSObject.Properties | Where-Object name -like "accessrights_*")

        $candidateName = "accessrights_$UserId"

        if (!($properties | Where-Object Name -eq $candidateName)) {
            throw "$UserId is not a valid UserId for this object. Valid values are $($properties.name -replace 'accessrights_','' -join ', ')"
        }

        $parameters = @{
            accessrights_ = 1
            accessgroup   = 0
        }

        foreach ($property in $properties) {
            if ($property.Name -eq $candidateName) {
                $parameters.$candidateName = $Access
            }
            else {
                $parameters.$($property.Name) = $property.Value
            }
        }

        $Device | Set-ObjectProperty -RawParameters $parameters -Force
    }
}

# -1 { if ($includeInheritedValue) { "Inherited" }; break }
# 0 { "None"; break }
# 100 { "Read"; break }
# 200 { "Write"; break }
# 400 { "Full"; break }

$usergroup = Get-Object -Name "_technical-support-group"
$stage = "stage-production"
$devices = get-device -tags $stage
$devices
$devices | Set-PrtgUserAccess -UserId $usergroup.id -Access 100
$stage = "stage-prod"
$devices = get-device -tags $stage
$devices
$devices | Set-PrtgUserAccess -UserId $usergroup.id -Access 100


<#

$usergroup = Get-Object -Name "_research-group"
# $stage = "stage-production"
# $devices = get-device -tags $stage
$devices | Set-PrtgUserAccess -UserId $usergroup.id -Access 100
$stage = "stage-beta"
$devices = get-device -tags $stage
$devices | Set-PrtgUserAccess -UserId $usergroup.id -Access 100
#>
$usergroup = Get-Object -Name "_research-group"
# get-probe -name "*beta*" | Set-PrtgUserAccess -UserId $usergroup.id -Access 100
# get-probe -name "agis*" | Set-PrtgUserAccess -UserId $usergroup.id -Access 100
