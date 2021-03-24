<#
Placeholder	        Description
%sensorid	        The ID of the EXE/Script sensor
%deviceid	        The ID of the device the sensor is created on
%groupid	        The ID of the group the sensor is created in
%probeid	        The ID of the probe the sensor is created on
%host	            The IP address/DNS name entry of the device the sensor is created on
%device	            The name of the device the sensor is created on
%group	            The name of the group the sensor is created in
%probe	            The name of the probe the sensor is created on
%name	            The name of the EXE/Script sensor
%windowsdomain	    The domain for Windows access (may be inherited from parent)
%windowsuser	    The user name for Windows access (may be inherited from parent)
%windowspassword	The password for Windows access (may be inherited from parent)
%linuxuser	        The user name for Linux access (may be inherited from parent)
%linuxpassword	    The password for Linux access (may be inherited from parent)
%snmpcommunity	    The community string for SNMP v1 or v2 (may be inherited from parent)
#>

$env:prtg_sensorid
$env:prtg_host
