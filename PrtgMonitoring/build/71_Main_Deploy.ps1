param (
    [Parameter(Mandatory=$true)]
    [string]$targetDirectory
)

Write-Host("71-Main-Deploy")

$buildDir = $PSScriptRoot
Write-Host("Builddir: {0}" -f $buildDir)
$sourceDirectory = Join-Path (Get-Item $buildDir).Parent.FullName -ChildPath "Source"
Write-Host("Sourcedirectory {0}" -f $sourceDirectory)
if ((Test-Path $targetDirectory) -eq $false){
    Write-Host("Directory {0} not found. Aborting." -f $targetDirectory)
    exit 1
}

# octopus adds some files, don't want them copied
$excludeList = @("*.secret", "bootstrap.ps1", "output.log", "*.code-workspace", ".gitignore", "*.http", "*.json")
$items2copy = Get-ChildItem -Path $sourceDirectory -Recurse -File -Exclude $excludeList

$sDir = (Get-Item $sourceDirectory).FullName
foreach($item in $items2copy){
    $tFile = Join-Path $targetDirectory -ChildPath ($item.FullName).Substring($sDir.Length)
    $tDir = Join-Path $targetDirectory -ChildPath ($item.DirectoryName).Substring($sDir.Length)
    if ((Test-Path $tDir) -eq $false){
        $newDir = New-Item -Path $tDir -ItemType Directory
        Write-Host("Created directory {0}" -f $newDir.FullName)
    }
    $item.CopyTo($tFile) | Out-Null
    Write-Host("File copied from {0} to {1}" -f $item.FullName, $tFile)
}
Write-Host("{0} Files copied" -f $items2copy.Length)
