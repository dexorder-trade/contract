// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "../test/MirrorEnv.sol";
import "forge-std/console2.sol";
import "forge-std/Script.sol";

contract DeployMirror is Script {
    function run() external {
        vm.startBroadcast();
        MirrorEnv mirror = new MirrorEnv();
        vm.stopBroadcast();
        console2.log('MirrorEnv');
        console2.log(address(mirror));
    }
}
