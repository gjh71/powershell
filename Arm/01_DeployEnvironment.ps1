#xrequires -modules az
<#
.SYNOPSIS
  This script will generate a full cowmanager infrastructure
.DESCRIPTION
  The script is using the powershell module 'az' to create the infrastructure. ARM templates are not used.
  A resource group and network components are created. Then based on the used switches the servers are created.
  After all servers have been created, they are automatically 'configured'. That is, windows features are installed and configuration is done.
.PARAMETER subscriptionid
  Azure subscriptionid : 3cce63cc-7694-47ff-aeac-6d62305d0f64 = csp
.PARAMETER environment
  Environment-name with versioning. This is the name that will be used as name for the resourcegroup
  e.g. test-047-02
.PARAMETER envShortName
  Short name for the environment, max 4 chars. 
  e.g. test
.PARAMETER DeployAllServers
  Use this switch to deploy all servertypes. All servertypes will be deployed.
.PARAMETER DeployDatabaseServer
  Deploy a database server. Network, resourcegroup etc, will be created
  Can be combined with other 'DeployServer-switches'
.PARAMETER nrOfDatabaseServers
  Default 1. But if you want mirroring, you want more...
.PARAMETER enableDirectSqlAccess
  Adds a firewall exception so sql-queries are allowed from harmelen office
.PARAMETER DeployRedisServer
  Deploy a redis server. Network, resourcegroup etc, will be created
  Can be combined with other 'DeployServer-switches'
.PARAMETER DeployWebServer
  Deploy webserver(s). Network, resourcegroup etc, will be created
  Can be combined with other 'DeployServer-switches'
.PARAMETER nrOfFrontEndServers
  Nr of webservers that will be deployed. Default is 1
.PARAMETER DeployDeviceWebServer
  Deploy device-webserver(s). Network, resourcegroup etc, will be created
  Can be combined with other 'DeployServer-switches'
.PARAMETER nrOfDeviceWebServers
  Nr of device-webservers that will be deployed. Default is 1
.PARAMETER DeployAppServer
  Deploy an application server. Network, resourcegroup etc, will be created
  Can be combined with other 'DeployServer-switches'
.PARAMETER nrOfAppServers
  Nr of application-servers that will be deployed. Default is 1
.PARAMETER UsePremiumStorage
  Default is to use 'Standard' storage as this is much cheaper. For production usage this switch should be added
.EXAMPLE
  Create a test environment, with only 1 web and 1 app server: 
  c:\repos\cm-powershell\util\server\arm>.\01_DeployEnvironment.ps1 -subscriptionId "3cce63cc-7694-47ff-aeac-6d62305d0f64" -environment "test-47-02" -envShortName "test" -DeployDatabaseServer -enableDirectSqlAccess -DeployWebServer -DeployAppServer

  Create production environment: 
  c:\repos\cm-powershell\util\server\arm>.\01_DeployEnvironment.ps1 -subscriptionId "3cce63cc-7694-47ff-aeac-6d62305d0f64" -environment "production-47-02" -envShortName "prod" -DeployAllServers -enableDirectSqlAccess -nrOfFrontEndServers 2 -nrOfDeviceWebServers 2 -UsePremiumStorage
.NOTES

#>
param(
  [Parameter(Mandatory=$true)]
  [string]$subscriptionId,
  [Parameter(Mandatory=$true)]
  [string]$environment,
  [Parameter(Mandatory=$true)]
  [string]$envShortName,
  [switch]$DeployAllServers,
  [switch]$DeployDatabaseServer,
  [int]$nrOfDatabaseServers = 1,
  [switch]$enableDirectSqlAccess,
  [switch]$DeployRedisServer,
  [switch]$DeployWebServer,
  [int]$nrOfFrontEndServers = 1,
  [switch]$DeployDeviceWebServer,
  [int]$nrOfDeviceWebServers = 1,
  [switch]$DeployAppServer,
  [int]$nrOfAppServers = 1,
  [switch]$UsePremiumStorage,
  [Parameter(Mandatory=$true)]
  [string]$youtrack
)
$timeStart = Get-Date
Write-Host("{0:dd-MM-yyyy HH:mm:ss}: Deployment started " -f (Get-Date)) -ForegroundColor Yellow
import-module az

# regions: functions, main

#region functions
Function New-ResourceGroup {
  Param(
    [String] $Name
  )

  $location = "West Europe"
  $tags = @{
    category    = "cowmanager-vm"
    environment = $environment
    owner       = $owner
    youtrack    = $youtrack
  }
  return New-AzResourceGroup -Name $Name -Location $location -Tag $tags -Force
}

