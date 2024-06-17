// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {IWETH9} from "../lib_uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import "../src/interface/IVaultFactory.sol";
import "../src/core/VaultLogic.sol";

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

        console2.log('old logic');
        IVaultLogic oldLogic = IVaultLogic(factory.logic());
        console2.log(address(oldLogic));
        IFeeManager feeManager = oldLogic.feeManager();
        console2.log('fee manager');
        console2.log(address(feeManager));
        vm.startBroadcast();
        console2.log('deploy new logic');
        VaultLogic logic = new VaultLogic(feeManager);
        console2.log('invoke upgrade');
        factory.upgradeLogic(address(logic));
        console2.log('logic upgrade proposed');
        vm.stopBroadcast();
    }
}
