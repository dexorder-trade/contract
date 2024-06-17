// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFeeManager} from "../interface/IFeeManager.sol";
import {IVaultProxy, IVaultLogic} from "../interface/IVault.sol";
import {VaultState} from "./Vault.sol";
import {Dexorder} from "../more/Dexorder.sol";
import {OrderLib} from "./OrderLib.sol";


contract VaultLogic is IVaultLogic, VaultState {

    uint256 constant public version = 1;

    IFeeManager public immutable feeManager;

    constructor( IFeeManager feeManager_ ) {
        feeManager = feeManager_;
    }

    function numSwapOrders() external view returns (uint64 num) {
        return uint64(ordersInfo.orders.length);
    }

    // Returns the amount of native coin charged by the placeDexorder() call. This amount MUST be in the msg.value
    function placementFee(OrderLib.SwapOrder memory order) external returns (uint256 orderFee, uint256 gasFee) {
        return placementFee(order, feeManager.fees());
    }

    function placementFee(OrderLib.SwapOrder[] memory orders) external returns (uint256 orderFee, uint256 gasFee) {
        return placementFee(orders, feeManager.fees());
    }

    function placementFee(OrderLib.SwapOrder memory order, IFeeManager.FeeSchedule memory sched) internal pure
    returns (uint256 orderFee, uint256 gasFee) {
        return OrderLib._placementFee(order, sched);
    }

    function placementFee(OrderLib.SwapOrder[] memory orders, IFeeManager.FeeSchedule memory sched) internal pure
    returns (uint256 orderFee, uint256 gasFee) {
        orderFee = 0;
        gasFee = 0;
        for( uint i=0; i<orders.length; i++ ) {
            (uint256 ofee, uint256 efee) = OrderLib._placementFee(orders[i], sched);
            orderFee += ofee;
            gasFee += efee;
        }
    }

    function placeDexorder(OrderLib.SwapOrder memory order) external payable onlyOwner nonReentrant {
        // feeSched() returns tuple, not struct!
        console2.log('placing order');
//        (uint8 fillFeeHalfBps,,,,) = d.fees(); // save fill fee in order
        IFeeManager.FeeSchedule memory sched = feeManager.fees();
        (uint256 orderFee, uint256 gasFee) = OrderLib._placementFee(order, sched);
        // We force the value to be sent with the message so that the user can see the fee immediately in their wallet
        // software before they confirm the transaction.  If the user overpays, the extra amount remains in this vault.
        require( msg.value >= orderFee + gasFee, 'FEE');
        if (orderFee > 0)
            feeManager.orderFeeAccount().transfer(orderFee);
        if (gasFee > 0)
            feeManager.gasFeeAccount().transfer(gasFee);
        OrderLib._placeOrder(ordersInfo, order, sched.fillFeeHalfBps);
        console2.log('order placed');
    }

    function placeDexorders(OrderLib.SwapOrder[] memory orders, OrderLib.OcoMode ocoMode) external payable onlyOwner nonReentrant {
        // todo fees
//        dexorder().orderFeeAccount().transfer(dexorder().orderFee() * orders.length);
        uint256 nTranches = 0;
        for( uint8 o = 0; o < orders.length; o++ ) {
            nTranches += orders[o].tranches.length;
        }
//        (uint8 fillFeeHalfBps,,,,) = dexorder().feeSched(); // save fill fee in order
        uint8 fillFeeHalfBps = 0; // todo fees
        OrderLib._placeOrders(ordersInfo, orders, fillFeeHalfBps, ocoMode);
//        dexorder().trancheFeeAccount().transfer(dexorder().trancheFee(nTranches));
    }

    function swapOrderStatus(uint64 orderIndex) external view returns (OrderLib.SwapOrderStatus memory status) {
        return ordersInfo.orders[orderIndex];
    }

    function execute(uint64 orderIndex, uint8 tranche_index, OrderLib.PriceProof memory proof) external nonReentrant
    {
        address payable t = payable(address(this));
        IVaultProxy proxy = IVaultProxy(t);
        address owner = proxy.owner();
        OrderLib.execute(ordersInfo, owner, orderIndex, tranche_index, proof, feeManager);
    }

    function cancelDexorder(uint64 orderIndex) external onlyOwner nonReentrant {
        OrderLib._cancelOrder(ordersInfo,orderIndex);
    }

    function cancelAllDexorders() external onlyOwner nonReentrant {
        OrderLib._cancelAll(ordersInfo);
    }

    function orderCanceled(uint64 orderIndex) external view returns (bool) {
        require( orderIndex < ordersInfo.orders.length );
        return OrderLib._isCanceled(ordersInfo, orderIndex);
    }

    modifier onlyOwner() {
        require(msg.sender == IVaultProxy(payable(address(this))).owner(), "not owner");
        _;
    }

}