Function New-Credential {
  $username = "adm_$environmentShortName"
  $password = ConvertTo-SecureString "Pass1Word!" -AsPlainText -Force
  return New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)
}

Function New-CredentialLinux {
  $username = "adm_$environmentShortName"
  $password = ConvertTo-SecureString "Pass1Word!Pass1Word!" -AsPlainText -Force
  return New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)
}

Function New-VNet {
  Param(
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] $ResourceGroup,
    [bool] $enableDirectSqlAccess
  )
  Write-Host("Start New-VNet") -ForegroundColor Yellow

  $ipAddressHarmelen = "62.132.200.5"

  # The cmdlet below gives warnings about breaking changes. Suppress these warnings.
  Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

  # Create a virtual network with subnets.
  $bastionSubnet = New-AzVirtualNetworkSubnetConfig -Name 'AzureBastionSubnet' -AddressPrefix 10.0.0.0/24
  Write-Host("Created: {0}" -f $bastionSubnet.Name) -ForegroundColor Yellow
  $frontEndSubnet = New-AzVirtualNetworkSubnetConfig -Name 'frontend-subnet' -AddressPrefix 10.0.1.0/24
  Write-Host("Created: {0}" -f $frontEndSubnet.Name) -ForegroundColor Yellow
  $backEndSubnet = New-AzVirtualNetworkSubnetConfig -Name 'backend-subnet' -AddressPrefix 10.0.2.0/24
  Write-Host("Created: {0}" -f $backEndSubnet.Name) -ForegroundColor Yellow

  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "cm-{0}-vnet" -f $environmentShortName
    AddressPrefix = "10.0.0.0/16"
    Subnet = ($bastionSubnet, $frontEndSubnet, $backEndSubnet)
  }
  $vnet = New-AzVirtualNetwork -Force @stmtargs
  Write-Host("Created: {0}" -f $vnet.Name) -ForegroundColor Yellow

  $stmtargs = @{
    name = "cm-bastion-{0}-ip" -f $environmentShortName
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    AllocationMethod = "Static"
    Sku = "Standard" 
    DomainNameLabel = "cm-bastion-{0}" -f $environmentShortName
  }
  $publicIpBastion = New-AzPublicIpAddress -Force @stmtargs
  Write-Host("Created: {0}" -f $publicIpBastion.Name) -ForegroundColor Yellow
  
  # New-AzBastion does not yet support the -Force parameter to create or update the resource,
  # therefore we check if the resource already exists.
  $bastion = Get-AzBastion -Name "cm-$environmentShortName-bt" -ResourceGroupName $ResourceGroup.ResourceGroupName -ErrorAction SilentlyContinue
  if (!$bastion) {
    $stmtargs = @{
      Name = "cm-bastion-{0}-bt" -f $environmentShortName
      ResourceGroupName = $ResourceGroup.ResourceGroupName
      PublicIpAddress = $publicIpBastion
      VirtualNetwork = $vnet
    }
    $bastion = New-AzBastion @stmtargs
    Write-Host "Bastion host $($bastion.Name) created" -ForegroundColor Yellow
  } 
  else {
    Write-Host "Bastion host $($bastion.Name) already exists" -ForegroundColor Yellow
  }

  $ruleset = @()
  # Create an NSG rule to allow HTTP traffic in from the Internet to the front-end subnet.
  $stmtargs = @{
    Name = "Allow-HTTP-All"
    Description = "Allow HTTP"
    Access = "Allow"
    Protocol = "Tcp"
    Direction = "Inbound"
    Priority = 100
    SourceAddressPrefix = "Internet"
    SourcePortRange = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange = "80"
  }
  $rule = New-AzNetworkSecurityRuleConfig @stmtargs
  Write-Host("Created: {0}" -f $rule.Name) -ForegroundColor Yellow
  $ruleset += $rule

  # Create an NSG rule to allow HTTPS traffic from the Internet to the front-end subnet.
  $stmtargs = @{
    Name = "Allow-HTTPS-All"
    Description = "Allow HTTPS"
    Access = "Allow"
    Protocol = "Tcp"
    Direction = "Inbound"
    Priority = 200
    SourceAddressPrefix = "Internet"
    SourcePortRange = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange = "443"
  }
  $rule = New-AzNetworkSecurityRuleConfig @stmtargs
  Write-Host("Created: {0}" -f $rule.Name) -ForegroundColor Yellow
  $ruleset += $rule

  # Create nsg-rule for octopus
  $stmtargs = @{
    Name = "Allow-Octopus"
    Description = "Allow Octopus from Office"
    Access = "Allow"
    Protocol = "Tcp"
    Direction = "Inbound"
    Priority = 101
    SourceAddressPrefix = $ipAddressHarmelen
    SourcePortRange = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange = "10933"
  }
  $rule = New-AzNetworkSecurityRuleConfig @stmtargs
  Write-Host("Created: {0}" -f $rule.Name) -ForegroundColor Yellow
  $ruleset += $rule
  
  # Create a network security group for the front-end subnet.
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "cm-frontend-{0}-nsg" -f $environmentShortName
    SecurityRules = $ruleset
  }
  $nsgFrontEnd = New-AzNetworkSecurityGroup -force @stmtargs
  Write-Host("Created: {0}" -f $nsgFrontEnd.Name) -ForegroundColor Yellow

  # Associate the front-end NSG to the front-end subnet
  Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'frontend-subnet' -AddressPrefix '10.0.1.0/24' -NetworkSecurityGroup $nsgFrontEnd
  Write-Host("Associated: {1} to {0}" -f $vnet.Name, $nsgFrontEnd.Name) -ForegroundColor Yellow

  $ruleset = @()
  # Create an NSG rule to allow SQL traffic from the front-end subnet to the back-end subnet.
  $stmtargs = @{
    Name = "Allow-SQL-FrontEnd"
    Description = "Allow SQL on port 1433"
    Access = "Allow"
    Protocol = "Tcp"
    Direction = "Inbound"
    Priority = 100
    SourceAddressPrefix = "10.0.1.0/24"
    SourcePortRange = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange = "1433"
  }
  if ($enableDirectSqlAccess){
    $stmtargs.SourceAddressPrefix = @($stmtargs.SourceAddressPrefix, $ipAddressHarmelen)
  }
  $rule = New-AzNetworkSecurityRuleConfig @stmtargs
  Write-Host("Created: {0}" -f $rule.Name) -ForegroundColor Yellow
  $ruleset += $rule

  # Create nsg-rule for octopus
  $stmtargs = @{
    Name = "Allow-Octopus"
    Description = "Allow Octopus from Office"
    Access = "Allow"
    Protocol = "Tcp"
    Direction = "Inbound"
    Priority = 101
    SourceAddressPrefix = $ipAddressHarmelen
    SourcePortRange = "*"
    DestinationAddressPrefix = "*"
    DestinationPortRange = "10933"
  }
  $rule = New-AzNetworkSecurityRuleConfig @stmtargs
  Write-Host("Created: {0}" -f $rule.Name) -ForegroundColor Yellow
  $ruleset += $rule
  
  # Create a network security group for back-end subnet.
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "cm-backend-{0}-nsg" -f $environmentShortName
    SecurityRules = $ruleset
  }
  $nsgBackEnd = New-AzNetworkSecurityGroup -Force @stmtargs
  Write-Host("Created: {0}" -f $nsgBackEnd.Name) -ForegroundColor Yellow

  # Associate the back-end NSG to the back-end subnet
  Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name 'backend-subnet' -AddressPrefix '10.0.2.0/24' -NetworkSecurityGroup $nsgBackEnd
  Write-Host("Associated: {1} to {0}" -f $vnet.Name, $nsgBackEnd.Name) -ForegroundColor Yellow

  $vnet | Set-AzVirtualNetwork
  Write-Host("Write modified state back to service of {0}" -f $vnet.Name) -ForegroundColor Yellow

  Write-Host("New-VNet ready") -ForegroundColor Yellow
  $vnet
}

