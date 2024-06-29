// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OrderLib} from "../core/OrderLib.sol";
import {IFeeManager} from "./IFeeManager.sol";
import {IVaultFactory} from "./IVaultFactory.sol";


interface IVaultLogic {

    function version() external pure returns (uint256);

    function feeManager() external view returns (IFeeManager);
    function placementFee(OrderLib.SwapOrder memory order, IFeeManager.FeeSchedule memory sched) external pure returns (uint256 orderFee, uint256 gasFee);
    function placementFee(OrderLib.SwapOrder[] memory orders, IFeeManager.FeeSchedule memory sched) external pure returns (uint256 orderFee, uint256 gasFee);

    function placeDexorder(OrderLib.SwapOrder memory order) external payable;
    function placeDexorders(OrderLib.SwapOrder[] memory orders, OrderLib.OcoMode ocoMode) external payable;

    function numSwapOrders() external view returns (uint64 num);
    function swapOrderStatus(uint64 orderIndex) external view returns (OrderLib.SwapOrderStatus memory status);

    function execute(uint64 orderIndex, uint8 tranche_index, OrderLib.PriceProof memory proof) external;

    function cancelDexorder(uint64 orderIndex) external;
    function cancelAllDexorders() external;
    function orderCanceled(uint64 orderIndex) external view returns (bool);

}

interface IVaultProxy {

    event VaultCreated(address indexed owner, uint8 num);
    event Killed();

    // Deposit and Withdrawl are for native coin transfers.  ERC20 tokens emit Transfer events on their own.
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawl(address indexed receiver, uint256 amount);

    // Logic upgrade events
    event VaultLogicProposed(address logic, uint32 activationTime);
    event VaultLogicChanged(address logic);

    function factory() external view returns (IVaultFactory);

    function kill() external;
    function killed() external view returns (bool);

    function owner() external view returns (address);

    function num() external view returns (uint8);

    function logic() external view returns (address);

    function upgrade(address logic) external;

    receive() external payable;

    function withdraw(uint256 amount) external;

    function withdrawTo(address payable recipient, uint256 amount) external;

    function withdraw(IERC20 token, uint256 amount) external;

    function withdrawTo(IERC20 token, address recipient, uint256 amount) external;
}

interface IVault is IVaultProxy, IVaultLogic {}
