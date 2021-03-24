[CmdLetBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$AliasName,
    [Parameter(Mandatory = $true)]
    [string]$SqlServerName,
    [string]$SqlServerPort = 1433
)

function Set-SqlServerAlias{
    param (
        [Parameter(Mandatory = $true)]
        [string]$AliasName,
        [Parameter(Mandatory = $true)]
        [string]$SqlServerName,
        [string]$SqlServerPort = 1433
    )
    #These are the two Registry locations for the SQL Alias (both 32 and 64 bit!)
    $x86 = "HKLM:\Software\Microsoft\MSSQLServer\Client\ConnectTo"
    $x64 = "HKLM:\Software\Wow6432Node\Microsoft\MSSQLServer\Client\ConnectTo"
 
    if ((test-path -path $x86) -ne $True) {
        New-Item $x86 | Out-Null
    }
    if ((test-path -path $x64) -ne $True) {
        New-Item $x64 | Out-Null
    }
 
    $TcpAliasName = "DBMSSOCN,$SqlServerName,$SqlServerPort"
 
    Set-ItemProperty -Path $x86 -Name $AliasName -Value $TcpAliasName
    Set-ItemProperty -Path $x64 -Name $AliasName -Value $TcpAliasName

    Write-Host("Alias [{0}] created to sql-server: {1}:{2}" -f $AliasName, $SqlServerName, $SqlServerPort)
}

Set-SqlServerAlias -aliasname $aliasname -sqlservername $sqlservername -sqlserverport $sqlserverport