// SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.7.6;
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/QueryHelper.sol";
import "../src/Factory.sol";
import "../src/Dexorder.sol";
import "../test/MockEnv.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
//        Factory deployer = new Factory{salt:keccak256(abi.encode(1))}(); // version 1
        Factory deployer = new Factory(); // hardhat often breaks on the CREATE2 above :(
        QueryHelper query = new QueryHelper();
        Dexorder dexorder = new Dexorder();
        MockEnv mock = new MockEnv();
        vm.stopBroadcast();
        console2.log('Factory');
        console2.log(address(deployer));
        console2.log('QueryHelper');
        console2.log(address(query));
        console2.log('Dexorder');
        console2.log(address(dexorder));
        console2.log('MockEnv'); // todo no mock in production deployment
        console2.log(address(mock));
    }
}
