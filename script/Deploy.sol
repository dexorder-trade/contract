// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/QueryHelper.sol";
import "../src/Factory.sol";
import "../test/MockEnv.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        Factory deployer = new Factory{salt:keccak256(abi.encode(1))}();
        QueryHelper query = new QueryHelper();
        MockEnv mock = new MockEnv();
        vm.stopBroadcast();
        console2.log('VaultDeployer');
        console2.log(address(deployer));
        console2.log('QueryHelper');
        console2.log(address(query));
        console2.log('MockEnv'); // todo no mock in production deployment
        console2.log(address(mock));
    }
}
