
sp_msforeachdb '
if ''tempdb''=''?'' begin
	print ''** Skip backup ?-database''
end
else 
begin
	BACKUP DATABASE [?] 
	TO  DISK = ''/var/opt/mssql/data/?.bak''
	WITH 
		NOFORMAT, 
		NOINIT,  
		NAME = N''[?]-Full Database Backup'', 
		SKIP, 
		NOREWIND, 
		NOUNLOAD
	print ''** Database: [?] backupped to: /var/opt/mssql/data/?.bak''
end
'
