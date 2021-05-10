[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$variableName,
    [string]$variableValue
)
[System.Environment]::SetEnvironmentVariable($variableName,$variableValue,"machine")