function New-LoadBalancer{
  Param(
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] $ResourceGroup,
    [PSCredential] $Credential,
    $name, 
    $Vnet,
    $subnet,
    $nsg
  )
  Write-Host("New-Loadbalancer start") -ForegroundColor Yellow
 
  # Create a public IP address for the load-balancer
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "{0}-ip" -f $name
    AllocationMethod = "Dynamic"
    DomainNameLabel = $name
  }
  $publicIp = New-AzPublicIpAddress -Force @stmtargs
  Write-Host("Created: {0}" -f $stmtargs.Name) -ForegroundColor Yellow

  $stmtargs = @{
    Name = "lb-frontend-ip"
    PublicIpAddress = $publicIp
  }
  $feip = New-AzLoadBalancerFrontendIpConfig @stmtargs
  Write-Host("Created: {0}" -f $stmtargs.Name) -ForegroundColor Yellow

  $stmtargs = @{
    Name = "lb-backend-addresspool-config"
  }
  $bepool = New-AzLoadBalancerBackendAddressPoolConfig @stmtargs
  Write-Host("Created: {0}" -f $stmtargs.Name) -ForegroundColor Yellow

  $stmtargs = @{
    Name = "lb-healthprobe-80-config"
    Protocol = "Http"
    Port = 80
    RequestPath = "/"
    IntervalInSeconds = 360
    ProbeCount = 5
  }
  $probe = New-AzLoadBalancerProbeConfig @stmtargs
  Write-Host("Created: {0}" -f $stmtargs.Name) -ForegroundColor Yellow

  $stmtargs = @{
    Name = "lb-rulehttp"
    Protocol = "Tcp"
    Probe = $probe
    FrontendPort = 80
    BackendPort = 80
    FrontendIpConfiguration = $feip
    BackendAddressPool = $bepool
  }
  $rule = New-AzLoadBalancerRuleConfig @stmtargs
  Write-Host("Created: {0}" -f $stmtargs.Name, $rule.Name) -ForegroundColor Yellow

  $stmtargs = @{
    Name = "lb-rulehttps"
    Protocol = "Tcp"
    Probe = $probe
    FrontendPort = 443
    BackendPort = 443
    FrontendIpConfiguration = $feip
    BackendAddressPool = $bepool
  }
  $rule = New-AzLoadBalancerRuleConfig @stmtargs
  Write-Host("Created: {0}" -f $stmtargs.Name) -ForegroundColor Yellow

  $stmtargs = @{
    ResourceGroupName = $resourceGroupName
    Name = "{0}-as" -f $resourceGroupName
    Location = $ResourceGroup.Location
    Sku = "Aligned"
    PlatformFaultDomainCount = 3
    PlatformUpdateDomainCount = 3
  }
  $as = New-AzAvailabilitySet @stmtargs
  Write-Host("Created: {0}" -f $stmtargs.Name) -ForegroundColor Yellow

  $subnetFrontend = $vnet.Subnets | Where-Object {$_.name -eq "frontend-subnet"}| Select-Object -First 1
  $stmtargs = @{
    ResourceGroupName = $resourceGroupName
    Name = "cm-redis01-{0}-rc" -f $resourceGroupName
    Location = $ResourceGroup.Location
    Sku = "Standard" #must be premium
    EnableNonSslPort = $true
    SubnetId = $subnetFrontend.Id #should be only for redis caches
  }
  #$rc = New-AzRedisCache @stmtargs
  Write-Host("SKIPPED: Created: {0}" -f $stmtargs.Name) -ForegroundColor Yellow

  $stmtargs = @{
    ResourceGroupName = $resourceGroupName
    Name = $name
    Location = $ResourceGroup.Location
    FrontendIpConfiguration = $feip
    BackendAddressPool = $bepool
    Probe = $probe
    LoadBalancingRule = $lbrule
    InboundNatRule = @()
  }
  $lb = New-AzLoadBalancer @stmtargs -Force
  Write-Host("Created: {0}" -f $stmtargs.Name) -ForegroundColor Yellow
  
  $rv =@{
    LoadBalancer = $lb
    FrontendIp = $feip
    BackendPool = $bepool
    AvailabilitysetID = $as.ID
  }

  $rv
}

