
pragma solidity 0.8.28;

import {IVaultFactory} from "../interface/IVaultFactory.sol";
import {IVaultProxy,IVaultImpl} from "../interface/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./OrderSpec.sol";


// All state in Vault is declared in VaultStorage so it will be identical in VaultImpl

contract VaultStorage is ReentrancyGuard { // The re-entrancy lock is part of the state
    address internal _impl;
    address internal _owner;
    bool internal _killed; // each Vault may be independently killed by its owner at any time
    OrdersInfo internal _ordersInfo;
}


contract VaultBase is VaultStorage {

    function _withdrawNative(address payable recipient, uint256 amount) internal onlyOwner {
        recipient.transfer(amount);
        emit IVaultProxy.Withdrawal(recipient, msg.value);
    }


    function _withdraw(IERC20 token, address recipient, uint256 amount) internal onlyOwner nonReentrant {
        token.transfer(recipient, amount);
    }


    modifier onlyOwner() {
        require(msg.sender == _owner, "not owner");
        _;
    }

}


// Vault is implemented in three parts:
// 1. VaultStorage contains the data members, which cannot be upgraded.  The number of data slots is fixed upon
//    construction of the Vault contract.
// 2. Vault itself inherits from the state and adds several "top-level" methods for receiving and withdrawing funds and
//    for upgrading the VaultImpl delegate.  These vault methods may not be changed or upgraded.
// 3. VaultImpl is a deployed contract shared by Vaults.  If a method call is not found on Vault directly, the call
//    is delegated to the contract address stored in the `_impl` variable.  The VaultImpl contract is basically the
//    OrderLib, implementing the common order manipulation methods.  Each Vault may be independently upgraded to point
//    to a new VaultImpl contract by the owner calling their vault's `upgrade()` method with the correct argument.

contract Vault is IVaultProxy, VaultBase, Proxy {
    //REV putting all variable decls together so we can more easily see visibility and immutability errors
    IVaultFactory immutable private _factory;
    uint8 immutable private _num;

    function implementation() external view override returns(address) {return _impl;}

    function factory() external view override returns(address) {return address(_factory);}

    function killed() external view override returns(bool) {return _killed;}

    function owner() external view override returns(address) {return _owner;}

    function num() external view override returns(uint8) {return _num;}

    // for OpenZeppelin Proxy to call implementation contract via fallback
    function _implementation() internal view override returns (address) {
        // If the VaultFactory that created this vault has had its kill switch activated, do not trust the implementation.
        // local _killed var allows individual users to put their vaults into "killed" mode, where Dexorder functionality
        // is disabled, but funds can still be moved.
        require(!_killed && !_factory.killed(), 'K');
        return _impl;
    }

    constructor() {
        _factory = IVaultFactory(msg.sender);
        (_owner, _num, _impl) = _factory.parameters();
        emit VaultCreated( _owner, _num );
        emit VaultImplChanged(_impl);
    }

    // "Killing" a Vault prevents this proxy from forwarding any calls to the VaultImpl delegate contract. This means
    // all executions are stopped. Orders cannot be placed or canceled.
    function kill() external override onlyOwner {
        emit Killed();
        _killed = true;
    }

    function upgrade(address newImpl) external override onlyOwner {
        // we force the upgrader to explicitly pass in the implementation contract address, then we
        // ensure that it matches the factory's current version.
        require( newImpl == _factory.implementation(), 'UV' );
        address oldImpl = _impl;
        if(oldImpl==newImpl){
            return;
        }
        _impl = newImpl;
        IVaultImpl(address(this)).vaultImplDidChange(oldImpl);
        emit VaultImplChanged(newImpl);
    }

    receive() external payable override {
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external override {
        _withdrawNative(payable(_owner), amount);
    }

    function withdraw(IERC20 token, uint256 amount) external override {
        _withdraw(token, _owner, amount);
    }

    // withdrawTo(...) methods are in the VaultImpl. If the Vault is killed, withdrawals are only allowed to the
    // owner of this Vault.

}
