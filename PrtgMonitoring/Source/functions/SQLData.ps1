function Get-SQLDataAsObjectList
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $connectionstring,
        [Parameter(Mandatory=$true)]
        [string] $sql,
        [int] $timeoutInSeconds = 30
    )

    $rv = @()
    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionstring
    $connection.Open()

    if (!$?) 
    {
        throw "Could not open the connection."
    }

    $command = New-Object System.Data.SqlClient.sqlCommand $sql, $connection
    $command.CommandTimeout = $timeoutInSeconds

    try 
    {
        $dataReader = $command.ExecuteReader()

        if ($datareader.HasRows)
        {
            while ($datareader.Read())
            {
                $record = New-Object PSObject
                [int]$fieldNr = 0
                while($fieldNr -lt $dataReader.FieldCount)
                {
                    Add-Member -InputObject $record -MemberType NoteProperty -Name $dataReader.GetName($fieldNr) -Value $dataReader.GetValue($fieldNr) -TypeName $dataReader.GetFieldType($fieldNr)
                    $fieldNr += 1
                }
                $rv += $record
            }
        }
    }
    catch  
    {
        $record = New-Object PSObject
        Add-Member -InputObject $record -MemberType NoteProperty -Name "ERROR" -Value ($_.Exception.Message)
        $rv += $record
    }
    finally 
    {
        $dataReader.Close()
    }

    $connection.Close()
    $rv
}

function Get-DataFromSqlWithParameters{
    param ( 
        [Parameter(Mandatory=$true)]
        $connectionstring,
        [Parameter(Mandatory=$true)]
        [string]$sql,
        $parameters=@{},
        $timeoutInSeconds=30
    )
    $cmd=new-object system.Data.SqlClient.SqlCommand($sql,$connectionstring)
    $cmd.CommandTimeout=$timeout
    foreach($p in $parameters.Keys){
        [Void] $cmd.Parameters.AddWithValue("@$p",$parameters[$p])
    }
    $ds=New-Object system.Data.DataSet
    $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
    $da.fill($ds) | Out-Null
 
    return $ds.Tables
}

function ExecuteSql
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $connectionstring,
        [Parameter(Mandatory=$true)]
        [string] $sql
    )
    $connection = new-object System.Data.SqlClient.SqlConnection $connectionstring
    $connection.Open()

    if (!$?) 
    {
        throw "Could not open the connection."
    }

    $command = New-Object System.Data.SqlClient.sqlCommand $qry, $connection
    $command.ExecuteNonQuery()
    $connection.Close()
}

function Get-ConnectionString
{
    param(
        [Parameter(Mandatory=$false)]
        [string] $targetSql = "SqlServerAlias",
        [string] $database,
        [string] $username,
        [string] $password
    )

    if ($database -eq $null)
    {
        $database = "master"
    }

    switch ($env:COMPUTERNAME) {
        "AGIS-APP04" {  
            $servers = @("AGIS-DB12", "AGIS-DB13")
            break
        }
        "AGIS-WEB05" {  
            $servers = @("AGIS-DB12", "AGIS-DB13")
            break
        }
        "AGIS-WEB12" {  
            $servers = @("AGIS-DB12", "AGIS-DB13")
            break
        }
        Default {
            $servers = @($targetSql, $targetSql)
        }
    }
    if ($username -ne "")
    {
        $connectionString = "Data Source={0};Failover Partner={1};Initial Catalog={2};User id={3};Password={4};MultipleActiveResultSets=True;Application Name=PRTG-Monitor-ps1" -f $servers[0], $servers[1], $database, $username, $password
    }
    else {
        $connectionString = "Data Source={0};Failover Partner={1};Initial Catalog={2};Integrated Security=SSPI;MultipleActiveResultSets=True;Application Name=PRTG-Monitor-ps1" -f $servers[0], $servers[1], $database
    }
    $connectionString
}