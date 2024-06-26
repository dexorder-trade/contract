// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import {IVaultFactory} from "../interface/IVaultFactory.sol";
import {VaultFactory} from "./VaultFactory.sol";
import {IVaultProxy} from "../interface/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OrderLib} from "./OrderLib.sol";
import {IERC20Metadata} from "../../lib_uniswap/v3-periphery/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Minimal} from "../../lib_uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";


// All state in Vault is declared in VaultState so it will be identical in VaultLogic

contract VaultState is ReentrancyGuard { // The re-entrancy lock is part of the state
    address internal _owner;
    bool internal _killed; // each Vault may be independently killed by its owner at any time
    OrderLib.OrdersInfo internal _ordersInfo;
    // additional slots for future expansion
    mapping(uint256=>uint256) internal _extra1;
    mapping(uint256=>uint256) internal _extra2;
    mapping(uint256=>uint256) internal _extra3;
}

// Vault is implemented in three parts:
// 1. VaultState contains the data members, which cannot be upgraded.  The number of data slots is fixed upon
//    construction of the Vault contract.
// 2. Vault itself inherits from the state and adds several "top-level" methods for receiving and withdrawing funds and
//    for upgrading the VaultLogic delegate.  These vault methods may not be changed or upgraded.
// 3. VaultLogic is a deployed contract shared by Vaults.  If a method call is not found on Vault directly, the call
//    is delegated to the contract address stored in the `logic` variable.  The VaultLogic contract is basically the
//    OrderLib, implementing the common order manipulation methods.  Each Vault may be independently upgraded to point
//    to a new VaultLogic contract by the owner calling their vault's `upgrade()` method with the correct argument.

contract Vault is IVaultProxy, VaultState, Proxy {

    IVaultFactory immutable private _factory;

    function factory() external view override returns(IVaultFactory) {return _factory;}

    function killed() external view override returns(bool) {return _killed;}

    function owner() external view override returns(address) {return _owner;}

    uint8 immutable private _num;
    function num() external view override returns(uint8) {return _num;}

    // Method calls not found on this contract are delegated to the logic contract.
    address public override logic;

    // for OpenZeppelin Proxy to call logic contract via fallback
    function _implementation() internal view override returns (address) {
        // If the VaultFactory that created this vault has had its kill switch activated, do not trust the logic.
        require(!_killed && !_factory.killed(), 'K');
        return logic;
    }

    constructor() {
        _factory = IVaultFactory(msg.sender);
        (_owner, _num, logic) = _factory.parameters();
        emit VaultCreated( _owner, _num );
        emit VaultLogicChanged(logic);
    }

    // "Killing" a Vault prevents this proxy from forwarding any calls to the VaultLogic delegate contract. This means
    // all executions are stopped. Orders cannot be placed or canceled.
    function kill() external override onlyOwner {
        emit Killed();
        _killed = true;
    }

    function upgrade(address newLogic) external override onlyOwner {
        // we force the upgrader to explicitly pass in the implementation contract address, then we
        // ensure that it matches the factory's current version.
        require( newLogic == _factory.logic(), 'UV' );
        logic = newLogic;
        emit VaultLogicChanged(newLogic);
    }

    receive() external payable override {
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external override {
        _withdrawNative(payable(_owner), amount);
    }

    function withdrawTo(address payable recipient, uint256 amount) external override {
        _withdrawNative(recipient, amount);
    }

    function _withdrawNative(address payable recipient, uint256 amount) internal onlyOwner {
        recipient.transfer(amount);
        emit Withdrawl(recipient, msg.value);
    }

    function withdraw(IERC20 token, uint256 amount) external override {
        _withdraw(token, _owner, amount);
    }

    function withdrawTo(IERC20 token, address recipient, uint256 amount) external override {
        _withdraw(token, recipient, amount);
    }

    function _withdraw(IERC20 token, address recipient, uint256 amount) internal onlyOwner nonReentrant {
        token.transfer(recipient, amount);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "not owner");
        _;
    }

}
