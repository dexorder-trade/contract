// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;
//pragma solidity =0.7.6;

import "forge-std/console2.sol";
import "../src/Factory.sol";
import "../src/VaultAddress.sol";
import "forge-std/Test.sol";
pragma abicoder v2;

contract TestVault is Test {

    Factory public factory;
    Vault public vault;

    function setUp() public {
        factory = new Factory();
        console2.log('factory');
        console2.log(address(factory));
        vault = Vault(factory.deployVault(address(this)));
        console2.log('vault');
        console2.log(address(vault));
    }

    function testDeterministicAddress() public view {
        console2.log(address(vault));
        address d = VaultAddress.computeAddress(address(factory), address(this));
        console2.log(d);
        assert(address(vault) == d);
    }
}