Function New-WebServer {
  Param(
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] $ResourceGroup,
    [PSCredential] $Credential,
    $Vnet,
    [Parameter(Mandatory=$true)]
    [string]$serverName,
    $serverNr,
    $subnet,
    $loadBalancer,
    $frontendIp,
    $backendPool,
    $availabilitysetID
  )
  Write-Host("New-WebServer start") -ForegroundColor Yellow
 
  # Create a NAT-rule for the VM
  $stmtargs = @{
    Name = "LB-rule-Octopus-{0}" -f $serverName
    FrontendIpConfiguration = $frontendIp
    Protocol = "Tcp"
    FrontendPort = "1{0}933" -f $serverNr
    BackendPort = 10933
  }
  $natrule = New-AzLoadBalancerInboundNatRuleConfig @stmtargs
  $LoadBalancer.InboundNatRules.add([Microsoft.Azure.Commands.Network.Models.PSInboundNatRule]$natrule)
  $LoadBalancer | Set-AzLoadBalancer | Out-Null
  Write-Host("Created: {0}" -f $natrule.Name) -ForegroundColor Yellow

  # Create a NIC for the VM 
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "{0}-nic" -f $servername
    LoadBalancerBackendAddressPool = $backendPool
    LoadBalancerInboundNatRule = $natrule
    Subnet = $subnet
  }
  $nic = New-AzNetworkInterface -Force @stmtargs
  Write-Host("Created: {0}" -f $nic.Name) -ForegroundColor Yellow

    # Create a web server VM 
  $vmName = "$servername-vm" 
  $diskCName = "$servername-C-disk"
  $diskSName = "$servername-S-disk"
  $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $sizeWebServer -AvailabilitySetID $availabilitysetId | `
    Set-AzVMOperatingSystem -Windows -ComputerName $servername -Credential $Credential | `
    Set-AzVMSourceImage -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest | `
    Set-AzVMBootDiagnostic -Disable | `
    Set-AzVMOSDisk -Name $diskCName -DiskSizeInGB 127 -CreateOption FromImage -Caching ReadWrite -StorageAccountType $STORAGEACCOUNTTYPE | `
    Add-AzVMDataDisk -Name $diskSName -DiskSizeInGB 100 -Lun 0 -CreateOption Empty -Caching ReadOnly -StorageAccountType $STORAGEACCOUNTTYPE | `
    Add-AzVMNetworkInterface -Id $nic.Id
  Write-Host("Config set: {0}" -f $vmconfig.VMName) -ForegroundColor Yellow

  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    VM = $vmConfig 
  }
  $vm = New-AzVM @stmtargs
  Write-Host("Created VM: {0}" -f $vmName) -ForegroundColor Yellow

  $vm
}

