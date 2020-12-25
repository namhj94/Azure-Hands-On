#!/bin/sh

# Create rg
az group create --name hjrg -l eastus

# Create network
az network vnet create -n vnet00 -g hjrg --address-prefixes 10.0.0.0/8 --subnet-name websubnet --subnet-prefixes 10.1.0.0/16
az network vnet subnet create -g hjrg --address-prefixes 10.2.0.0/16 --name wassubnet --vnet-name vnet00
az network vnet subnet create -g hjrg --address-prefixes 10.3.0.0/16 --name dbsubnet --vnet-name vnet00

az network nsg create -n webnsg -g hjrg -l eastus
az network nsg create -n wasnsg -g hjrg -l eastus
az network nsg create -n dbnsg -g hjrg -l eastus

az network nsg rule create -n "Allow 80" -g hjrg --nsg-name webnsg --access Allow  --direction Inbound --priority 100 --source-address-prefixes  "*" --source-port-range "*" --destination-address-prefixes "*" --destination-port-ranges 80
az network nsg rule create -n "Allow 8080" -g hjrg --nsg-name webnsg --access Allow --direction Inbound --priority 120 --source-address-prefixes "*" --source-port-range "*" --destination-address-prefixes "*" --destination-port-range 8080
az network nsg rule create -n "Allow ssh" -g hjrg --nsg-name webnsg --access Allow  --direction Inbound --priority 110 --source-address-prefixes  "*" --source-port-range "*" --destination-address-prefixes "*" --destination-port-ranges 22

az network nsg rule create -n "Allow ssh" -g hjrg --nsg-name wasnsg --access Allow  --direction Inbound --priority 110 --source-address-prefixes  "*" --source-port-range "*" --destination-address-prefixes "*" --destination-port-ranges 22
az network nsg rule create -n "Allow 8080" -g hjrg --nsg-name wasnsg --access Allow --direction Inbound --priority 120 --source-address-prefixes "*" --source-port-range "*" --destination-address-prefixes "*" --destination-port-range 8080
az network nsg rule create -n "Allow 8081" -g hjrg --nsg-name wasnsg --access Allow --direction Inbound --priority 130 --source-address-prefixes "*" --source-port-range "*" --destination-address-prefixes "*" --destination-port-range 8081

az network vnet subnet update -g hjrg -n websubnet --vnet-name vnet00 --nsg webnsg
az network vnet subnet update -g hjrg -n wassubnet --vnet-name vnet00 --nsg wasnsg

# Create Web Server(Front End)
az vm create -g hjrg -n web00 --image CentOS --admin-username azureuser --generate-ssh-keys --nsg "" --size Standard_D1_v2 --vnet-name vnet00 --subnet websubnet --public-ip-address webserverpip

# Create WAS Server(Back End)
az vm create -g hjrg -n was00 --image CentOS --admin-username azureuser --generate-ssh-keys --nsg "" --size Standard_D1_v2 --vnet-name vnet00 --subnet wassubnet --public-ip-address wasserverpip

# Create DB Server()
az mysql server create -g hjrg -n db00 -l eastus --admin-user ADMIN_NAME --admin-password PASSWORD --sku-name GP_Gen5_2

# DB서버 방화벽 규칙 설정, 아래 커맨드는 서브넷생각해서 한건데, 이 DB서버가 서브넷이랑 관련없으므로 먹히지 않음
# 포털 CONNECTION SECURITY에서 VNET과 SUBNET을 추가해줘야함
az mysql server firewall-rule create -g hjrg --server db00 --name AllowMyIP --start-ip-address 10.2.0.4 --end-ip-address 10.2.0.4
