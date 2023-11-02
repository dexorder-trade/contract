// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/QueryHelper.sol";
import "../src/Factory.sol";
import "../src/Dexorder.sol";
import "../test/MockEnv.sol";

contract DeployMock is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MockEnv mock = new MockEnv();
        mock.init();
        vm.stopBroadcast();
        console2.log('MockEnv');
        console2.log(address(mock));
    }
}
