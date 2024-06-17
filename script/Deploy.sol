// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/core/FeeManager.sol";
import "../src/core/VaultLogic.sol";
import "../src/core/VaultFactory.sol";
import "../src/more/QueryHelper.sol";
import "../src/more/Dexorder.sol";
import {IWETH9} from "../lib_uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        Dexorder dexorder = new Dexorder();
        FeeManager feeManager = FeeManagerLib.debugFeeManager(
            payable(msg.sender),
            payable(0x90F79bf6EB2c4f870365E785982E1f101E93b906),  // order fees (native) => dev account #3
            payable(0x976EA74026E726554dB657fA54763abd0C3a0aa9),  //   gas fees (native) => dev account #6
            payable(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65)   //  fill fees (tokens) => dev account #4
        );
        VaultLogic logic = new VaultLogic(feeManager);
        VaultFactory factory = new VaultFactory(msg.sender, address(logic));
        QueryHelper query = new QueryHelper();
        vm.stopBroadcast();

        console2.log('VaultFactory');
        console2.log(address(factory));
        console2.log('QueryHelper');
        console2.log(address(query));
        console2.log('Dexorder');
        console2.log(address(dexorder));
    }
}
