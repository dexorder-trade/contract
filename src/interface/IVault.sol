// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OrderLib} from "../OrderLib.sol";
import {Dexorder} from "../Dexorder.sol";

// Actually Proxy for VaultLogic

interface IVaultProxy {

    event DexorderReceived(address, uint256);

    function owner() external view returns (address);
    function dexorder() external view returns (Dexorder);

    function withdraw(uint256 amount) external;

    function withdrawTo(address payable recipient, uint256 amount) external;

    function withdraw(IERC20 token, uint256 amount) external;

    function withdrawTo(IERC20 token, address recipient, uint256 amount) external;
}

interface IVaultLogic {

    function version() external pure returns (uint8);

    function numSwapOrders() external view returns (uint64 num);

    function placeDexorder(OrderLib.SwapOrder memory order) external;

    function placeDexorders(OrderLib.SwapOrder[] memory orders, OrderLib.OcoMode ocoMode) external;

    function swapOrderStatus(uint64 orderIndex) external view returns (OrderLib.SwapOrderStatus memory status);

    function execute(uint64 orderIndex, uint8 tranche_index, OrderLib.PriceProof memory proof) external;

    function cancelDexorder(uint64 orderIndex) external;

    function cancelAllDexorders() external;

    function orderCanceled(uint64 orderIndex) external view returns (bool);

}

interface IVault is IVaultProxy, IVaultLogic {}
