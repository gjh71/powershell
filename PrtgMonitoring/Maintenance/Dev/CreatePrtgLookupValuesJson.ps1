# https://kb.paessler.com/en/topic/70609-value-interpretation-aka-lookups

<#
<?xml version="1.0" encoding="UTF-8"?>
  <ValueLookup 
        id="prtg.customlookups.apc.failcause" 
        desiredValue="1" 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xsi:noNamespaceSchemaLocation="PaeValueLookup.xsd" 
        undefinedState="Warning">
    <Lookups>
      <SingleInt state="Ok" value="1">No Events</SingleInt>
      <SingleInt state="Error" value="2">High line voltage</SingleInt>
	  <SingleInt state="Error" value="3">Brownout</SingleInt>
	  <SingleInt state="Error" value="4">Loss of mains power</SingleInt>
	  <SingleInt state="Warning" value="5">Small temporary power drop</SingleInt>
	  <SingleInt state="Error" value="6">Large temporary power drop</SingleInt>
	  <SingleInt state="Warning" value="7">Small spike</SingleInt>
	  <SingleInt state="Error" value="8">Large spike</SingleInt>
	  <SingleInt state="Ok" value="9">UPS self test</SingleInt>
	  <SingleInt state="Error" value="10">Excessive input voltage fluctuation</SingleInt>
    </Lookups>
  </ValueLookup>
#>