Function New-DeviceWebServer {
  Param(
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] $ResourceGroup,
    [PSCredential] $Credential,
    [Parameter(Mandatory=$true)]
    [string]$serverName,
    $subnet,
    $nsg
  )
 
  # Create a public IP address for the server VM
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "{0}-ip" -f $servername
    AllocationMethod = "Dynamic"
    DomainNameLabel = $servername
  }
  $publicIp = New-AzPublicIpAddress -Force @stmtargs

  # Create a NIC for the VM
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "{0}-nic" -f $servername
    PublicIpAddress = $publicIp 
    Subnet = $subnet
  }
  $nic = New-AzNetworkInterface -Force @stmtargs
  Write-Host("Created: {0}" -f $nic.Name) -ForegroundColor Yellow

  $vmName = "$servername-vm" 
  $diskCName = "$servername-C-disk"
  $diskSName = "$servername-S-disk"
  $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $sizeDeviceWebServer | `
    Set-AzVMOperatingSystem -Windows -ComputerName $servername -Credential $Credential | `
    Set-AzVMSourceImage -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest | `
    Set-AzVMBootDiagnostic -Disable | `
    Set-AzVMOSDisk -Name $diskCName -DiskSizeInGB 127 -CreateOption FromImage -Caching ReadWrite -StorageAccountType $STORAGEACCOUNTTYPE | `
    Add-AzVMDataDisk -Name $diskSName -DiskSizeInGB 100 -Lun 0 -CreateOption Empty -Caching ReadOnly -StorageAccountType $STORAGEACCOUNTTYPE | `
    Add-AzVMNetworkInterface -Id $nic.Id
  Write-Host("Config set: {0}" -f $vmconfig.VMName) -ForegroundColor Yellow

  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    VM = $vmConfig 
  }
  $vm = New-AzVM @stmtargs
  Write-Host("Created VM: {0}" -f $vmName) -ForegroundColor Yellow

  $vm
}
Function New-RedisServer {
  Param(
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] $ResourceGroup,
    [PSCredential] $Credential,
    $subnet,
    $nsg
  )
 
  $servername = "cm-redis01-$environmentShortName"

  # # Create a public IP address for the server VM
  # $stmtargs = @{
  #   ResourceGroupName = $ResourceGroup.ResourceGroupName 
  #   Location = $ResourceGroup.Location
  #   Name = "{0}-ip" -f $servername
  #   AllocationMethod = "Dynamic"
  #   DomainNameLabel = $servername
  # }
  # $publicIp = New-AzPublicIpAddress -Force @stmtargs

  # Create a NIC for the VM
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "{0}-nic" -f $servername
    # PublicIpAddress = $publicIp 
    Subnet = $subnet
  }
  $nic = New-AzNetworkInterface -Force @stmtargs
  Write-Host("Created: {0}" -f $nic.Name) -ForegroundColor Yellow

  $vmName = "$servername-vm" 
  $diskCName = "$servername-C-disk"

  $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $sizeRedisServer | `
    Set-AzVMOperatingSystem `
      -Linux `
      -ComputerName $servername `
      -Credential $Credential | `
    Set-AzVMSourceImage `
      -PublisherName 'cognosys' `
      -Offer 'redis-with-ubuntu-1404-lts' `
      -Skus 'redis-with-ubuntu-1404-lts' `
      -Version latest | `
    Set-AzVMBootDiagnostic -Disable | `
    Set-AzVMOSDisk `
      -Name $diskCName `
      -CreateOption FromImage `
      -Caching ReadWrite `
      -StorageAccountType Standard_LRS | `
    Add-AzVMNetworkInterface -Id $nic.Id
  Write-Host("Config set: {0}" -f $vmconfig.VMName) -ForegroundColor Yellow

  Set-AzVMPlan -VM $vmConfig -Publisher "cognosys" -Product "redis-with-ubuntu-1404-lts" -Name "redis-with-ubuntu-1404-lts"
  
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    VM = $vmConfig 
  }
  $vm = New-AzVM @stmtargs
  Write-Host("Created VM: {0}" -f $vmName) -ForegroundColor Yellow

  $vm
}

