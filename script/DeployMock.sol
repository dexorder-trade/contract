// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../test/MockEnv.sol";

contract DeployMock is Script {
    function run() external {
        vm.startBroadcast();
        MockEnv mock = new MockEnv();
        mock.init();
        vm.stopBroadcast();
        console2.log('MockEnv');
        console2.log(address(mock));
    }
}
