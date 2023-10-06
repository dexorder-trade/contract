// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "forge-std/console2.sol";
import "../src/Factory.sol";
import "../src/VaultAddress.sol";
import "forge-std/Test.sol";
pragma abicoder v2;

contract TestVault is Test{

    Factory public factory;
    Vault public vault;

    function setUp() public {
        factory = new Factory();
        vault = Vault(factory.deployVault(address(this)));
    }

    function testDeterministicAddress() public {
        console2.log(address(vault));
        address d = VaultAddress.computeAddress(address(factory), address(this));
        console2.log(d);
        assert(address(vault) == d);
    }
}
