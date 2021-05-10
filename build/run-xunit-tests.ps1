$workerdir="C:\BuildAgent.02\work\92461154517a6736"
$workerdir="C:\BuildAgent.02\work\a265cba5cbb02e4e"
$workerdir="C:\BuildAgent.01\work\a265cba5cbb02e4e"
$targetEnv = "dev"
$xunitDir = "C:\BuildAgent.01\tools\xunit-runner\bin\2.2.0"
$xunit = Get-Item -Path (Join-Path $xunitDir -ChildPath "xunit.console.exe")

$targetTest = "cowmanager.api.test"
$method = "CowManager.Api.Test.IntegrationTests.MatingsTests.Put_Valid_Mating_Returns_200_And_Mating"

"C:\BuildAgent.01\work\a265cba5cbb02e4e\Source\7. Tests\CowManager.Business.Test\bin\Debug\Agis.CowManager.Business.Test.dll"

$targetTest = "CowManager.Business.Test"
$method = "Agis.CowManager.Business.Test.IntegrationTests.CowEventPregnancyTestTests.DeletePregnancyTestEvent"
$method = "Agis.CowManager.Business.Test.IntegrationTests.CompanyTests.CreateCompany"

$targetdll = "{0}\source\7. tests\{1}\bin\{2}\Agis.{1}.dll" -f $workerdir, $targetTest, $targetEnv
Write-Host ("Targetdll: {0}`nMethod: {1}" -f $targetdll, $method) -ForegroundColor Green
. ($xunit.FullName) $targetdll -method $method


$class = "Agis.CowManager.Business.Test.IntegrationTests.CowEventHormoneTreatmentTests"
$class = "Agis.CowManager.Business.Test.IntegrationTests.CowEventHormoneTreatmentTests"
$method = "{0}.DeleteHormoneTreatmentEvent" -f $class

$targetTest = "CowManager.Api.Test"
$targetdll = "{0}\source\7. tests\{1}\bin\{2}\{1}.dll" -f $workerdir, $targetTest, $targetEnv
$class = "CowManager.Api.Test.IntegrationTests.PrivateControllers.CompanyInfoTests"
$method = "{0}.Get_CompanyInfo_Returns_200_And_CompanyInfo" -f $class
Write-Host ("Targetdll: {0}`nMethod: {1}" -f $targetdll, $method) -ForegroundColor Green
. ($xunit.FullName) $targetdll -method $method
. ($xunit.FullName) $targetdll -class $class

#             C:\BuildAgent.02\work\a265cba5cbb02e4e\source\device\cowmanager.device.api.test\bin\dev\CowManager.Device.Api.Test.dll
$targetdll = "C:\BuildAgent.02\work\a265cba5cbb02e4e\Source\Device\CowManager.Device.Api.Test\bin\Dev\CowManager.Device.Api.Test.dll"
$class = "CowManager.Device.Api.Test.Devices.DevicesPerformanceTests"
$method = "Get_Devices_Returns_200_With_DeviceInfoDtoArray"
$target = "{0}.{1}" -f $class, $method
$target = "{0}" -f $class, $method
. ($xunit.FullName) $targetdll -class $target


$targetTest = "CowManager.Api.Test"
$targetdll = "{0}\source\7. tests\{1}\bin\{2}\{1}.dll" -f $workerdir, $targetTest, $targetEnv

$namespace = "CowManager.Api.Test.IntegrationTests"
$class = "CompaniesTests"
$method = "{0}.Get_CompanyInfo_Returns_200_And_CompanyInfo" -f $class
$method = "Get_Companies_Returns_200_With_CompaniesDto"

$target = "{0}.{1}.{2}" -f $namespace, $class, $method
Write-Host ("Targetdll: {0}`nMethod: {1}" -f $targetdll, $target) -ForegroundColor Green
. ($xunit.FullName) $targetdll -method $target

$namespace = "CowManager.Api.Test.IntegrationTests.PrivateControllers"
$class = "OtapTests"
$method = "Put_Status_Shutdowned_Returns_Ok"

$target = "{0}.{1}.{2}" -f $namespace, $class, $method
Write-Host ("Targetdll: {0}`nMethod: {1}" -f $targetdll, $target) -ForegroundColor Green
. ($xunit.FullName) $targetdll -method $target