Function New-DatabaseServer {
  Param(
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] $ResourceGroup,
    [PSCredential] $Credential,
    [Parameter(Mandatory = $true)]
    [string]$serverName,
    $subnet,
    $nsg,
    [bool] $enableDirectSqlAccess
  )

  $publicIp = $null
  if ($enableDirectSqlAccess){
    # Create a public IP address for the server VM
    $stmtargs = @{
      ResourceGroupName = $ResourceGroup.ResourceGroupName 
      Location = $ResourceGroup.Location
      Name = "{0}-ip" -f $servername
      AllocationMethod = "Dynamic"
      DomainNameLabel = $servername
    }
    $publicIp = New-AzPublicIpAddress -Force @stmtargs
  }

    # Create a NIC for VM
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "{0}-nic" -f $servername
    PublicIpAddress = $publicIp 
    Subnet = $subnet
  }
  $nic = New-AzNetworkInterface -Force @stmtargs
  Write-Host("Created: {0}" -f $nic.Name) -ForegroundColor Yellow

  # Create a database server VM.
  $vmName = "$servername-vm"
  $diskCName = "$servername-C-disk"
  $diskLName = "$servername-L-disk"
  $diskSName = "$servername-S-disk"
  $sqlImagePublisher = "MicrosoftSQLServer"
  $sqlImageVersion = "latest"
  $sqlImageOffer = "SQL2016SP2-WS2016"
  $sqlImageSkus = "SQLDEV"
  if (($vmName -like "*-db03-*") -or ($vmName -like "*-db04-*")){
    $sqlImageOffer = "sql2019-ws2019"
    $sqlImageSkus = "enterprisedbengineonly"
  }
  Write-host("Image selected: {0}" -f $sqlImageOffer) -ForegroundColor Yellow
  
  $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $sizeDbServer 
  $vmConfig = $vmConfig | Set-AzVMOperatingSystem -Windows -ComputerName $servername -Credential $Credential
  $vmConfig = $vmConfig | Set-AzVMSourceImage -PublisherName $sqlImagePublisher -Offer $sqlImageOffer -Skus $sqlImageSkus -Version $sqlImageVersion 
  $vmConfig = $vmConfig | Set-AzVMBootDiagnostic -Disable
  $vmConfig = $vmConfig | Set-AzVMOSDisk -Name $diskCName -DiskSizeInGB 127 -CreateOption FromImage -Caching ReadWrite -StorageAccountType $STORAGEACCOUNTTYPE
  $vmConfig = $vmConfig | Add-AzVMDataDisk -Name $diskLName -DiskSizeInGB 40 -Lun 1 -CreateOption Empty -Caching ReadOnly -StorageAccountType $STORAGEACCOUNTTYPE
  $vmConfig = $vmConfig | Add-AzVMDataDisk -Name $diskSName -DiskSizeInGB 200 -Lun 0 -CreateOption Empty -Caching ReadOnly -StorageAccountType $STORAGEACCOUNTTYPE
  $vmConfig = $vmConfig | Add-AzVMNetworkInterface -Id $nic.Id
  Write-Host("Config set: {0}" -f $vmconfig.Name) -ForegroundColor Yellow

  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    VM = $vmConfig 
  }
  $vm = New-AzVM @stmtargs
  Write-Host("Created VM: {0}" -f $vmName) -ForegroundColor Yellow

  $vm
}

