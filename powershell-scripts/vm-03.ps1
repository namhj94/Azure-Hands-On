#--public-ip-address
# Name of the public IP address when creating one (default) or referencing an existing one. 
# Can also reference an existing public IP by ID or specify "" for None ('""' in Azure CLI using PowerShell or --% operator).

az vm availability-set create --name avset02 -g handson `
--platform-fault-domain-count 2 `
--platform-update-domain-count 5

az vm create -g handson `
--name vm01 `
--vnet-name vnet01 `
--subnet subnet01 `
--availability-set avset01 `
--nsg none --public-ip-address '""' `
--image Win2019Datacenter `
--size Standard_D1_v2 `
--admin-username azureuser `
--storage-sku Standard_LRS2

az vm create -g handson `
--name vm02 `
--vnet-name vnet01 `
--subnet subnet01 `
--availability-set avset01 `
--nsg none --public-ip-address '""'`
--image Win2019Datacenter `
--size Standard_D1_v2 `
--admin-username azureuser `
--storage-sku Standard_LRS

# 02. Create Availability Set and Virtual machine
az vm availability-set create --name avset02 -g handson `
--platform-fault-domain-count 2 `
--platform-update-domain-count 5 

az vm create -g handson `
--name vm03 `
--vnet-name vnet01 `
--subnet subnet02 `
--availability-set avset02 `
--nsg none --public-ip-address '""' --image Win2019Datacenter `
--size Standard_D1_v2 `
--admin-username azureuser `
--storage-sku Standard_LRS

az vm create -g handson `
--name vm04 `
--vnet-name vnet01 `
--subnet subnet02 `
--availability-set avset02 `
--nsg none --public-ip-address  '""' --image Win2019Datacenter `
--size Standard_D1_v2 `
--admin-username azureuser `
--storage-sku Standard_LRS