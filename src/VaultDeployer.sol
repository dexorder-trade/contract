// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;

import "./Vault.sol";
pragma abicoder v2;

contract VaultDeployer {

    struct Parameters {
        address owner;
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
        parameters = Parameters(owner);
        vault = payable(address(new Vault{salt: keccak256(abi.encodePacked(owner,num))}()));
        delete parameters;
        emit VaultCreated( owner, num );
    }

}
