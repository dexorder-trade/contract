// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import {IVaultDeployer} from "./interface/IVaultDeployer.sol";
import {IVaultProxy} from "./interface/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OrderLib} from "./OrderLib.sol";
import {Dexorder} from "./Dexorder.sol";

// Vault represents the interests of its owner client

// All state in Vault is declared in VaultState so it will be identical in VaultLogic

contract VaultState {
    OrderLib.OrdersInfo public ordersInfo;
}

// Vault is proxy that calls VaultLogic

// Inheritance order for stateful contracts must be consistent between Vault and VaultLogic
// This is the order: ReentrancyGuard, VaultState

contract Vault is IVaultProxy, ReentrancyGuard, VaultState, Proxy {

    address immutable _owner;
    address immutable vaultLogic; // Address of logic contract
    address immutable _dexorder;
    function owner() external view returns(address) {return _owner;}
    function dexorder() external view returns(Dexorder) {return Dexorder(payable(_dexorder));}

    constructor()
    {
        (_owner, vaultLogic, _dexorder) = IVaultDeployer(msg.sender).parameters();
    }

    // event DexorderReceived(address, uint256);

    receive() external payable {
        emit DexorderReceived(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _withdrawNative(payable(_owner), amount);
    }

    function withdrawTo(address payable recipient, uint256 amount) external {
        _withdrawNative(recipient, amount);
    }

    function _withdrawNative(address payable recipient, uint256 amount) internal onlyOwner {
        recipient.transfer(amount);
    }

    function withdraw(IERC20 token, uint256 amount) external {
        _withdraw(token, _owner, amount);
    }

    function withdrawTo(IERC20 token, address recipient, uint256 amount) external {
        _withdraw(token, recipient, amount);
    }

    function _withdraw(IERC20 token, address recipient, uint256 amount) internal onlyOwner nonReentrant {
        token.transfer(recipient, amount);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "not owner");
        _;
    }

    // Use OpenZeppelin Proxy to call logic contract via fallback

    function _implementation() internal view override returns (address) {
        return address(vaultLogic);
    }

}
