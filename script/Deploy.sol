// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/QueryHelper.sol";
import "../src/Factory.sol";
import "../src/Dexorder.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Dexorder dexorder = new Dexorder();
        Factory deployer = new Factory{salt:keccak256(abi.encode(1))}(dexorder); // version 1
        QueryHelper query = new QueryHelper();
        vm.stopBroadcast();
        console2.log('Factory');
        console2.log(address(deployer));
        console2.log('QueryHelper');
        console2.log(address(query));
        console2.log('Dexorder');
        console2.log(address(dexorder));
    }
}
