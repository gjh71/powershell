pushd "C:\dev.cm\cm-cowmanager\Source\6. Databases\CowManager.Identity.DbUp\bin\Debug"
start CowManager.Identity.DbUp.exe /b /w 
popd

pushd "C:\dev.cm\cm-cowmanager\Source\6. Databases\BehaviorDetection.DbUp\bin\Debug"
start BehaviorDetection.DbUp.exe /b /w 
popd

pushd "C:\dev.cm\cm-cowmanager\Source\6. Databases\CowManager.Database.DbUp\bin\Debug"
start CowManager.Database.DbUp.exe /b /w 
popd

pause