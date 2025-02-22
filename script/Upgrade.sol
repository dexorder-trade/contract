
pragma solidity 0.8.28;

import "@forge-std/Script.sol";
import "@forge-std/console2.sol";
import {IWETH9} from "../lib_uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../src/interface/IVaultFactory.sol";
import "../src/core/VaultImpl.sol";
import {ArbitrumRouter} from "../src/core/Router.sol";

contract Upgrade is Script {
    function run() external {
        address factoryAddr = vm.envAddress('FACTORY');
        console2.log(factoryAddr);
        require( factoryAddr != address(0), 'Must set FACTORY envvar');
        IVaultFactory factory = IVaultFactory(factoryAddr);
        address upgrader = factory.upgrader();
        console2.log('upgrader');
        console2.log(upgrader);
        console2.log(msg.sender);
        require( msg.sender == upgrader, 'Must be upgrader account');

        console2.log('old implementation');
        IVaultImpl oldImpl = IVaultImpl(factory.implementation());
        console2.log(address(oldImpl));
        IFeeManager feeManager = oldImpl.feeManager();
        console2.log('fee manager');
        console2.log(address(feeManager));
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
