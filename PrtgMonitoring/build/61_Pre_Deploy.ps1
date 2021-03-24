param (
    [Parameter(Mandatory=$true)]
    [string]$serviceName,
    [Parameter(Mandatory=$true)]
    [string]$targetDirectory
)

Write-Host("61-Pre-Deploy")

$service = Get-Service $serviceName
Write-Host("Service: {0} is {1}. Needs to be stopped." -f $service.Name, $service.Status)
$service | Stop-Service

$targetDirectories = @("C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXE\", "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\")
foreach ($targetDirectory in $targetDirectories) {
    if ((Test-Path $targetDirectory) -eq $false) {
        Write-Host("Folder {0} not found" -f $targetDirectory)    
    }
    else {
        Write-Host("Remove contents of folder {0}" -f $targetDirectory)
        Get-ChildItem -Path $targetDirectory -Recurse | Remove-Item -Force -Recurse
        Write-Host("Removing folder {0}" -f $targetDirectory)
        Remove-Item -Path $targetDirectory -Force
    }
    $newFolder = New-Item -Path $targetDirectory -ItemType Directory
    Write-Host("Folder {0} has been created" -f $newFolder.FullName)
}
