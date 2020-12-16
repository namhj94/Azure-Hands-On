# PowerShell Syntax Guide
## 기본 개념
- 기본적으로 오브젝트를 얻어서 변수에 저장후, 다른 리소스 만들때 의존성으로 참조
- 생성 순서
    1. 해당 리소스의 config, 내부 설정 우선 생성, 변수처리
    2. 해당 리소스 생성
## Virtual Network
### Add-AzVirtualNetworkSubnetConfig
Adds a subnet configuration to a virtual network. => 새로운 subnet을 기존에 있는 vnet에 추가
### Set-AzVirtualNetworkSubnetConfig
Updates a subnet configuration for a virtual network. => 기존에 있는 서브넷 정보 업데이트, Add로 추가하고 Set을 해줘야 반영이 됨
### Get-AzVirtualNetworkSubnetConfig
Gets a subnet in a virtual network. => 기존에 있는 서브넷 정보 획득하여 구성에 사용