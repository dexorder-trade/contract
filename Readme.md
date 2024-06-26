# Overview

These contracts power [⬆dexorder](https://dexorder.trade).

The heart of the system is contained in `OrderLib.sol`, particularly the  `OrderLib.execute()` method. `Vaults` are 
basically thin wrappers around the `OrderLib`.

# Quickstart

The development environment is based on [Foundry](https://book.getfoundry.sh) toolset.

```bash
sudo apt install make curl jq
curl -L https://foundry.paradigm.xyz | bash  # Foundry
cp foundry-default.toml foundry.toml  # edit to include your own RPC URLs
git submodule init
make
```

# Development

## Error Codes

All Dexorder error codes, along with a few error codes from Uniswap, are described
in `doc/errors.md`.


## Mock Environment

run `./bin/mock` to spin up an Anvil node which forks Arbitrum in order to have the Uniswap v3 contracts available,
deploys the essential Dexorder init contracts, and also deploys the `MockEnv` class, which contains two mock tokens 
MEH and USXD along with a mock pool to trade that pair. See `test/MockEnv.sol`.

### Mock Shell
run `. ./bin/shmockenv` to populate these environment variables:

`MOCK`     address of the MockEnv  
`MEH`      address of MEH token  
`USXD`     address of the USXD token  
`T0`       address of token0 in the mock pool  
`T1`       address of token1 in the mock pool
`INVERTED` true iff USXD is token 0 and MEH is token 1

There are also a few scripts available to manipulate the MockEnv:

`./bin/price` shows the price of the mock MEH/USXD pool. NOTE: this price is always
expressed as MEH/USXD regardless of the order of those two tokens in the mock
pool.

`./bin/setprice <number>` adjusts the price of the mock pool by minting new tokens and swapping them. NOTE: this sets the price of MEH in terms of USXD
regardless of whether the pool is inverted.


## Deployments

Solidity compiler output and Foundry broadcast files for each chain are found under deployment/*<tag>*. The `broadcast`
directory contains files describing the deployment of the initial contracts on-chain, while the `out` directory
contains the usual solc compiler output including ABI information.

## Create a New Vault

To deploy a new Vault, use the `IVaultDeployer` interface, which is a superclass of Factory. You may find the factory
address in `contract/deployment/<tag>/broadcast/Deploy.sol/<chainId>/run-latest.json`.

```solidity
IVaultFactory factory = IVaultFactory(factoryAddress);
IVault myVault = factory.deployVault(); // deploy a vault owned by this smart contract
IVault yourVault = factory.deployVault(myAddress);  // deploy a vault for any address
```

Only a single vault per account address, vault number 0, is currently supported. Do not use vault numbers other than 0
until multi-vault support is added to the activation backend.

Any account may deploy the Vault associated with any given owner. That is, the owner of the vault does not need to be
its deployer. Vault addresses are deterministic and salted with the owner's address, so an account's associated Vault 
address may be computed off-chain, or by using the `VaultAddress` class. The `VaultAddress.sol` file is generated using 
the `bin/build` script for local builds, or use the deployed code from `deployments/.../VaultAddress.json`.

## Place an Order

For interaction with a Vault, use the `IVault` interface.

See `test/TestOrder.sol` for a couple simple examples of constructing an order that may be passed to the vault's
`placeOrder()` method.  Extensive documentation of the order spec is forthcoming...

The Dexorder backend detects and executes all placed orders from on-chain event data. There is no requirement to use the
Dexorder website to place orders. However, only the owner of a vault may place or cancel the orders in that vault. The
`placeOrder()` transaction must be signed by the vault's owner.

## Withdraw Funds

Standard `withdraw()` and `withdrawTo()` methods for both native coin and ERC20 tokens are available on the `IVault`
interface. Withdrawl transactions must be signed by the vault's owner.

# Security Notes

These contracts are not feature complete and are works in progress. No audit has yet been performed, not even the
running of static analysis scripts. Please report any discovered problems as a public issue here in the GitHub project.

The Vault itself is a proxy contract that points its external methods to a shared VaultLogic contract, which is
basically an instantiation of the OrderLib. This tremendously reduces the size of the deployed vault instances and also
allows for a smoother user experience when upgrading to new versions. Any change to a vault's delegate contract
will require an approval signature from the vault owner, but this process is not implemented yet. We are receptive to a
non-upgradable model where assets must be explicitly transferred from an old vault to a new one, but currently do not
believe that would really present a significant security improvement over an explicit upgrade signature from every 
user.

Overflow checking is now built-in to Solidity 0.8.x. We have *copied* Uniswap dependencies into our
repository and modified them to build with 0.8.

A re-entrancy lock has been implemented but not tested.

`onlyOwner` modifiers guard order interactions and withdrawls.

The `execute()` method is intentionally public. It is expected to revert if any test of the order conditions fails. 

# Support

Create a new issue in this project using the `Question` tag, or join our [Discord](https://discord.gg/fqp9JXXQyt) for a
more interactive experience.
