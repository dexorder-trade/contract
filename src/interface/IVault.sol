
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../core/OrderSpec.sol";
import {IFeeManager} from "./IFeeManager.sol";


interface IVaultImpl {

    function version() external view returns (uint256);

    function feeManager() external view returns (IFeeManager);
    function placementFee(SwapOrder memory order, IFeeManager.FeeSchedule memory sched) external view returns (uint256 orderFee, uint256 gasFee);
    function placementFee(SwapOrder[] memory orders, IFeeManager.FeeSchedule memory sched) external view returns (uint256 orderFee, uint256 gasFee);

    function placeDexorder(SwapOrder memory order) external payable;
    function placeDexorders(SwapOrder[] memory orders, OcoMode ocoMode) external payable;

    function numSwapOrders() external view returns (uint64 num);
    function swapOrderStatus(uint64 orderIndex) external view returns (SwapOrderStatus memory status);

    function execute(uint64 orderIndex, uint8 tranche_index, PriceProof memory proof) external;

    function cancelDexorder(uint64 orderIndex) external;
    function cancelAllDexorders() external;
    function orderCanceled(uint64 orderIndex) external view returns (bool);

    function vaultImplDidChange(address oldImpl) external; //REV: Changed this name to avoid similarity with the event name

    function wrapper() external view returns (address);
    function wrap(uint256 amount) external;
    function unwrap(uint256 amount) external;

}


interface IVaultProxy {

    event VaultCreated(address indexed owner, uint8 num);
    event Killed();

    // Deposit and Withdrawal are for native coin transfers.  ERC20 tokens emit Transfer events on their own.
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed receiver, uint256 amount);

    // Implementation upgrade events
    event VaultImplProposed(address impl, uint32 activationTime);
    event VaultImplChanged(address impl);

    function factory() external view returns (address);

    function kill() external;
    function killed() external view returns (bool);

    function owner() external view returns (address);

    function num() external view returns (uint8);

    function implementation() external view returns (address);

    function upgrade(address impl) external;

    receive() external payable;

    function withdraw(uint256 amount) external;

    function withdrawTo(address payable recipient, uint256 amount) external;

    function withdraw(IERC20 token, uint256 amount) external;

    function withdrawTo(IERC20 token, address recipient, uint256 amount) external;
}

interface IVault is IVaultProxy, IVaultImpl {}
