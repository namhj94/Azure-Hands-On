# Login to Azure
connect-azaccount
# Create Resource Group
new-azresourcegroup -name hjrg -l eastus
# Create Vnet
$virtualNetwork = New-AzVirtualNetwork `
  -ResourceGroupName hjrg `
  -Location EastUS `
  -Name hjvnet01 `
  -AddressPrefix 10.0.0.0/8
# Create subnet
$subnetConfig = Add-AzVirtualNetworkSubnetConfig `
  -Name hjsubnet01 `
  -AddressPrefix 10.1.0.0/16 `
  -VirtualNetwork $virtualNetwork
# Connect Vnet and Subnet
$virtualNetwork | Set-AzVirtualNetwork

# Create NSG & Adding nsg rules
New-AzNetworkSecurityGroup -Name hjnsg01 -ResourceGroupName hjrg  -Location  eastus

Get-AzNetworkSecurityGroup -Name  hjnsg01 -ResourceGroupName hjrg | 
Add-AzNetworkSecurityRuleConfig -Name RDP -Description "Allow RDP" `
-Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
-SourceAddressPrefix * -SourcePortRange * `
-DestinationAddressPrefix * -DestinationPortRange 3389 | 
Set-AzNetworkSecurityGroup


Get-AzNetworkSecurityGroup -Name  hjnsg01 -ResourceGroupName hjrg | 
Add-AzNetworkSecurityRuleConfig -Name HTTP -Description "Allow HTTP" `
-Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
-SourceAddressPrefix * -SourcePortRange * `
-DestinationAddressPrefix * -DestinationPortRange 80 | 
Set-AzNetworkSecurityGroup

Get-AzNetworkSecurityGroup -Name  hjnsg01 -ResourceGroupName hjrg | 
Add-AzNetworkSecurityRuleConfig -Name ICMP -Description "Allow ICMP" `
-Access Allow -Protocol Tcp -Direction Inbound -Priority 120 `
-SourceAddressPrefix * -SourcePortRange * `
-DestinationAddressPrefix * -DestinationPortRange * | 
Set-AzNetworkSecurityGroup

# Associate nsg to subnet
$Vnet = Get-AzVirtualNetwork -name hjvnet01 -ResourceGroupName hjrg
$nsg = Get-AzNetworkSecurityGroup -name hjnsg01 -ResourceGroupName hjrg
Set-AzVirtualNetworkSubnetConfig -Name hjsubnet01 -VirtualNetwork $Vnet -AddressPrefix 10.1.0.0/16 `
-NetworkSecurityGroup $nsg
$Vnet | Set-AzVirtualNetwork



$VMLocalAdminUser = "azureuser"
$VMLocalAdminSecurePassword = ConvertTo-SecureString  -AsPlainText -Force
$LocationName = "East US"
$ResourceGroupName = "hjrg"
$ComputerName = "hjvm01"
$VMName = "hjvm01"
$VMSize = "Standard_DS1_v2"
$Vnet = Get-AzVirtualNetwork -name hjvnet01 -ResourceGroupName hjrg

$NICName = "hjvm01nic"
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2012-R2-Datacenter' -Version latest

New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose

# Create Public LoadBalancer
$publicip = @{
    Name = 'hjpip'
    ResourceGroupName = 'hjrg'
    Location = 'eastus'
    Sku = 'Standard'
    AllocationMethod = 'static'
}
New-AzPublicIpAddress @publicip

## Place public IP created in previous steps into variable. ##
$publicIp = Get-AzPublicIpAddress -Name 'hjpip' -ResourceGroupName 'hjrg'

## Create load balancer frontend configuration and place in variable. ##
$feip = New-AzLoadBalancerFrontendIpConfig -Name 'myFrontEnd' -PublicIpAddress $publicIp

## Create backend address pool configuration and place in variable. ##
$bepool = New-AzLoadBalancerBackendAddressPoolConfig -Name 'myBackEndPool'

## Create the health probe and place in variable. ##
$probe = @{
    Name = 'myHealthProbe'
    Protocol = 'http'
    Port = '80'
    IntervalInSeconds = '360'
    ProbeCount = '5'
    RequestPath = '/'
}
$healthprobe = New-AzLoadBalancerProbeConfig @probe

## Create the load balancer rule and place in variable. ##
$lbrule = @{
    Name = 'myHTTPRule'
    Protocol = 'tcp'
    FrontendPort = '80'
    BackendPort = '80'
    IdleTimeoutInMinutes = '15'
    FrontendIpConfiguration = $feip
    BackendAddressPool = $bePool
}
$rule = New-AzLoadBalancerRuleConfig @lbrule -EnableTcpReset -DisableOutboundSNAT

## Create the load balancer resource. ##
$loadbalancer = @{
    ResourceGroupName = 'hjrg'
    Name = 'myLoadBalancer'
    Location = 'eastus'
    Sku = 'Standard'
    FrontendIpConfiguration = $feip
    BackendAddressPool = $bePool
    LoadBalancingRule = $rule
    Probe = $healthprobe
}
New-AzLoadBalancer @loadbalancer

# Add VM to loadbalancer backend pool and Create InboundNatRule(Attach VM)
$lb = Get-AzLoadBalancer -Name "MyLoadBalancer" -ResourceGroupName "hjrg"
$lb | Add-AzLoadBalancerInboundNatRuleConfig -Name "vm01NatRule" -FrontendIPConfiguration $lb.FrontendIpConfigurations[0] -Protocol "Tcp" -FrontendPort 5000 -BackendPort 3389
$lb | Set-AzLoadBalancer

$nic = Get-AzNetworkInterface -Name "hjvm01nic" -ResourceGroupName "hjrg"
$bepool = $lb | Get-AzLoadBalancerBackendAddressPoolConfig
$NatRule = $lb | Get-AzLoadBalancerInboundNatRuleConfig

$lb = Get-AzLoadBalancer -Name "MyLoadBalancer" -ResourceGroupName "hjrg"
Set-AzNetworkInterfaceIpConfig -Name ipconfig1 -NetworkInterface $nic `
-LoadBalancerBackendAddressPool  $bepool `
-LoadBalancerInboundNatRule $NatRule

Set-AzNetworkInterface -NetworkInterface $nic