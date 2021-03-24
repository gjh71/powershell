[CmdletBinding()]
param()

$allResults = @()
function Get-SQLDataAsObjectList {
    param(
        [Parameter(Mandatory = $true)]
        [string] $connectionstring,
        [Parameter(Mandatory = $true)]
        [string] $sql,
        [int] $timeoutInSeconds = 30
    )

    $rv = @()

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection $connectionstring
        $connection.Open()
        $command = New-Object System.Data.SqlClient.sqlCommand $sql, $connection
        $command.CommandTimeout = $timeoutInSeconds
        $dataReader = $command.ExecuteReader()

        if ($datareader.HasRows) {
            while ($datareader.Read()) {
                $record = New-Object PSObject
                [int]$fieldNr = 0
                while ($fieldNr -lt $dataReader.FieldCount) {
                    Add-Member -InputObject $record -MemberType NoteProperty -Name $dataReader.GetName($fieldNr) -Value $dataReader.GetValue($fieldNr)
                    $fieldNr += 1
                }
                $rv += $record
            }
        }
    }
    catch {
        $record = New-Object PSObject
        Add-Member -InputObject $record -MemberType NoteProperty -Name "ERROR" -Value ($_.Exception.Message)
        $rv += $record
    }
    finally {
        if ($null -ne $dataReader) {
            $dataReader.Close()
        }
        if ($null -ne $connection) {
            $connection.Close()
        }
    }

    $rv
}

function Test-ConnectionsInConfig {
    param(
        [Parameter(Mandatory = $true)]
        $configPath
    )
    $rv = $true
    $configContent = [xml](Get-Content $configPath)
    $qry = "select @@servername as servername"
    Write-Verbose("Analizing connections in {0}" -f $configPath)
    foreach ($connection in $configContent.configuration.connectionStrings.add) {
        Write-Verbose ("{0}" -f $connection.name) 
        if ($connection.name -in ("CowManagerCache", "CalculationEntities", "Eventhub_ConnectionString_DeviceEvent", "Eventhub_ConnectionString_Device", "Eventhub_ConnectionString_Behavior")) {
        }
        else {
            $constr = $connection.connectionString
            if ($connection.providerName -eq "System.Data.EntityClient") {
                $constr = $constr.Split('"')[1]
            }

            $result = Get-SQLDataAsObjectList -connectionstring $constr -sql $qry
            foreach ($row in $result) {
                if ($null -ne $result.ERROR) {
                    Write-Verbose ("ERROR: `t {0}: {1}" -f $connection.name, $result.ERROR)
                    $rv = $false
                }
                else {
                    # $result = @{
                    #     ConfigFile       = $configPath
                    #     Connection       = $connection.name
                    #     ConnectedServer  = $result.servername
                    #     ConnectionString = $constr
                    # }
                    # $allResults += Select-Object { @n = "ConfigFile"; @n = $configPath }
                    Write-Verbose ("Connection OK!: `t {0}: {1}" -f $connection.name, $result.servername)
                }
            }
        }
    }
    $rv
}

$rootFolder = "C:\Octopus\Applications"
$configCount = 0
$stageFolders = Get-ChildItem -Path $rootFolder -Directory
foreach ($stageFolder in $stageFolders) {
    $deployedAppFolders = Get-ChildItem -Path $stageFolder.FullName -Directory
    foreach ($deployedAppFolder in $deployedAppFolders) {
        $lastVersionFolder = Get-ChildItem -Path $deployedAppFolder.FullName -Directory | Sort-Object | Select-Object -Last 1
        Write-Verbose("Application: {0} - Version: {1}" -f $deployedAppFolder.Name, $lastVersionFolder.Name)
        $configFiles = Get-ChildItem -Path $lastVersionFolder.FullName -Filter *.config -File
        $config = $configFiles | Where-Object { $_.name -eq "web.config" }
        if ($null -eq $config) {
            $baseName = $deployedAppFolder.Name.Substring(10)
            $config = $configFiles | Where-Object { $_.name -like ("*{0}*" -f $baseName) }
        }
        if ($null -eq $config) {
            Write-Verbose("Skipping: {0}\{1}, no config determined" -f $deployedAppFolder.Name, $lastVersionFolder.Name)
        }
        else {
            $configCount++
            $result = Test-ConnectionsInConfig -configPath $config.FullName
            if ($result -eq $false) {
                Write-Host("Bad connection in: {0} {1}" -f $deployedAppFolder.Name, $lastVersionFolder.Name) -ForegroundColor red -BackgroundColor White
            }
        }
    }
}
Write-Host("{0} configs checked, run with -verbose to see details" -f $configCount)
$allResults | Out-GridView