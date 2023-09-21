// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./UniswapSwapper.sol";


library OrderLib {

    uint64 internal constant NO_CHAIN = type(uint64).max;
    uint64 internal constant NO_OCO = type(uint64).max;

    event DexorderPlaced (uint64 startOrderIndex, uint8 numOrders);

    event DexorderSwapFilled (uint64 orderIndex, uint8 trancheIndex, uint256 amountIn, uint256 amountOut);

    event DexorderCompleted (uint64 orderIndex);

    event DexorderError (uint64 orderIndex, string reason);

    enum SwapOrderState {
        Open, Canceled, Filled, Template
    }

    struct SwapOrder {
        address tokenIn;
        address tokenOut;
        uint24 fee;
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
        uint256 filledIn;
        uint256 filledOut;
    }

    enum ConstraintMode {
        Time,
        Limit,
        Trailing,
        Barrier,
        Line
    }

    struct Constraint {
        ConstraintMode mode;
        bytes constraint; // abi-encoded constraint struct
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
        uint64 fraction; // 18-decimal fraction of the order amount which is available to this tranche. must be <= 1
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

    struct OrdersInfo {
        bool _ignored; // workaround for Solidity bug where a public struct member cannot start with an array of uncertain size
        SwapOrderStatus[] orders;
        OcoGroup[] ocoGroups; // each indexed OCO group is an array of orderIndexes of orders in the oco group.
    }


    function _placeOrder(OrdersInfo storage self, SwapOrder memory order) internal {
        SwapOrder[] memory orders = new SwapOrder[](1);
        orders[0] = order;
        return _placeOrders(self,orders,OcoMode.NO_OCO);
    }

    function _placeOrders(OrdersInfo storage self, SwapOrder[] memory orders, OcoMode ocoMode) internal {
        require(orders.length < type(uint8).max);
        uint64 startIndex = uint64(self.orders.length);
        require(startIndex < type(uint64).max);
        uint64 ocoGroup;
        if( ocoMode == OcoMode.NO_OCO )
            ocoGroup = NO_OCO;
        else if ( ocoMode == OcoMode.CANCEL_ON_PARTIAL_FILL || ocoMode == OcoMode.CANCEL_ON_COMPLETION ){
            ocoGroup = uint64(self.ocoGroups.length);
            self.ocoGroups.push(OcoGroup(ocoMode, startIndex, uint8(orders.length)));
        }
        else
            revert('OCOM');
        for( uint8 o = 0; o < orders.length; o++ ) {
            SwapOrder memory order = orders[o];
            // we must explicitly copy into storage because Solidity doesn't implement copying the double-nested
            // tranches constraints array :(
            uint orderIndex = self.orders.length;
            self.orders.push();
            SwapOrderStatus storage status = self.orders[orderIndex];
            status.order.amount = order.amount;
            status.order.amountIsInput = order.amountIsInput;
            status.order.tokenIn = order.tokenIn;
            status.order.tokenOut = order.tokenOut;
            status.order.fee = order.fee;
            status.order.chainOrder = order.chainOrder;
            status.order.outputDirectlyToOwner = order.outputDirectlyToOwner;
            for( uint t=0; t<order.tranches.length; t++ ) {
                status.order.tranches.push();
                OrderLib.Tranche memory ot = order.tranches[t]; // order tranche
                OrderLib.Tranche storage st = status.order.tranches[t]; // status tranche
                st.fraction = ot.fraction;
                for( uint c=0; c<ot.constraints.length; c++ )
                    st.constraints.push(ot.constraints[c]);
            }
            status.state = SwapOrderState.Open;
            status.start = uint32(block.timestamp);
            status.ocoGroup = ocoGroup;
        }
        emit DexorderPlaced(startIndex,uint8(orders.length));
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
        address pool = Constants.uniswapV3Factory.getPool(status.order.tokenIn, status.order.tokenOut, status.order.fee);
        for (uint8 c = 0; c < tranche.constraints.length; c++) {
            Constraint storage constraint = tranche.constraints[c];
            if (constraint.mode == ConstraintMode.Time) {
                TimeConstraint memory tc = abi.decode(constraint.constraint, (TimeConstraint));
                uint32 time = tc.earliest.mode == TimeMode.Timestamp ? tc.earliest.time : status.start + tc.earliest.time;
                if (time > block.timestamp)
                    return 'TE';
                time = tc.latest.mode == TimeMode.Timestamp ? tc.latest.time : status.start + tc.latest.time;
                if (time < block.timestamp)
                    return 'TL';
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
                return 'NI';
            }
            else if (constraint.mode == ConstraintMode.Trailing) {
                return 'NI';
            }
            else if (constraint.mode == ConstraintMode.Line) {
                return 'NI';
            }
            else
                return 'NI';
            // unknown constraint
        }
        uint256 amount = status.order.amount * tranche.fraction / 10 ** 18;
        uint256 remaining = status.order.amount - (status.order.amountIsInput ? status.filledIn : status.filledOut);
        if (amount > remaining)
            amount = remaining;
        uint256 amountIn;
        uint256 amountOut;
        (error, amountIn, amountOut) = _do_execute_univ3(status.order, pool, amount, sqrtPriceLimitX96);
        if( bytes(error).length == 0 ) {
            status.filledIn += amountIn;
            status.filledOut += amountOut;
            emit DexorderSwapFilled(orderIndex, tranche_index, amountIn, amountOut);
            _checkCompleted(self, orderIndex, status);
        }
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
                    pool, order.tokenIn, order.tokenOut, order.fee, amount, sqrtPriceLimitX96));
        }
        else {
            amountOut = amount;
            (error, amountIn) = UniswapSwapper.swapExactOutput(UniswapSwapper.SwapParams(
                    pool, order.tokenIn, order.tokenOut, order.fee, amount, sqrtPriceLimitX96));
        }
    }

    function _checkCompleted(OrdersInfo storage self, uint64 orderIndex, SwapOrderStatus storage status) internal {
        uint256 remaining = status.order.amount - (status.order.amountIsInput ? status.filledIn : status.filledOut);
        if( remaining == 0 )  { // todo dust leeway?
            status.state = SwapOrderState.Filled;
            emit DexorderCompleted(orderIndex);
            if( status.ocoGroup != NO_OCO )
                _cancelOco(self, status.ocoGroup);
        }
        else if( status.ocoGroup != NO_OCO && self.ocoGroups[status.ocoGroup].mode == OcoMode.CANCEL_ON_PARTIAL_FILL )
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
        if( state == SwapOrderState.Open || state == SwapOrderState.Template ) {
            self.orders[orderIndex].state = SwapOrderState.Canceled;
            emit DexorderCompleted(orderIndex);
        }
    }
}
