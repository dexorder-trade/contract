// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import "./Vault.sol";
import "./interface/IVault.sol";
import "./VaultLogic.sol";
import "./interface/IVaultDeployer.sol";
import "./Dexorder.sol";

contract VaultDeployer is IVaultDeployer {

    VaultLogic immutable vaultLogic;
    Dexorder immutable dexorder;

    constructor (Dexorder _dexorder) {
        vaultLogic = new VaultLogic();
        dexorder = _dexorder;
    }

    struct Parameters {
        address owner;
        address vaultLogic;
        address dexorder;
    }

    event VaultCreated( address indexed owner, uint8 num );

    Parameters public parameters;

    function deployVault() public returns (address payable vault) {
        return _deployVault(msg.sender, 0);
    }

    function deployVault(uint8 num) public returns (address payable vault) {
        return _deployVault(msg.sender, num);
    }

    function deployVault(address owner) public returns (address payable vault) {
        return _deployVault(owner, 0);
    }

    function deployVault(address owner, uint8 num) public returns (address payable vault) {
        return _deployVault(owner, num);
    }

    function _deployVault(address owner, uint8 num) internal returns (address payable vault) {
        parameters = Parameters(owner, address(vaultLogic), address(dexorder));
        // console2.log("new Vault owner:", owner);
        vault = payable(address(new Vault{salt: keccak256(abi.encodePacked(owner,num))}()));
        delete parameters;
        emit VaultCreated( owner, num );
    }
}
