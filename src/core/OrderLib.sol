
pragma solidity 0.8.26;

import "@forge-std/console2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {Util} from "./Util.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEEE754, float} from "./IEEE754.sol";
import {IFeeManager} from "../interface/IFeeManager.sol";
import {IRouter} from "../interface/IRouter.sol";
import "./OrderSpec.sol";
import "./LineLib.sol";


library OrderLib {
    using IEEE754 for float;
    using LineLib for Line;

    function _placementFee(SwapOrder memory order, IFeeManager.FeeSchedule memory sched, SwapOrder memory conditionalOrder) internal pure
    returns (uint256 orderFee, uint256 executionFee) {
        // Conditional orders are charged for execution but not placement.
        if (order.amount==0)
            return (0,0);
        orderFee = _orderFee(sched);
        executionFee = _executionFee(order, sched, conditionalOrder);  // special execution fee
    }


    function _placementFee(SwapOrder memory order, IFeeManager.FeeSchedule memory sched) internal pure
    returns (uint256 orderFee, uint256 executionFee) {
        // Place conditional orders using a zero amount to avoid placement fees on that conditional. Fees will be
        // charged instead to any order which references the conditional order.
        if (order.amount==0)
            return (0,0);
        // console2.log('computing fee');
        // console2.log(sched.orderFee);
        // console2.log(sched.orderExp);
        // console2.log(sched.gasFee);
        // console2.log(sched.gasExp);
        // console2.log(sched.fillFeeHalfBps);
        orderFee = _orderFee(sched);
        // console2.log(orderFee);
        executionFee = _executionFee(order, sched);
        // console2.log('total fee');
        // console2.log(orderFee+executionFee);
    }


    function _orderFee(IFeeManager.FeeSchedule memory sched) internal pure
    returns (uint256 orderFee) {
        orderFee = uint256(sched.orderFee) << sched.orderExp;
    }

    function _executionFee(SwapOrder memory order, IFeeManager.FeeSchedule memory sched) internal pure
    returns (uint256 executionFee) {
        executionFee = _numExecutions(order) * (uint256(sched.gasFee) << sched.gasExp);
    }

    function _executionFee(SwapOrder memory order, IFeeManager.FeeSchedule memory sched, SwapOrder memory conditionalOrder) internal pure
    returns (uint256 executionFee) {
        (uint256 orderFee, uint256 gasFee) =  _placementFee(conditionalOrder, sched);
        uint256 placementFee = orderFee + gasFee;
        executionFee = _numExecutions(order) * placementFee;
    }

    function _numExecutions(SwapOrder memory order) internal pure
    returns (uint256 numExecutions) {
        numExecutions = 0;
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
    }

    function _placeOrder(OrdersInfo storage self, SwapOrder memory order, uint8 fillFeeHalfBps, IRouter router) internal {
        SwapOrder[] memory memOrders = new SwapOrder[](1);
        memOrders[0] = order;
        return _placeOrders(self,memOrders,fillFeeHalfBps,OcoMode.NO_OCO, router);
    }

    function _placeOrders(OrdersInfo storage self, SwapOrder[] memory memOrders, uint8 fillFeeHalfBps, OcoMode ocoMode, IRouter router) internal {
        // console2.log('_placeOrders');
        require(memOrders.length < type(uint8).max, 'TMO'); // TMO = Too Many Orders
        require(self.orders.length < type(uint64).max - memOrders.length, 'TMO');
        uint64 startIndex = uint64(self.orders.length);
        uint64 ocoGroup;
        if( ocoMode == OcoMode.NO_OCO )
            ocoGroup = NO_OCO_INDEX;
        else if ( ocoMode == OcoMode.CANCEL_ON_PARTIAL_FILL || ocoMode == OcoMode.CANCEL_ON_COMPLETION ){
            ocoGroup = uint64(self.ocoGroups.length);
            self.ocoGroups.push(OcoGroup(ocoMode, startIndex, uint8(memOrders.length)));
        }
        else
            revert('OCOM');
        // console2.log('copying orders');
        // solc can't automatically generate the code to copy from memory to storage :( so we explicitly code it here
        for( uint8 o = 0; o < memOrders.length; o++ ) {
            SwapOrder memory order = memOrders[o];
            require(order.route.exchange == Exchange.UniswapV3, 'UR');  // UR = Unknown Route

            //NOTE: Conditional orders must not form a loop, so we disallow a conditional order that places another conditional order
            //There are many reasons this could be dangerous, one of which is that a conditional order loop could create a runaway
            //scenario where much more quantity is swapped than intended (e.g., a market order for limited quantity looping on itself,
            //resulting in unlimited quantity).
            //
            //Also note that for CONDITIONAL_ORDER_IN_CURRENT_GROUP, the referenced order must be PRIOR to the instant order, otherwise
            //the transaction will revert because `coIndex` below will be out of bounds.

            if (order.conditionalOrder != NO_CONDITIONAL_ORDER) {
                uint64 coIndex = _conditionalOrderIndex(startIndex, order.conditionalOrder);
                order.conditionalOrder = coIndex;  // replace any relative indexing with an absolute index

                //NOTE: `order` is in `memory` so replacing `order.conditionalOrder` cannot affect any existing `condi` referenced below
                //If you change the order of operations or memory/storage in this code, be very careful about the require() check below.

                require(
                    coIndex < self.orders.length, // conditional order
                    'COI' // COI = conditional order index violation
                );
                SwapOrderStatus storage condi = self.orders[coIndex]; //coIndex must therefore be a PRIOR placed order.
                require(
                    // this order's output token must match the conditional order's input token
                    order.tokenOut == condi.order.tokenIn
                    // amountIsInput must be true
                    && condi.order.amountIsInput
                    // cannot have any amount of its own
                    && condi.order.amount == 0
                    // cannot chain a conditional order into another conditional order (prevent loops)
                    && condi.order.conditionalOrder == NO_CONDITIONAL_ORDER,
                    'COS' // COS = conditional order suitability
                );
            }
            _createOrder(self, order, fillFeeHalfBps, ocoGroup, router, NO_CONDITIONAL_ORDER);
        }
        // console2.log('orders placed');
    }

    uint64 constant internal CONDITIONAL_ORDER_IN_CURRENT_GROUP_MASK = CONDITIONAL_ORDER_IN_CURRENT_GROUP - 1;

    function _conditionalOrderIndex(uint64 startIndex, uint64 coIndex) internal pure
    returns (uint64 index){
        // If the high bit (CONDITIONAL_ORDER_IN_CURRENT_GROUP) is set, then the index is relative to the
        // start of the order placement batch
        index = coIndex & CONDITIONAL_ORDER_IN_CURRENT_GROUP == 0 ? coIndex :
            startIndex + CONDITIONAL_ORDER_IN_CURRENT_GROUP_MASK & coIndex;
    }

    function _prepTrancheStatus(Tranche memory tranche, TrancheStatus storage trancheStatus, uint32 startTime) internal {
        trancheStatus.startTime = (tranche.startTimeIsRelative ? startTime + tranche.startTime: tranche.startTime);
        trancheStatus.endTime = (tranche.endTimeIsRelative ? startTime + tranche.endTime: tranche.endTime);
        trancheStatus.activationTime = trancheStatus.startTime;
    }

    function _createOrder(OrdersInfo storage self, SwapOrder memory order, uint8 fillFeeHalfBps, uint64 ocoGroup, IRouter router, uint64 origIndex ) internal
    returns (uint64 orderIndex)
    {
        // console2.log('exchange ok');
        // todo more order validation
        uint32 startTime = uint32(block.timestamp);
        orderIndex = uint64(self.orders.length);
        self.orders.push();
        // console2.log('pushed');
        SwapOrderStatus storage status = self.orders[orderIndex];
        status.order = order;
        status.fillFeeHalfBps = fillFeeHalfBps;
        status.startTime = startTime;
        status.ocoGroup = ocoGroup;
        status.originalOrder = origIndex;
        // console2.log('setting tranches');
        bool needStartPrice = false;
        for( uint t=0; t<order.tranches.length; t++ ) {
            Tranche memory tranche = order.tranches[t];

            // todo implement barriers
            if( tranche.minIsBarrier || tranche.maxIsBarrier )
                revert('NI');  // Not Implemented

            status.trancheStatus.push();
            _prepTrancheStatus(tranche,status.trancheStatus[t],startTime);
            if (tranche.minIsRatio || tranche.maxIsRatio)
                needStartPrice = true;
            require(!tranche.marketOrder || !tranche.minLine.intercept.isNegative(), 'NSL');  // negative slippage
        }
        // console2.log('fee/oco');
        if (needStartPrice)
            status.startPrice = router.protectedPrice(order.route.exchange, order.tokenIn, order.tokenOut, order.route.fee, order.inverted);
    }


    struct ExecuteVars {
        uint256 price;
        // limit is passed to routes for slippage control. It is derived from the slippage variable if marketOrder is
        // true, otherwise from the minLine if it is set
        uint256 limit;
        uint256 amountIn;
        uint256 fillFee;
        uint256 trancheAmount;
        uint256 limitedAmount;
        uint256 amount;
        uint256 remaining;
    }


    function execute(
        OrdersInfo storage self, address owner, uint64 orderIndex, uint8 trancheIndex,
        PriceProof memory, IRouter router, IFeeManager feeManager ) internal
    returns(uint256 amountOut) {
        // Reference the tranche and validate open/available
        SwapOrderStatus storage status = self.orders[orderIndex];
        if (_isCanceled(self, orderIndex))
            revert('NO'); // Not Open
        SwapOrder storage order = status.order;
        Tranche storage tranche = status.order.tranches[trancheIndex];
        TrancheStatus storage tStatus = status.trancheStatus[trancheIndex];

        ExecuteVars memory v;

        //
        // Enforce constraints
        //

        // time constraints
        require(block.timestamp < tStatus.endTime, 'TL');  // Time Late
        require(block.timestamp >= tStatus.startTime, 'TE');  // Time Early
        require(block.timestamp >= tStatus.activationTime, 'RL');  // Rate Limited

        // market order slippage control: we overload minLine.intercept to store slippage value
        if( tranche.marketOrder && !tranche.minLine.intercept.isZero() ) {
            // console2.log('slippage');
            uint256 protectedPrice = router.protectedPrice(order.route.exchange, order.tokenIn,
                order.tokenOut, order.route.fee, order.inverted);
            // minLine.intercept is interpreted as the slippage ratio
            uint256 slippage = uint256(tranche.minLine.intercept.toFixed(96));
            bool buy = (order.tokenIn > order.tokenOut) != order.inverted;
            v.limit = buy ?
                FullMath.mulDiv( protectedPrice, 2**96+slippage, 2**96) :
                FullMath.mulDiv( protectedPrice, 2**96, 2**96+slippage);
            // console2.log(protectedPrice);
            // console2.log(slippage);
            // console2.log(buy);
            // console2.log(v.limit);
        }

        // line constraints
        // price math is done in the linspace determined by order.inverted.
        else {
            v.price = 0;
            // check min line
            if( tranche.minLine.isEnabled() ) {
                v.price = router.rawPrice(order.route.exchange, order.tokenIn,
                    order.tokenOut, order.route.fee, order.inverted);
                // console2.log('price', v.price);
                uint256 minPrice = tranche.minIsRatio ?
                    tranche.minLine.ratioPrice(status.startTime, status.startPrice) :
                    tranche.minLine.priceNow();
                // console2.log('min line limit', v.limit);
                // console2.log('price', v.price);
                require( v.price > minPrice, 'LL' );
                if ((order.tokenIn < order.tokenOut) != order.inverted)
                    v.limit = minPrice;
            }
            // check max line
            if( tranche.maxLine.isEnabled()) {
                // price may have been already initialized by the min line
                if( v.price == 0 ) {  // don't look it up a second time if we already have it.
                    v.price = router.rawPrice(order.route.exchange, order.tokenIn,
                        order.tokenOut, order.route.fee, order.inverted);
                    // console2.log('price');
                    // console2.log(v.price);
                }
                uint256 maxPrice = tranche.maxIsRatio ?
                    tranche.maxLine.ratioPrice(status.startTime, status.startPrice) :
                    tranche.maxLine.priceNow();
                // console2.log('max line limit');
                // console2.log(maxPrice);
                require( v.price <= maxPrice, 'LU' );
                if ((order.tokenIn > order.tokenOut) != order.inverted)
                    v.limit = maxPrice;
            }
        }

        // compute size
        v.trancheAmount = order.amount * tranche.fraction / MAX_FRACTION; // the most this tranche could do
        v.amount = v.trancheAmount - tStatus.filled; // minus tranche fills
        if (tranche.rateLimitFraction != 0) {
            // rate limit sizing
            v.limitedAmount = v.trancheAmount * tranche.rateLimitFraction / MAX_FRACTION;
            if (v.amount > v.limitedAmount)
                v.amount = v.limitedAmount;
        }
        // order amount remaining
        v.remaining = order.amount - status.filled;
        if (v.amount > v.remaining)  // not more than the order's overall remaining amount
            v.amount = v.remaining;
        require( v.amount >= order.minFillAmount, 'TF' );
        address recipient = order.outputDirectlyToOwner ? owner : address(this);
        IERC20 outToken = IERC20(order.tokenOut);
        // this variable is only needed for calculating the amount to forward to a conditional order, so we set it to 0 otherwise
        uint256 startingTokenOutBalance = order.conditionalOrder == NO_CONDITIONAL_ORDER ? 0 : outToken.balanceOf(address(this));

        //
        // Order has been approved. Send to router for swap execution.
        //

        // console2.log('router request:');
        // console2.log(order.tokenIn);
        // console2.log(order.tokenOut);
        // console2.log(recipient);
        // console2.log(v.amount);
        // console2.log(order.minFillAmount);
        // console2.log(order.amountIsInput);
        // console2.log(v.limit);
        // console2.log(order.route.fee);
        IRouter.SwapParams memory swapParams = IRouter.SwapParams(
            order.route.exchange, order.tokenIn, order.tokenOut, recipient,
            v.amount, order.minFillAmount, order.amountIsInput,
            order.inverted, v.limit, order.route.fee);
        // DELEGATECALL
        (bool success, bytes memory result) = address(router).delegatecall(
            abi.encodeWithSelector(IRouter.swap.selector, swapParams));
        if (!success) {
            if (result.length > 0) { // if there was a reason given, forward it
                assembly ("memory-safe") {
                    let size := mload(result)
                    revert(add(32, result), size)
                }
            }
            else
                revert();
        }
        // delegatecall succeeded
        (v.amountIn, amountOut) = abi.decode(result, (uint256, uint256));

        // console2.log('swapped');

        // Update filled amounts
        v.amount = order.amountIsInput ? v.amountIn : amountOut;
        status.filled += v.amount;
        tStatus.filled += v.amount;

        // Update rate limit timing
        if (v.limitedAmount != 0) {
            // Rate limited.  Compute the timestamp of the earliest next execution
            tStatus.activationTime = uint32(block.timestamp + v.amount * tranche.rateLimitPeriod / v.limitedAmount );
        }

        // Take fill fee
        v.fillFee = amountOut * status.fillFeeHalfBps / 20_000;
        outToken.transfer(feeManager.fillFeeAccount(), v.fillFee);

        emit DexorderSwapFilled(orderIndex, trancheIndex, v.amountIn, amountOut, v.fillFee, tStatus.activationTime);

        // Conditional order placement
        // Fees for conditional orders are taken up-front by the VaultImpl and are not charged here.
        if (order.conditionalOrder != NO_CONDITIONAL_ORDER) {
            // the conditional order index will have been converted to an absolute index during placement
            SwapOrder memory condi = self.orders[order.conditionalOrder].order;
            // the amount forwarded will be different than amountOut due to our fee and possible token transfer taxes
            condi.amount = outToken.balanceOf(address(this)) - startingTokenOutBalance;
            // fillFee is preserved
            uint64 condiOrderIndex = _createOrder(
                self, condi, status.fillFeeHalfBps,
                NO_OCO_INDEX, router, order.conditionalOrder);
            emit DexorderSwapPlaced(condiOrderIndex, 1, 0, 0); // zero fees
        }

        // Check order completion and OCO canceling
        uint256 remaining = order.amount - status.filled;
        if( remaining < order.minFillAmount )  {
            // we already get fill events so completion may be inferred without an extra Completion event
            if( status.ocoGroup != NO_OCO_INDEX)
                _cancelOco(self, status.ocoGroup);
        }
        else if( status.ocoGroup != NO_OCO_INDEX && self.ocoGroups[status.ocoGroup].mode == OcoMode.CANCEL_ON_PARTIAL_FILL )
            _cancelOco(self, status.ocoGroup);

        // console2.log('orderlib execute completed');
    }


    // the price fixed-point standard is 96 decimal bits

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
