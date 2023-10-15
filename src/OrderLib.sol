// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./UniswapSwapper.sol";
import "forge-std/console2.sol";


library OrderLib {
    // todo safe math and/or bounds checking

    uint64 internal constant NO_CHAIN = type(uint64).max;
    uint64 internal constant NO_OCO_INDEX = type(uint64).max;

    struct OrdersInfo {
        bool _ignored; // workaround for Solidity bug where a public struct member cannot start with an array of uncertain size
        SwapOrderStatus[] orders;
        OcoGroup[] ocoGroups;
    }

    event DexorderSwapPlaced (uint64 startOrderIndex, uint8 numOrders);

    event DexorderSwapFilled (uint64 orderIndex, uint8 trancheIndex, uint256 amountIn, uint256 amountOut);

    event DexorderSwapCompleted (uint64 orderIndex); // todo remove?

    event DexorderSwapError (uint64 orderIndex, string reason);

    enum SwapOrderState {
        Open, Canceled, Filled, Expired // Expired isn't ever shown on-chain. the Expired state is implied by tranche constraints.
    }

    enum Exchange {
        UniswapV2,
        UniswapV3
    }

    struct Route {
        Exchange exchange;
        uint24 fee;
    }

    struct SwapOrder {
        address tokenIn;
        address tokenOut;
        Route route;
        uint256 amount;
        bool amountIsInput;
        bool outputDirectlyToOwner;
        uint64 chainOrder; // use NO_CHAIN for no chaining. chainOrder index must be < than this order's index for safety (written first) and chainOrder state must be Template
        Tranche[] tranches;
    }

    struct SwapOrderStatus {
        SwapOrder order;
        SwapOrderState state;
        uint32 start;
        uint64 ocoGroup;
        uint256 filledIn;  // total
        uint256 filledOut; // total
        uint256[] trancheFilledIn;  // sum(trancheFilledIn) == filledIn
        uint256[] trancheFilledOut; // sum(trancheFilledOut) == filledOut
    }

    enum ConstraintMode {
        Time,
        Limit,
        Trailing,
        Barrier,
        Line
    }

    struct Constraint {
        ConstraintMode mode; // type information
        bytes constraint;    // abi packed-encoded constraint struct: decode according to mode
    }

    struct PriceConstraint {
        bool isAbove;
        bool isRatio;
        uint160 valueSqrtX96;
    }

    struct LineConstraint {
        bool isAbove;
        bool isRatio;
        uint32 time;
        uint160 valueSqrtX96;
        int160 slopeSqrtX96; // price change per second
    }

    enum TimeMode {
        Timestamp, // absolute timestamp
        SinceOrderStart // relative to order creation (useful for chained orders)
    }

    struct Time {
        TimeMode mode;
        uint32 time;
    }

    uint32 constant DISTANT_PAST = 0;
    uint32 constant DISTANT_FUTURE = type(uint32).max;

    struct TimeConstraint {
        Time earliest;
        Time latest;
    }

    struct Tranche {
        uint16 fraction; // fraction of the order amount is available to this tranche, where type(uint16).max == 100%
        Constraint[] constraints;
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

    function _placeOrder(OrdersInfo storage self, SwapOrder memory order) internal {
        console2.log('OrderLib._placeOrder()');
        SwapOrder[] memory orders = new SwapOrder[](1);
        orders[0] = order;
        return _placeOrders(self,orders,OcoMode.NO_OCO);
    }

    function _placeOrders(OrdersInfo storage self, SwapOrder[] memory orders, OcoMode ocoMode) internal {
        console2.log('_placeOrders A');
        require(orders.length < type(uint8).max);
        console2.log('_placeOrders B');
        uint64 startIndex = uint64(self.orders.length);
        require(startIndex < type(uint64).max);
        console2.log('_placeOrders C');
        uint64 ocoGroup;
        if( ocoMode == OcoMode.NO_OCO )
            ocoGroup = NO_OCO_INDEX;
        else if ( ocoMode == OcoMode.CANCEL_ON_PARTIAL_FILL || ocoMode == OcoMode.CANCEL_ON_COMPLETION ){
            ocoGroup = uint64(self.ocoGroups.length);
            self.ocoGroups.push(OcoGroup(ocoMode, startIndex, uint8(orders.length)));
        }
        else
            revert('OCOM');
        console2.log('_placeOrders D');
        for( uint8 o = 0; o < orders.length; o++ ) {
            SwapOrder memory order = orders[o];
            require(order.route.exchange == Exchange.UniswapV3, 'UR');
            console2.log('_placeOrders E');
            // todo more order validation
            // we must explicitly copy into storage because Solidity doesn't implement copying the double-nested
            // tranches constraints array :(
            uint orderIndex = self.orders.length;
            self.orders.push();
            SwapOrderStatus storage status = self.orders[orderIndex];
            status.order.amount = order.amount;
            status.order.amountIsInput = order.amountIsInput;
            status.order.tokenIn = order.tokenIn;
            status.order.tokenOut = order.tokenOut;
            status.order.route = order.route;
            status.order.chainOrder = order.chainOrder;
            status.order.outputDirectlyToOwner = order.outputDirectlyToOwner;
            console2.log('_placeOrders F');
            for( uint t=0; t<order.tranches.length; t++ ) {
                status.order.tranches.push();
                OrderLib.Tranche memory ot = order.tranches[t]; // order tranche
                OrderLib.Tranche storage st = status.order.tranches[t]; // status tranche
                st.fraction = ot.fraction;
                for( uint c=0; c<ot.constraints.length; c++ )
                    st.constraints.push(ot.constraints[c]);
                console2.log('_placeOrders G');
                status.trancheFilledIn.push(0);
                status.trancheFilledOut.push(0);
            }
            status.state = SwapOrderState.Open;
            status.start = uint32(block.timestamp);
            status.ocoGroup = ocoGroup;
            console2.log('_placeOrders H');
        }
        emit DexorderSwapPlaced(startIndex,uint8(orders.length));
    }


    // return codes:
    //
    // returns the zero-length string '' on success
    //
    // NO order is not open
    // OCO order was implicitly canceled by an OCO
    // NI not implemented / unknown constraint
    // TE current time is too early for this tranche
    // TL current time is too late for this tranche
    //
    function execute(OrdersInfo storage self, uint64 orderIndex, uint8 tranche_index, PriceProof memory proof) internal
    returns (string memory error)
    {
        SwapOrderStatus storage status = self.orders[orderIndex];
        if (status.state != SwapOrderState.Open)
            return 'NO'; // Not Open
        Tranche storage tranche = status.order.tranches[tranche_index];
        uint160 sqrtPriceX96 = 0;
        uint160 sqrtPriceLimitX96 = 0;
        // todo other routes
        address pool = Constants.uniswapV3Factory.getPool(status.order.tokenIn, status.order.tokenOut, status.order.route.fee);
        for (uint8 c = 0; c < tranche.constraints.length; c++) {
            Constraint storage constraint = tranche.constraints[c];
            if (constraint.mode == ConstraintMode.Time) {
                TimeConstraint memory tc = abi.decode(constraint.constraint, (TimeConstraint));
                uint32 time = tc.earliest.mode == TimeMode.Timestamp ? tc.earliest.time : status.start + tc.earliest.time;
                if (time > block.timestamp)
                    return 'TE'; // time early
                time = tc.latest.mode == TimeMode.Timestamp ? tc.latest.time : status.start + tc.latest.time;
                if (time < block.timestamp)
                    return 'TL'; // time late
            }
            else if (constraint.mode == ConstraintMode.Limit) {
                if( sqrtPriceX96 == 0 ) {
                    (sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
                }
                PriceConstraint memory pc = abi.decode(constraint.constraint, (PriceConstraint));
                uint256 price = sqrtPriceX96;
                if( pc.isRatio )
                    pc.valueSqrtX96 = uint160(price * pc.valueSqrtX96 / 2**96); // todo overflow check!
                if( pc.isAbove && price < pc.valueSqrtX96 || !pc.isAbove && price > pc.valueSqrtX96 )
                    return 'L';
            }
            else if (constraint.mode == ConstraintMode.Barrier) {
                return 'NI'; // not implemented
            }
            else if (constraint.mode == ConstraintMode.Trailing) {
                return 'NI'; // not implemented
            }
            else if (constraint.mode == ConstraintMode.Line) {
                return 'NI'; // not implemented
            }
            else
                return 'NI'; // not implemented
            // unknown constraint
        }
        uint256 amount = status.order.amount * tranche.fraction / type(uint16).max // the most this tranche could do
                         - (status.order.amountIsInput ? status.trancheFilledIn[tranche_index] : status.trancheFilledOut[tranche_index]); // minus tranche fills
        // order amount remaining
        uint256 remaining = status.order.amount - (status.order.amountIsInput ? status.filledIn : status.filledOut);
        if (amount > remaining)  // not more than the order's overall remaining amount
            amount = remaining;
        uint256 amountIn;
        uint256 amountOut;
        if( status.order.route.exchange == Exchange.UniswapV3 )
            (error, amountIn, amountOut) = _do_execute_univ3(status.order, pool, amount, sqrtPriceLimitX96);
        //  todo other routes
        else
            return 'UR'; // unknown route
        if( bytes(error).length == 0 ) {
            status.filledIn += amountIn;
            status.filledOut += amountOut;
            status.trancheFilledIn[tranche_index] += amountIn;
            status.trancheFilledOut[tranche_index] += amountOut;
            emit DexorderSwapFilled(orderIndex, tranche_index, amountIn, amountOut);
            _checkCompleted(self, orderIndex, status);
        }
        return ''; // success is no error, said no one
    }


    function _do_execute_univ3( SwapOrder storage order, address pool, uint256 amount, uint160 sqrtPriceLimitX96) private
    returns (string memory error, uint256 amountIn, uint256 amountOut)
    {
        // todo refactor this signature to be more low-level, taking only the in/out amounts and limit prices.  doesnt need self/status/index
        if (sqrtPriceLimitX96 == 0)
        // check pool inversion to see if the price should be high or low
            sqrtPriceLimitX96 = order.tokenIn < order.tokenOut ? 0 : type(uint160).max;
        // todo swap direct to owner
        if (order.amountIsInput) {
            amountIn = amount;
            (error, amountOut) = UniswapSwapper.swapExactInput(UniswapSwapper.SwapParams(
                    pool, order.tokenIn, order.tokenOut, order.route.fee, amount, sqrtPriceLimitX96));
        }
        else {
            amountOut = amount;
            (error, amountIn) = UniswapSwapper.swapExactOutput(UniswapSwapper.SwapParams(
                    pool, order.tokenIn, order.tokenOut, order.route.fee, amount, sqrtPriceLimitX96));
        }
    }

    function _checkCompleted(OrdersInfo storage self, uint64 orderIndex, SwapOrderStatus storage status) internal {
        uint256 remaining = status.order.amount - (status.order.amountIsInput ? status.filledIn : status.filledOut);
        if( remaining == 0 )  { // todo dust leeway?
            status.state = SwapOrderState.Filled;
            emit DexorderSwapCompleted(orderIndex);
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
        SwapOrderState state = self.orders[orderIndex].state;
        if( state == SwapOrderState.Open ) {
            self.orders[orderIndex].state = SwapOrderState.Canceled;
            emit DexorderSwapCompleted(orderIndex);
        }
    }
}
