[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("app", "web", "dw", "db")]
    [string[]] $machineRoles
)
$machineRoles | ForEach-Object{
    write-host("Role: {0}" -f $_)
}
Write-Host("done")