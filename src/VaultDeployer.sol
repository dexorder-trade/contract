// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "./Vault.sol";
pragma abicoder v2;

contract VaultDeployer {

    struct Parameters {
        address owner;
    }

    event VaultCreated( address deployer, address owner );

    Parameters public parameters;

    function deployVault(address owner) public returns (address vault) {
        parameters = Parameters(owner);
        vault = address(new Vault{salt: keccak256(abi.encode(owner))}());
        delete parameters;
        emit VaultCreated( address(this), owner );
    }
}
