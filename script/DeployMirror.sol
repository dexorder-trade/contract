
pragma solidity 0.8.26;

import "../test/MirrorEnv.sol";
import "@forge-std/console2.sol";
import "@forge-std/Script.sol";
import {UniswapV3Arbitrum} from "../src/core/UniswapV3.sol";

contract DeployMirror is Script {
    function run() external {
        address nfpm = vm.envOr('NFPM', address(UniswapV3Arbitrum.nfpm));
        address swapRouter = vm.envOr('SWAP_ROUTER', address(UniswapV3Arbitrum.swapRouter));
        console2.log('Using NFPM at');
        console2.log(nfpm);
        vm.startBroadcast();
        MirrorEnv mirror = new MirrorEnv(INonfungiblePositionManager(nfpm), ISwapRouter(swapRouter));
        vm.stopBroadcast();
        console2.log('Deployed MirrorEnv to');
        console2.log(address(mirror));
    }
}
