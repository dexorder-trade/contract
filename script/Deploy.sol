// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "forge-std/Script.sol";
import "../src/VaultDeployer.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        VaultDeployer deployer = new VaultDeployer{salt:keccak256(abi.encode(1))}();
        vm.stopBroadcast();
    }
}
