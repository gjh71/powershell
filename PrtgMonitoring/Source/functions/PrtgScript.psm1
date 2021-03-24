$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
#Write-Host $scriptDir
Push-Location $scriptDir
$functionlist = Get-ChildItem *.ps1 -Exclude "*.Tests.ps1" | Where-Object {$_.name -cnotlike "_*"}

foreach ($functionfile in $functionlist)
{
    . $functionfile.FullName
}

Pop-Location