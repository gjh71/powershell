@echo off
REM Place this script on each monitored server in:
REM C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\
REM The returned channel-names contain computer/username
REM In prtg, choose Add sensor, Custom Sensors (NO OS SELECTION!!!), then 'EXE/Script Advanced'
echo ^<?xml version="1.0" encoding="Windows-1252" ?^>
echo ^<prtg^>
echo    ^<result^>
echo        ^<channel^>COMPUTERNAME-%COMPUTERNAME%^</channel^>
echo        ^<value^>1^</value^>
echo    ^</result^>
echo    ^<result^>
echo        ^<channel^>USERNAME-%USERNAME%^</channel^>
echo        ^<value^>2^</value^>
echo    ^</result^>
echo ^</prtg^>
