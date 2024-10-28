
pragma solidity 0.8.26;

import "@forge-std/Script.sol";
import "@forge-std/console2.sol";
import {IWETH9} from "../lib_uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../src/interface/IVaultFactory.sol";
import "../src/core/VaultImpl.sol";
import {ArbitrumRouter} from "../src/core/Router.sol";

contract UpgradeArbitrum is Script {
    function run() external {
        address factoryAddr = address(0x7fb08EAE59e6260B6d62fC1bC199F6B8a9993246);
        console2.log(factoryAddr);
        IVaultFactory factory = IVaultFactory(factoryAddr);
        address upgrader = factory.upgrader();
        require( msg.sender == upgrader, 'Must be upgrader account');

        IVaultImpl oldImpl = IVaultImpl(factory.implementation());
        IFeeManager feeManager = oldImpl.feeManager();
        console2.log('retaining fee manager', address(feeManager));
        vm.startBroadcast();
        console2.log('deploy new router (Arbitrum)');
        IRouter router = new ArbitrumRouter();
        console2.log('deploy new implementation');
        VaultImpl impl = new VaultImpl(router, feeManager, oldImpl.wrapper());
        console2.log('invoke upgrade');
        factory.upgradeImplementation(address(impl));
        console2.log('impl upgrade proposed');
        vm.stopBroadcast();
    }
}
