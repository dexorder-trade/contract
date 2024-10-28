
pragma solidity 0.8.26;

import {console2} from "@forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFeeManager} from "../interface/IFeeManager.sol";
import {IVaultProxy, IVaultImpl} from "../interface/IVault.sol";
import {VaultStorage} from "./Vault.sol";
import {Dexorder} from "../more/Dexorder.sol";
import "./OrderSpec.sol";
import {OrderLib} from "./OrderLib.sol";
import {IUniswapV3Factory} from "../../lib_uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IRouter} from "../interface/IRouter.sol";
import {IWETH9} from "../../lib_uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";
import {UniswapV3Arbitrum} from "./UniswapV3.sol";


// There is only one VaultImpl contract deployed, which is shared by all Vaults. When the vault proxy calls into
// the implementation contract, the original Vault's state is used. So here the VaultImpl inherits the vault state but in
// usage, this state will be the state of the calling Vault, not of the deployed VaultImpl contract instance.

contract VaultImpl is IVaultImpl, VaultStorage {

    uint256 constant public version = 2;

    IFeeManager public immutable feeManager;
    IRouter private immutable router;
    IWETH9 private immutable weth9;

    constructor( IRouter router_, IFeeManager feeManager_, address weth9_ ) {
        router = router_;
        feeManager = feeManager_;
        weth9 = IWETH9(weth9_);
    }

    function numSwapOrders() external view returns (uint64 num) {
        return uint64(_ordersInfo.orders.length);
    }

    function placementFee(SwapOrder memory order, IFeeManager.FeeSchedule memory sched) public view
    returns (uint256 orderFee, uint256 gasFee) {
        return _placementFee(order,sched);
    }

    function _placementFee(SwapOrder memory order, IFeeManager.FeeSchedule memory sched) internal view
    returns (uint256 orderFee, uint256 gasFee) {
        if (order.conditionalOrder == NO_CONDITIONAL_ORDER)
            return OrderLib._placementFee(order, sched);
        uint64 condiIndex = OrderLib._conditionalOrderIndex(uint64(_ordersInfo.orders.length), order.conditionalOrder);
        SwapOrder memory condi = _ordersInfo.orders[condiIndex].order;
        return OrderLib._placementFee(order, sched, condi);

    }

    function placementFee(SwapOrder[] memory orders, IFeeManager.FeeSchedule memory sched) public view
    returns (uint256 orderFee, uint256 gasFee) {
        orderFee = 0;
        gasFee = 0;
        for( uint i=0; i<orders.length; i++ ) {
            (uint256 ofee, uint256 efee) = _placementFee(orders[i], sched);
            orderFee += ofee;
            gasFee += efee;
        }
    }

    function placeDexorder(SwapOrder memory order) external payable onlyOwner nonReentrant {
        // console2.log('placing order');
        IFeeManager.FeeSchedule memory sched = feeManager.fees();
        (uint256 orderFee, uint256 gasFee) = OrderLib._placementFee(order, sched);
        // We force the value to be sent with the message so that the user can see the fee immediately in their wallet
        // software before they confirm the transaction.  If the user overpays, the extra amount is refunded.
        _takeFee(payable(msg.sender), orderFee, gasFee);
        uint64 startIndex = uint64(_ordersInfo.orders.length);
        OrderLib._placeOrder(_ordersInfo, order, sched.fillFeeHalfBps, router);
        emit DexorderSwapPlaced(startIndex, 1, orderFee, gasFee);
        // console2.log('order placed');
    }

    function placeDexorders(SwapOrder[] memory orders, OcoMode ocoMode) external payable onlyOwner nonReentrant {
        // console2.log('placing orders');
        IFeeManager.FeeSchedule memory sched = feeManager.fees();
        (uint256 orderFee, uint256 gasFee) = placementFee(orders, sched);
        _takeFee(payable(msg.sender), orderFee, gasFee);
        uint64 startIndex = uint64(_ordersInfo.orders.length);
        OrderLib._placeOrders(_ordersInfo, orders, sched.fillFeeHalfBps, ocoMode, router);
        emit DexorderSwapPlaced(startIndex, uint8(orders.length), orderFee, gasFee);
        // console2.log('orders placed');
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
            // console2.log('refunding fee');
            // console2.log(refund);
            sender.transfer(refund);
        }
    }

    function swapOrderStatus(uint64 orderIndex) external view returns (SwapOrderStatus memory status) {
        return _ordersInfo.orders[orderIndex];
    }

    function execute(uint64 orderIndex, uint8 tranche_index, PriceProof memory proof) external nonReentrant
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
        require( orderIndex < _ordersInfo.orders.length, 'OI' );
        return OrderLib._isCanceled(_ordersInfo, orderIndex);
    }

    function vaultImplDidChange(address oldAddress) external {
    }

    function wrapper() external view returns (address) { return address(weth9); }

    function wrap(uint256 amount) external onlyOwner nonReentrant {
        require(address(weth9)!=address(0),'WU');
        weth9.deposit{value:amount}();
    }

    function unwrap(uint256 amount) external onlyOwner nonReentrant {
        require(address(weth9)!=address(0),'WU');
        weth9.withdraw(amount);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "not owner");
        _;
    }

}


contract ArbitrumVaultImpl is VaultImpl {
    constructor(IRouter router_, IFeeManager feeManager_)
        VaultImpl(router_, feeManager_, address(UniswapV3Arbitrum.weth9))
    {}
}