Function New-AppServer {
  Param(
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup] $ResourceGroup,
    [PSCredential] $Credential,
    $serverName,
    $subnet,
    $nsg
  )

  # Create a public IP address for the server VM
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "{0}-ip" -f $servername
    AllocationMethod = "Dynamic"
    DomainNameLabel = $servername
  }
  $publicIp = New-AzPublicIpAddress -Force @stmtargs

  # Create a NIC for the VM
  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    Name = "{0}-nic" -f $servername
    PublicIpAddress = $publicIp 
    Subnet = $subnet
  }
  $nic = New-AzNetworkInterface -Force @stmtargs
  Write-Host("Created: {0}" -f $nic.Name) -ForegroundColor Yellow

  #$nic.NetworkSecurityGroup = $nsg
  #$nic | Set-AzNetworkInterface | Out-Null
  Write-Host("NOT Attached: {0} to {1}" -f $nsg.name, $nic.Name) -ForegroundColor Yellow

  $vmName = "$servername-vm"
  $diskCName = "$servername-C-disk"
  $diskSName = "$servername-S-disk"
  $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $sizeAppServer | `
    Set-AzVMOperatingSystem -Windows -ComputerName $servername -Credential $Credential | `
    Set-AzVMSourceImage -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest | `
    Set-AzVMBootDiagnostic -Disable | `
    Set-AzVMOSDisk -Name $diskCName -DiskSizeInGB 127 -CreateOption FromImage -Caching ReadWrite -StorageAccountType $STORAGEACCOUNTTYPE | `
    Add-AzVMDataDisk -Name $diskSName -DiskSizeInGB 100 -Lun 0 -CreateOption Empty -Caching ReadOnly -StorageAccountType $STORAGEACCOUNTTYPE | `
    Add-AzVMNetworkInterface -Id $nic.Id
  Write-Host("Config set: {0}" -f $vmconfig.VMName) -ForegroundColor Yellow

  $stmtargs = @{
    ResourceGroupName = $ResourceGroup.ResourceGroupName 
    Location = $ResourceGroup.Location
    VM = $vmConfig 
  }
  $vm = New-AzVM @stmtargs
  Write-Host("Created VM: {0}" -f $vmName) -ForegroundColor Yellow

  $vm
}
#endregion

#region main

if ($DeployAllServers){
  $DeployDatabaseServer = $true
  $DeployWebServer = $true
  $DeployDeviceWebServer = $true
  $DeployAppServer = $true
  $DeployRedisServer = $true
}

$owner = "{0}@cowmanager.com" -f $env:USERNAME
$environmentShortName = $environment
if ($environmentShortName.Length -gt 4){
  if ($envShortName -ne "" -and $null -ne $envShortName){
    $environmentShortName = $envShortName
  }
}

Select-AzSubscription -SubscriptionId $subscriptionId

# Global variables
$sizeWebServer = "Standard_DS2_v2"
$sizeDeviceWebServer = "Standard_DS2_v2"
$sizeRedisServer = "Basic_A0"
$sizeAppServer = "Standard_DS2_v2"
$sizeDbServer = "Standard_DS2_v2"
$STORAGEACCOUNTTYPE = "Standard_LRS"
if ($UsePremiumStorage){
  $STORAGEACCOUNTTYPE = "Premium_LRS"
}

$credential = New-Credential

$resourceGroupName = "cm-{0}-rg" -f $environment
$resourceGroup = New-ResourceGroup -Name $resourceGroupName
Write-Host "Resource group created: $($resourceGroup.ResourceGroupName)" -ForegroundColor Yellow

$vnet = New-VNet -ResourceGroup $resourceGroup -enableDirectSqlAccess $enableDirectSqlAccess
$subnetFrontend = $vnet.Subnets | Where-Object {$_.name -eq "frontend-subnet"}| Select-Object -First 1
$subnetBackend = $vnet.Subnets | Where-Object {$_.name -eq "backend-subnet"}| Select-Object -First 1
$nsgs = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName
$nsgFrontend = $nsgs | Where-Object {$_.name -like "cm-frontend-*-nsg"}
$nsgBackend = $nsgs | Where-Object {$_.name -like "cm-backend-*-nsg"}

