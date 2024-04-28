// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/console2.sol";
import "../src/Factory.sol";
import "../src/VaultAddress.sol";
import "forge-std/Test.sol";
pragma abicoder v2;

contract TestCreateVault is Test {

    Factory public factory;
    Vault public vault;

    function setUp() public {
        factory = new Factory(new Dexorder());
        console2.log('factory');
        console2.log(address(factory));
    }

    function testCreateVault() public {
        Vault(factory.deployVault(address(this)));
    }

}
