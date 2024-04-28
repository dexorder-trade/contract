// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import {console2} from "forge-std/console2.sol";
import {VaultState} from "./Vault.sol";
import {IVaultProxy, IVaultLogic} from "./interface/IVault.sol";
import {Dexorder} from "./Dexorder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OrderLib} from "./OrderLib.sol";

// Inheritance order for stateful contracts must be consistent between Vault and VaultLogic
// This is the order: ReentrancyGuard, VaultState

contract VaultLogic is IVaultLogic, ReentrancyGuard, VaultState {

    uint8 constant public version = 1;
    function dexorder() view internal returns(Dexorder) {
        return Dexorder(IVaultProxy(address(this)).dexorder());
    }
    
    function numSwapOrders() external view returns (uint64 num) {
        return uint64(ordersInfo.orders.length);
    }

    // todo rename using dexorder and inform the method hash registries
    function placeDexorder(OrderLib.SwapOrder memory order) external onlyOwner nonReentrant {
        // feeSched() returns tuple, not struct!
        console2.log('placing order');
        Dexorder d = dexorder();
        (uint8 fillFeeBP,,,,) = d.feeSched(); // save fill fee in order
        OrderLib._placeOrder(ordersInfo, order, fillFeeBP);
        // console2.log("placeDexorder: fillFeeBP 1", order.fillFeeBP);
        // uint256 N = IVaultLogic(this).numSwapOrders();
        // console2.log("placeDexorder: fillFeeBP 2", ordersInfo.orders[N-1].order.fillFeeBP);
        // todo combine orderFee() and trancheFee() into a single call. this call could be made once in top-level funcs incl placeDexorders([])
        uint256 orderFee = d.orderFee();
        uint256 trancheFee = d.trancheFee(order.tranches.length);
        if (orderFee>0) {
            console2.log('sending order fee');
            console2.log(orderFee);
            d.orderFeeAccount().transfer(orderFee);
        }
        if (trancheFee>0) {
            console2.log('sending tranche fee');
            console2.log(trancheFee);
            d.trancheFeeAccount().transfer(trancheFee);
        }
        console2.log('order placed');
    }

    function placeDexorders(OrderLib.SwapOrder[] memory orders, OrderLib.OcoMode ocoMode) external onlyOwner nonReentrant {
        dexorder().orderFeeAccount().transfer(dexorder().orderFee() * orders.length);
        uint256 nTranches = 0;
        for( uint8 o = 0; o < orders.length; o++ ) {
            nTranches += orders[o].tranches.length;
        }
        (uint8 fillFeeBP,,,,) = dexorder().feeSched(); // save fill fee in order
        OrderLib._placeOrders(ordersInfo, orders, fillFeeBP, ocoMode);
        dexorder().trancheFeeAccount().transfer(dexorder().trancheFee(nTranches));
    }

    function swapOrderStatus(uint64 orderIndex) external view returns (OrderLib.SwapOrderStatus memory status) {
        return ordersInfo.orders[orderIndex];
    }

    function execute(uint64 orderIndex, uint8 tranche_index, OrderLib.PriceProof memory proof) external nonReentrant
    {
        uint256 amountOut =
            OrderLib.execute(ordersInfo, IVaultProxy(address(this)).owner(), orderIndex, tranche_index, proof);
        uint256 feeAmount = dexorder().fillFee(amountOut, ordersInfo.orders[orderIndex].fillFeeBP);
        // console2.log("feeAmount, fillFeeBP", feeAmount, ordersInfo.orders[orderIndex].order.fillFeeBP);
        IERC20(ordersInfo.orders[orderIndex].order.tokenOut).transfer(dexorder().fillFeeAccount(), feeAmount);
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
        require(msg.sender == IVaultProxy(address(this)).owner(), "not owner");
        _;
    }

}
