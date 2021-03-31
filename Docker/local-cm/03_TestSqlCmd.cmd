set sqlserver="localhost,1733"
set sqlserver="sqlserveralias"
set sqlserver=tcp:localhost,1733
set sqlusr=sa
set sqlpwd=%dockersqlpwd%

set sqlqry="select @@servername, getdate()"

sqlcmd -S %sqlserver% -U %sqlusr% -P %sqlpwd% -q %sqlqry%
pause
