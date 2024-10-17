
pragma solidity 0.8.26;

import "@forge-std/Script.sol";
import "@forge-std/console2.sol";
import "../test/MockEnv.sol";

contract DeployMock is Script {
    function run() external {
        vm.startBroadcast();
        MockEnv mock = new MockEnv();
        mock.initDebugFees();
        vm.stopBroadcast();
        console2.log('MockEnv');
        console2.log(address(mock));
    }
}
