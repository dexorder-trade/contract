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
import {IUniswapV3Factory} from "../../lib_uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IRouter} from "./IRouter.sol";


// There is only one VaultLogic contract deployed, which is shared by all Vaults. When the vault proxy calls into
// the logic contract, the original Vault's state is used. So here the VaultLogic inherits the vault state but in
// usage, this state will be the state of the calling Vault, not of the deployed VaultLogic contract instance.

contract VaultLogic is IVaultLogic, VaultState {

    uint256 constant public version = 1;

    IFeeManager public immutable feeManager;
    IRouter private immutable router;

    constructor( IRouter router_, IFeeManager feeManager_ ) {
        router = router_;
        feeManager = feeManager_;
    }

    function numSwapOrders() external view returns (uint64 num) {
        return uint64(_ordersInfo.orders.length);
    }

    function placementFee(OrderLib.SwapOrder memory order, IFeeManager.FeeSchedule memory sched) public pure
    returns (uint256 orderFee, uint256 gasFee) {
        return OrderLib._placementFee(order, sched);
    }

    function placementFee(OrderLib.SwapOrder[] memory orders, IFeeManager.FeeSchedule memory sched) public pure
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
        console2.log('placing order');
        IFeeManager.FeeSchedule memory sched = feeManager.fees();
        (uint256 orderFee, uint256 gasFee) = OrderLib._placementFee(order, sched);
        // We force the value to be sent with the message so that the user can see the fee immediately in their wallet
        // software before they confirm the transaction.  If the user overpays, the extra amount is refunded.
        _takeFee(payable(msg.sender), orderFee, gasFee);
        OrderLib._placeOrder(_ordersInfo, order, sched.fillFeeHalfBps);
        console2.log('order placed');
    }

    function placeDexorders(OrderLib.SwapOrder[] memory orders, OrderLib.OcoMode ocoMode) external payable onlyOwner nonReentrant {
        console2.log('placing orders');
        IFeeManager.FeeSchedule memory sched = feeManager.fees();
        (uint256 orderFee, uint256 gasFee) = placementFee(orders, sched);
        _takeFee(payable(msg.sender), orderFee, gasFee);
        OrderLib._placeOrders(_ordersInfo, orders, sched.fillFeeHalfBps, ocoMode);
        console2.log('orders placed');
    }

    function _takeFee( address payable sender, uint256 orderFee, uint256 gasFee ) internal {
        require( msg.value >= orderFee + gasFee, 'FEE');
        if (orderFee > 0)
            feeManager.orderFeeAccount().transfer(orderFee);
        if (gasFee > 0)
            feeManager.gasFeeAccount().transfer(gasFee);
        uint256 totalFee = orderFee + gasFee;
        if (totalFee < msg.value) {
            uint256 refund = msg.value - totalFee;
            console2.log('refunding fee');
            console2.log(refund);
            sender.transfer(refund);
        }
    }

    function swapOrderStatus(uint64 orderIndex) external view returns (OrderLib.SwapOrderStatus memory status) {
        return _ordersInfo.orders[orderIndex];
    }

    function execute(uint64 orderIndex, uint8 tranche_index, OrderLib.PriceProof memory proof) external nonReentrant
    {
        address payable t = payable(address(this));
        IVaultProxy proxy = IVaultProxy(t);
        address owner = proxy.owner();
        OrderLib.execute(_ordersInfo, owner, orderIndex, tranche_index, proof, router, feeManager);
    }

    function cancelDexorder(uint64 orderIndex) external onlyOwner nonReentrant {
        OrderLib._cancelOrder(_ordersInfo,orderIndex);
    }

    function cancelAllDexorders() external onlyOwner nonReentrant {
        OrderLib._cancelAll(_ordersInfo);
    }

    function orderCanceled(uint64 orderIndex) external view returns (bool) {
        require( orderIndex < _ordersInfo.orders.length );
        return OrderLib._isCanceled(_ordersInfo, orderIndex);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "not owner");
        _;
    }

}
