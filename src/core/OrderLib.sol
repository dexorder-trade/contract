// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import "forge-std/console2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Util} from "./Util.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEEE754, float} from "./IEEE754.sol";
import {IFeeManager} from "../interface/IFeeManager.sol";
import {IRouter} from "./IRouter.sol";


library OrderLib {

    uint64 internal constant NO_CONDITIONAL_ORDER = type(uint64).max;
    uint64 internal constant NO_OCO_INDEX = type(uint64).max;

    struct OrdersInfo {
        uint64 cancelAllIndex;
        SwapOrderStatus[] orders;
        OcoGroup[] ocoGroups;
    }

    event DexorderSwapPlaced (uint64 indexed startOrderIndex, uint8 numOrders);

    event DexorderSwapFilled (
        uint64 indexed orderIndex, uint8 indexed trancheIndex,
        uint256 amountIn, uint256 amountOut, uint256 fillFee // fill fee is taken from the out token
    );

    event DexorderSwapCanceled (uint64 orderIndex);

    event DexorderCancelAll (uint64 cancelAllIndex);

    enum Exchange {
        UniswapV2,  // 0
        UniswapV3   // 1
    }

    // todo does embedding Route into SwapOrder take a full word?
    struct Route {
        Exchange exchange;
        uint24 fee;
    }

    // Primary data structure for order specification. These fields are immutable after order placement.
    struct SwapOrder {
        address tokenIn;
        address tokenOut;
        Route route;
        uint256 amount;
        uint256 minFillAmount;  // if a tranche has less than this amount available to fill, it is considered completed
        bool amountIsInput;
        bool outputDirectlyToOwner;
        uint64 conditionalOrder; // use NO_CONDITIONAL_ORDER for no chaining. conditionalOrder index must be < than this order's index for safety (written first) and conditionalOrder state must be Template
        Tranche[] tranches;
        // we have 94 bits remaining in the last word
    }

    // "Status" includes dynamic information about the trade in addition to its static SwapOrder specification.
    struct SwapOrderStatus {
        SwapOrder order;
        // the fill fee is remembered from the active fee schedule at order creation time.
        // 1/20_000 "half bps" means the maximum representable value is 1.275%
        uint8 fillFeeHalfBps;
        bool canceled;
        uint32 start;
        // todo startPrice (rename start to startTime as well)  TODO adjust lines on order creation instead.
        uint64 ocoGroup;
        uint256 filled;  // total
        uint256[] trancheFilled;  // sum(trancheFilled) == filled
        uint32[] trancheActivationTime;  // related to rate limit: the earliest time at which each tranche can execute.
    }

    uint16 constant MAX_FRACTION = type(uint16).max;
    uint32 constant DISTANT_PAST = 0;
    uint32 constant DISTANT_FUTURE = type(uint32).max;


    struct Tranche {
        uint16  fraction;

        bool   startTimeIsRelative;
        bool   endTimeIsRelative;
        bool   minIsBarrier;
        bool   maxIsBarrier;
        bool   marketOrder;  // if true, both min and max lines are ignored, and minIntercept is treated as a maximum slippage value (use positive numbers)
        bool   minIsRatio;   // todo price isRatio: recalculate intercept
        bool   maxIsRatio;
        bool   _reserved7;
        uint16 rateLimitFraction;  // max fraction of this tranche's amount per rate-limited execution
        uint24 rateLimitPeriod;  // seconds between rate limit resets

        uint32 startTime;  // use DISTANT_PAST to effectively disable
        uint32 endTime;    // use DISTANT_FUTURE to effectively disable

        // if intercept and slope are both 0, the line is disabled
        // limit prices are always in terms of outputToken as the quote currency: prices are the expected output amount
        // per input amount
        float  minIntercept; // if marketOrder==true, this is the (positive) max slippage amount
        float  minSlope;
        float  maxIntercept;
        float  maxSlope;
    }

    struct PriceProof {
        // todo
        uint proof;
    }

    enum OcoMode {
        NO_OCO,
        CANCEL_ON_PARTIAL_FILL,
        CANCEL_ON_COMPLETION
    }

    struct OcoGroup {
        OcoMode mode;
        uint64 startIndex; // starting orderIndex of the group
        uint8 num;        // number of orders in the group
    }

    function _placementFee(SwapOrder memory order, IFeeManager.FeeSchedule memory sched) internal pure
    returns (uint256 orderFee, uint256 executionFee) {
        // console2.log('computing fee');
        // console2.log(sched.orderFee);
        // console2.log(sched.orderExp);
        // console2.log(sched.gasFee);
        // console2.log(sched.gasExp);
        // console2.log(sched.fillFeeHalfBps);
        orderFee = uint256(sched.orderFee) << sched.orderExp;
        // console2.log(orderFee);
        uint256 numExecutions = 0;
        for( uint i=0; i<order.tranches.length; i++ ) {
            uint16 rate = order.tranches[i].rateLimitFraction;
            uint256 exes;
            if (rate == 0)
                exes = 1;
            else {
                exes =  MAX_FRACTION / rate;
                // ceil
                if( exes * rate < MAX_FRACTION)
                    exes += 1;
            }
            // console2.log(exes);
            numExecutions += exes;
        }
        executionFee = numExecutions * (uint256(sched.gasFee) << sched.gasExp);
        // console2.log(executionFee);
        // console2.log('total fee');
        // console2.log(orderFee+executionFee);
    }

    function _placeOrder(OrdersInfo storage self, SwapOrder memory order, uint8 fillFeeHalfBps) internal {
        SwapOrder[] memory orders = new SwapOrder[](1);
        orders[0] = order;
        return _placeOrders(self,orders,fillFeeHalfBps,OcoMode.NO_OCO);
    }

    function _placeOrders(OrdersInfo storage self, SwapOrder[] memory orders, uint8 fillFeeHalfBps, OcoMode ocoMode) internal {
        require(orders.length < type(uint8).max);
        uint64 startIndex = uint64(self.orders.length);
        require(startIndex < type(uint64).max);
        uint64 ocoGroup;
        if( ocoMode == OcoMode.NO_OCO )
            ocoGroup = NO_OCO_INDEX;
        else if ( ocoMode == OcoMode.CANCEL_ON_PARTIAL_FILL || ocoMode == OcoMode.CANCEL_ON_COMPLETION ){
            ocoGroup = uint64(self.ocoGroups.length);
            self.ocoGroups.push(OcoGroup(ocoMode, startIndex, uint8(orders.length)));
        }
        else
            revert('OCOM');
        // todo get fee structure
        // console2.log('copying orders');
        // solc can't automatically generate the code to copy from memory to storage :( so we explicitly code it here
        for( uint8 o = 0; o < orders.length; o++ ) {
            SwapOrder memory order = orders[o];
            require(order.route.exchange == Exchange.UniswapV3, 'UR');  // UR = Unknown Route
            require(  // conditional order must be declared prior to this order, to prevent loops
                order.conditionalOrder == NO_CONDITIONAL_ORDER ||
                order.conditionalOrder < startIndex+o
            );
            // console2.log('exchange ok');
            // todo more order validation
            uint orderIndex = self.orders.length;
            self.orders.push();
            // console2.log('pushed');
            SwapOrderStatus storage status = self.orders[orderIndex];
            status.order.tokenIn = order.tokenIn;
            status.order.tokenOut = order.tokenOut;
            status.order.route = order.route;
            status.order.amount = order.amount;
            status.order.minFillAmount = order.minFillAmount;
            status.order.amountIsInput = order.amountIsInput;
            status.order.outputDirectlyToOwner = order.outputDirectlyToOwner;
            status.order.conditionalOrder = order.conditionalOrder;
            // console2.log('setting tranches');
            for( uint t=0; t<order.tranches.length; t++ ) {
                status.order.tranches.push(order.tranches[t]);
                status.trancheFilled.push(0);
                status.trancheActivationTime.push(0);
            }
            // console2.log('fee/oco');
            status.fillFeeHalfBps = fillFeeHalfBps;
            status.start = uint32(block.timestamp);
            // todo start price?
            status.ocoGroup = ocoGroup;
        }
        // console2.log('orders placed');
        emit DexorderSwapPlaced(startIndex,uint8(orders.length));
    }


    function execute(
        OrdersInfo storage self, address owner, uint64 orderIndex, uint8 trancheIndex,
        PriceProof memory, IRouter router, IFeeManager feeManager ) internal
    returns(uint256 amountOut) {
        // console2.log('execute');
        // console2.log(address(this));
        // console2.log(uint(orderIndex));
        // console2.log(uint(trancheIndex));
        SwapOrderStatus storage status = self.orders[orderIndex];
        if (_isCanceled(self, orderIndex))
            revert('NO'); // Not Open
        // todo check rate limit
        Tranche storage tranche = status.order.tranches[trancheIndex];

        // limit is passed to routes for slippage control. it is derived from the slippage variable if marketOrder is
        // true, otherwise from the minLine if it is set
        uint256 limit = 0;

        // enforce constraints

        // todo implement barriers
        if( tranche.minIsBarrier || tranche.maxIsBarrier )
            revert('NI');

        // time constraints
        uint32 time = tranche.startTimeIsRelative ? status.start + tranche.startTime : tranche.startTime;
        if (block.timestamp < time)
            revert('TE'); // time early
        time = tranche.endTimeIsRelative ? status.start + tranche.endTime : tranche.endTime;
        if (block.timestamp > time)
            revert('TL'); // time late

        // line constraints
        uint256 price;
        if( tranche.marketOrder ) {
            // todo slippage needs to be relative to the oracle mark not the current price
            /*
            console2.log('slippage');
            // minIntercept is interpreted as the slippage ratio
            uint256 slippage = uint256(IEEE754.toFixed(tranche.minIntercept, 96));
            console2.log(slippage);
            uint256 delta = (price * slippage) >> 96;
            limit = status.order.tokenIn > status.order.tokenOut ? price + delta : price - delta; // todo is this correct?
            */
            // console2.log('market order');
        }
        else {
            // check min line
            if( float.unwrap(tranche.minIntercept) != 0 || float.unwrap(tranche.minSlope) != 0 ) {
                price = router.price(status.order.route.exchange, status.order.tokenIn,
                    status.order.tokenOut, status.order.route.fee);
                // console2.log('price');
                // console2.log(price);
                limit = _linePrice(tranche.minIntercept, tranche.minSlope);
                // console2.log('min line limit');
                // console2.log(limit);
                require( price > limit, 'LL' );
            }
            // check max line
            if( float.unwrap(tranche.maxIntercept) != 0 || float.unwrap(tranche.maxSlope) != 0 ) {
                // price may have been already initialized by the min line
                if( price == 0 ) {
                    price = router.price(status.order.route.exchange, status.order.tokenIn,
                        status.order.tokenOut, status.order.route.fee);
                    // console2.log('price');
                    // console2.log(price);
                }
                uint256 maxPrice = _linePrice(tranche.maxIntercept, tranche.maxSlope);
                // console2.log('max line limit');
                // console2.log(limit);
                require( price < maxPrice, 'LU' );
            }
        }

//        console2.log('computing amount');
//        console2.log(status.order.amount);
//        console2.log(tranche.fraction);
//        console2.log(status.order.amountIsInput);
//        console2.log(status.filled);
//        console2.log(status.trancheFilled[trancheIndex]);
        uint256 amount = status.order.amount * tranche.fraction / MAX_FRACTION // the most this tranche could do
                         - status.trancheFilled[trancheIndex]; // minus tranche fills
        // console2.log('amount');
        // console2.log(amount);
        // console2.log('price');
        // console2.log(price);
        // console2.log('limit');
        // console2.log(limit);
        // order amount remaining
        require( status.filled <= status.order.amount, 'OVR' );
        uint256 remaining = status.order.amount - status.filled;
        // console2.log('remaining');
        // console2.log(remaining);
        if (amount > remaining)  // not more than the order's overall remaining amount
            amount = remaining;
        require( amount >= status.order.minFillAmount, 'TF' );
        // console2.log(amount);
        address recipient = status.order.outputDirectlyToOwner ? owner : address(this);
        // console2.log(recipient);
        uint256 amountIn;

        // Order has been approved. Send to router for swap execution.
        IRouter.SwapParams memory swapParams = IRouter.SwapParams(
            status.order.tokenIn, status.order.tokenOut, recipient,
            amount, status.order.minFillAmount, status.order.amountIsInput, limit, status.order.route.fee);
        // DELEGATECALL
        (bool success, bytes memory result) = address(router).delegatecall(
            abi.encodeWithSelector(IRouter.swap.selector, status.order.route.exchange, swapParams)
        );
        if (!success) {
            if (result.length > 0) { // if there was a reason given, forward it
                assembly {
                    let size := mload(result)
                    revert(add(32, result), size)
                }
            }
            else
                revert();
        }
        // delegatecall succeeded
        (amountIn, amountOut) = abi.decode(result, (uint256, uint256));

        // Update filled amounts
        amount = status.order.amountIsInput ? amountIn : amountOut;
        status.filled += amount;
        status.trancheFilled[trancheIndex] += amount;

        // todo compute next rate limit

        // fill fee
        uint256 fillFee = amountOut * status.fillFeeHalfBps / 20_000;
        IERC20(status.order.tokenOut).transfer(feeManager.fillFeeAccount(), fillFee);

        emit DexorderSwapFilled(orderIndex, trancheIndex, amountIn, amountOut, fillFee);
        // console2.log('emitted DexorderSwapFilled event');
        _checkCompleted(self, status);
        // console2.log('orderlib execute completed');
    }


    // the price fixed-point standard is 96 decimal bits

    function _linePrice(float intercept, float slope) private view returns (uint256 price) {
        int256 b = IEEE754.toFixed(intercept, 96);
        if( float.unwrap(slope) == 0 )
            return uint256(b);
        int256 m = IEEE754.toFixed(slope, 96);
        int256 x = int256(block.timestamp);
        // steep lines may overflow any bitwidth quickly, but this would be merely a numerical error not a semantic one.
        // we handle overflows here explicitly, bounding the result to the range [0,MAXINT]
        unchecked {
            int256 p = m * x + b;
            if ((p - b) / m == x)
                price = p <= 0 ? 0 : uint256(p);
            else // overflow
                price = IEEE754.isPositive(slope) ? type(uint256).max : 0;
        }
    }


    function _checkCompleted(OrdersInfo storage self, SwapOrderStatus storage status) internal {
        uint256 remaining = status.order.amount - status.filled;
        if( remaining < status.order.minFillAmount )  {
            // we already get fill events so completion may be inferred without an extra Completion event
            if( status.ocoGroup != NO_OCO_INDEX)
                _cancelOco(self, status.ocoGroup);
        }
        else if( status.ocoGroup != NO_OCO_INDEX && self.ocoGroups[status.ocoGroup].mode == OcoMode.CANCEL_ON_PARTIAL_FILL )
            _cancelOco(self, status.ocoGroup);
    }

    function _cancelOco(OrdersInfo storage self, uint64 ocoIndex) internal {
        OcoGroup storage group = self.ocoGroups[ocoIndex];
        uint64 endIndex = group.startIndex + group.num;
        for( uint64 i=group.startIndex; i<endIndex; i++ )
            _cancelOrder(self, i);
    }

    function _cancelOrder(OrdersInfo storage self, uint64 orderIndex) internal {
        self.orders[orderIndex].canceled = true;
        emit DexorderSwapCanceled(orderIndex);
    }

    function _cancelAll(OrdersInfo storage self) internal {
        // All open orders will be considered cancelled.
        self.cancelAllIndex = uint64(self.orders.length);
        emit DexorderCancelAll(self.cancelAllIndex);
    }

    function _isCanceled(OrdersInfo storage self, uint64 orderIndex) internal view returns(bool) {
        return orderIndex < self.cancelAllIndex || self.orders[orderIndex].canceled;
    }

}