if ($DeployDatabaseServer){
  1..$nrOfDatabaseServers | ForEach-Object {
    $stmtargs = @{
      ResourceGroup         = $resourceGroup 
      Credential            = $credential 
      serverName            = "cm-db{1:00}-{0}" -f $environmentShortName, $_
      subnet                = $subnetBackend 
      nsg                   = $nsgBackend 
      enableDirectSqlAccess = $enableDirectSqlAccess
    } 
    Write-Host("Start creation of: {0}" -f $stmtargs.serverName)
    New-DatabaseServer @stmtargs
  }
}
if ($DeployWebServer){
  $lbname = "cm-lb01-{0}" -f $environmentShortName
  Write-Host "Creating load balancer..." -ForegroundColor Yellow
  $lbConf = New-LoadBalancer -ResourceGroup $ResourceGroup -Name $lbname -Vnet $vnet -subnet $subnetFrontend -nsg $nsgFrontend

  1..$nrOfFrontEndServers | ForEach-Object {
    $stmtargs = @{
      ResourceGroup     = $resourceGroup 
      VNet              = $vnet 
      serverName        = "cm-web{1:00}-{0}" -f $environmentShortName, $_
      serverNr          = $loopNr 
      Credential        = $credential 
      subnet            = $subnetFrontend 
      LoadBalancer      = $lbconf.LoadBalancer 
      frontendIp        = $lbconf.FrontendIp 
      backendPool       = $lbconf.BackendPool
      availabilitysetId = $lbconf.AvailabilitysetId
    }
    Write-Host("Start creation of: {0}" -f $stmtargs.serverName)
    New-WebServer @stmtargs
  }
}

if ($DeployDeviceWebServer){
  1..$nrOfDeviceWebServers | ForEach-Object {
    $stmtargs = @{
      ResourceGroup = $resourceGroup 
      Credential    = $credential 
      servername    = "cm-dw{1:00}-{0}" -f $environmentShortName, $_
      subnet        = $subnetBackend 
      nsg           = $nsgBackend  
    } 
    Write-Host("Start creation of: {0}" -f $stmtargs.serverName)
    New-DeviceWebServer @stmtargs
  }
}
if ($DeployAppServer){
  1..$nrOfAppServers | ForEach-Object {
    $stmtargs = @{
      ResourceGroup = $resourceGroup 
      Credential    = $credential 
      servername    = "cm-app{1:00}-{0}" -f $environmentShortName, $loopNr
      subnet        = $subnetBackend 
      nsg           = $nsgBackend  
    } 
    Write-Host("Start creation of: {0}" -f $stmtargs.serverName)
    New-AppServer @stmtargs
  }
}
if ($DeployRedisServer){
  Write-Host "Creating redis server..." -ForegroundColor Yellow
  $cred = New-CredentialLinux
  New-RedisServer -ResourceGroup $resourceGroup -VNet $vnet -Credential $cred -subnet $subnetBackend -nsg $nsgBackend
}

Write-Host "All servers created" -ForegroundColor Yellow

# Initialize the servers
$vms = Get-AzVM -ResourceGroupName $ResourceGroup.ResourceGroupName #-Name $vmName  
$jobs = @{}
$initialiseScript = join-path $PSScriptRoot -ChildPath "..\install\Initialise-server.ps1"
Foreach ($vm in $vms) {
  Write-Host "Initializing server $($vm.Name)..." -ForegroundColor Yellow

  $job = Invoke-AzVMRunCommand -CommandId RunPowerShellScript -VM $vm -ScriptPath $initialiseScript -AsJob
  Write-Host ("Created job: {0}" -f $job.id) -ForegroundColor Yellow
  $jobs.Add($vm.Name, $job.id)
}
Write-Host ("{0:HH:mm:ss} Init-jobs started. Waiting for all to finish" -f (Get-Date)) -ForegroundColor Yellow
Write-Host ("Note: if this is aborted, the job results are not written to files!")
$cnt = (Get-Job | Where-Object {$_.State -eq "Running"}).Length
while ($cnt -gt 0) {
  Write-Host ("{0:HH:mm:ss} ... Waiting for {1} job(s) to finish" -f (Get-Date), $cnt) -ForegroundColor Yellow
  Start-Sleep -Seconds 30
  $cnt = (Get-Job | Where-Object {$_.State -eq "Running"}).Length
}

foreach ($job in Get-Job | Where-Object {$_.state -eq "Completed" -and $_.HasMoreData -eq $true} ){
  $lognm = Join-Path $PSScriptRoot -ChildPath ("{0}-job{1:000}-result.log" -f $envShortName, $job.Id)
  $job | Receive-Job | Out-File -FilePath $lognm
  Write-Host("Logfile {0} was created. Please verify that output." -f $lognm) -ForegroundColor Yellow
}

$timeReady = Get-Date
$ts = New-TimeSpan -Start $timeStart -End $timeReady
Write-Host("{0:dd-MM-yyyy HH:mm:ss}: Deployment ready in {1}m{2:00}s " -f (Get-Date), [Math]::Truncate($ts.TotalMinutes), $ts.Seconds) -ForegroundColor Cyan
#endregion