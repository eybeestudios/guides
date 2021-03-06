# IPSUM Staking and Masternode
*These guides are designed to assist you in installing and configuring an IPSUM staking wallet or IPSUM masternode.* 

## Requirements

### Staking
  * The IPS coins you intent to stake must have 101 confirmations
  * At least 25GB of free space
  * Synchronized IPSUM wallet

### Masternode
  * Exactly 5000.00 IPS as collateral
  * An internet addressable IP address
  * Port 22331 forwarded
  * At least 25GB of free space
  * Synchronized IPSUM wallet
  
## Recommendations

### Staking
  * At least 10000 IPS, anything less than that you are better off running a masternode
  * Dedicated machine for your wallet, as you want to keep it online as much as possible
  
### Masternode
  * Dedicated Linux (Ubuntu 16.04) VPS from [Vultr](https://www.vultr.com/) or [Digital Ocean](https://www.digitalocean.com/)

## Staking Installation Types

### Windows

[Windows Staking Guide](STAKING-WINDOWS.md)

### Linux

[Linux Staking Guide](STAKING-LINUX.md)
  
## Masternode Installation Types

### Windows Wallet with Linux VPS
*Choose this installation guide if you are running a Windows IPSUM wallet holding the collateral for your masternode*

#### Cold Wallet
*Collateral coins are not stored on the masternode, rather in a Windows wallet.*

[Windows Cold Wallet and Linux VPS Installation Guide](WINDOWS.md)

### Linux Wallet and VPS
*Choose this installation guide if you are running a Linux wallet holding the collateral for your masternode*

#### Hot Wallet
*This is for advanced users and should not be used unless you understand what you are doing. Collateral coins are stored on the masternode.*

[Linux VPS Hot Wallet Installation Guide](LINUX-HOT.md)

#### Cold Wallet
*Collateral coins are not stored on the masternode, rather in a Linux wallet.*

[Linux VPS Cold Wallet Installation Guide](LINUX-COLD.md)

### Docker
*Choose this installation if your are a power user with Docker*

[Docker Installation Guide](DOCKER.md)
