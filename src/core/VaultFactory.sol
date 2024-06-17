// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import "./Vault.sol";
import "../interface/IVault.sol";
import "../interface/IVaultFactory.sol";
import "../more/Dexorder.sol";

contract VaultFactory is IVaultFactory {

    address public override upgrader;

    // This is the common implementation contract, which is the delegate of the vault proxies.  Each created vault
    // keeps its own delegate pointer, and the owner of each vault must explicity opt-in to upgrades (changes) of
    // their vault's implementation.  The _vaultLogic pointed to here is the initial implementation for new vaults and
    // the new implementation for any vaults that authorize an upgrade().
    // The _vaultLogic cannot be changed immediately.  The admin of the VaultFactory proposes a new implementation
    // which is stored in proposedLogic for at least UPGRADE_NOTICE_DURATION seconds before it becomes active as the
    // new implementation.  This gives users and the community time to review any proposed changes before they can be
    // adopted.  Any malicous entity that hacks the Dexorder admin account would also suffer this 30-day delay before
    // their exploit implementation would be used by anyone.  Upgrade proposals are easily, publicly visible by looking
    // for the VaultLogicProposed event on-chain.

    // This is the implementation delegate for newly created vaults. Use logic() to get, then cast to VaultLogic type.
    address private _vaultLogic;

    // Upgrades
    // uint32 UPGRADE_NOTICE_DURATION = 30 * 24 * 60 * 60; // 30 days
    uint32 public constant UPGRADE_NOTICE_DURATION = 2 * 60; // todo remove debug duration


    // 0 if no upgrade is pending, otherwise the timestamp when proposedLogic becomes the default for new vaults
    uint32 public override proposedLogicActivationTimestamp;
    address public override proposedLogic;  // the contract address of a proposed upgrade to the default vault logic.


    constructor ( address upgrader_, address vaultLogic_ ) {
        upgrader = upgrader_;
        _vaultLogic = vaultLogic_;
        proposedLogic = address(0);
        proposedLogicActivationTimestamp = 0;
    }

    struct Parameters {
        address owner;
        uint8 num;
        address vaultLogic;
    }

    Parameters public override parameters;

    function deployVault() public override returns (address payable vault) {
        return _deployVault(msg.sender, 0);
    }

    function deployVault(uint8 num) public override returns (address payable vault) {
        return _deployVault(msg.sender, num);
    }

    function deployVault(address owner) public override returns (address payable vault) {
        return _deployVault(owner, 0);
    }

    function deployVault(address owner, uint8 num) public override returns (address payable vault) {
        return _deployVault(owner, num);
    }

    function _deployVault(address owner, uint8 num) internal returns (address payable vault) {
        parameters = Parameters(owner, num, _logic());
        // console2.log("new Vault owner:", owner);
        vault = payable(address(new Vault{salt: keccak256(abi.encodePacked(owner,num))}()));
        delete parameters;
    }


    function _logic() internal returns (address) {
        if (proposedLogicActivationTimestamp != 0 && proposedLogicActivationTimestamp <= block.timestamp) {
            // time to start using the latest upgrade
            _vaultLogic = proposedLogic;
            proposedLogicActivationTimestamp = 0;
            emit IVaultProxy.VaultLogicChanged(_vaultLogic);
        }
        return _vaultLogic;
    }


    function logic() external view override returns (address) {
        return proposedLogicActivationTimestamp != 0 && proposedLogicActivationTimestamp <= block.timestamp ?
            proposedLogic : _vaultLogic;
    }


    modifier onlyUpgrader() {
        require(msg.sender == upgrader, "not upgrader");
        _;
    }

    function upgradeLogic( address newLogic ) external onlyUpgrader {
        proposedLogic = newLogic;
        proposedLogicActivationTimestamp = uint32(block.timestamp + UPGRADE_NOTICE_DURATION);
        emit IVaultProxy.VaultLogicProposed( newLogic, proposedLogicActivationTimestamp);
    }

}
