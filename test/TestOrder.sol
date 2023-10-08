// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "./MockEnv.sol";
import "forge-std/Test.sol";
import "../src/Factory.sol";

contract TestOrder is MockEnv, Test {
    Factory public factory;
    Vault public vault;

    // vault gets 100,000 COIN and 100,000 USD
    function setUp() public {
        init();
        factory = new Factory();
        vault = Vault(factory.deployVault(address(this)));
        uint256 coinAmount = 100_000 * 10 ** COIN.decimals();
        COIN.mint(address(vault), coinAmount);
        uint256 usdAmount = 100_000 * 10 ** USD.decimals();
        USD.mint(address(vault), usdAmount);
    }


    function testOrder() public {

    }

}
