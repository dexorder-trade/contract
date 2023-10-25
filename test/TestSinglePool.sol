// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
pragma abicoder v2;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import "./MockEnv.sol";


contract TestSinglePool is MockEnv, Test {
    function setUp() public {
        init();
    }

     function testSwap() public {
        COIN.mint(address(this), 1 * 10**18);
        uint256 usd = swap(COIN, USD, 1 * 10**18);
        console2.log(usd);
    }
}
