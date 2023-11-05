// SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.7.6;
pragma solidity >=0.8.0;
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
        Line,
        Barrier
    }

    struct Constraint {
        ConstraintMode mode; // type information
        bytes constraint;    // abi-encoded constraint struct: decode according to mode
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
            ocoGroup = NO_OCO_INDEX;
        else if ( ocoMode == OcoMode.CANCEL_ON_PARTIAL_FILL || ocoMode == OcoMode.CANCEL_ON_COMPLETION ){
            ocoGroup = uint64(self.ocoGroups.length);
            self.ocoGroups.push(OcoGroup(ocoMode, startIndex, uint8(orders.length)));
        }
        else
            revert('OCOM');
        for( uint8 o = 0; o < orders.length; o++ ) {
            SwapOrder memory order = orders[o];
            require(order.route.exchange == Exchange.UniswapV3, 'UR');
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
            for( uint t=0; t<order.tranches.length; t++ ) {
                status.order.tranches.push();
                OrderLib.Tranche memory ot = order.tranches[t]; // order tranche
                OrderLib.Tranche storage st = status.order.tranches[t]; // status tranche
                st.fraction = ot.fraction;
                for( uint c=0; c<ot.constraints.length; c++ )
                    st.constraints.push(ot.constraints[c]);
                status.trancheFilledIn.push(0);
                status.trancheFilledOut.push(0);
            }
            status.state = SwapOrderState.Open;
            status.start = uint32(block.timestamp);
            status.ocoGroup = ocoGroup;
        }
        emit DexorderSwapPlaced(startIndex,uint8(orders.length));
    }


    // revert codes:
    //
    // NO order is not open
    // OCO order was implicitly canceled by an OCO
    // NI not implemented / unknown constraint
    // TE current time is too early for this tranche
    // TL current time is too late for this tranche
    //
    function execute(OrdersInfo storage self, address owner, uint64 orderIndex, uint8 trancheIndex, PriceProof memory ) internal {
        console2.log('execute');
        console2.log(address(this));
        console2.log(uint(orderIndex));
        console2.log(uint(trancheIndex));
        SwapOrderStatus storage status = self.orders[orderIndex];
        if (status.state != SwapOrderState.Open)
            revert('NO'); // Not Open
        Tranche storage tranche = status.order.tranches[trancheIndex];
        uint160 sqrtPriceX96 = 0;
        uint160 sqrtPriceLimitX96 = 0; // 0 means "not set yet" and 1 is the minimum value
        // todo other routes
        address pool = Constants.uniswapV3Factory.getPool(status.order.tokenIn, status.order.tokenOut, status.order.route.fee);
        for (uint8 c = 0; c < tranche.constraints.length; c++) {
            Constraint storage constraint = tranche.constraints[c];
            if (constraint.mode == ConstraintMode.Time) {
                console2.log('time constraint');
                TimeConstraint memory tc = abi.decode(constraint.constraint, (TimeConstraint));
                uint32 time = tc.earliest.mode == TimeMode.Timestamp ? tc.earliest.time : status.start + tc.earliest.time;
                if (time > block.timestamp)
                    revert('TE'); // time early
                time = tc.latest.mode == TimeMode.Timestamp ? tc.latest.time : status.start + tc.latest.time;
                if (time < block.timestamp)
                    revert('TL'); // time late
            }
            else if (constraint.mode == ConstraintMode.Line) {
                console2.log('line constraint');
                if( sqrtPriceX96 == 0 )
                    (sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
                LineConstraint memory lc = abi.decode(constraint.constraint, (LineConstraint));
                uint256 price = sqrtPriceX96;
                if( lc.isRatio )
                    revert('ratio not implemented'); // todo the ratio must be computed when the order is placed
                    // c.valueSqrtX96 = uint160(price * c.valueSqrtX96 / 2**96);
                int256 limit256 = int256(uint256(lc.valueSqrtX96));
                if( lc.slopeSqrtX96 != 0 ) {
                    // todo cannot add square roots.
                    limit256 += int256(block.timestamp - lc.time) * lc.slopeSqrtX96 / 2**96;
                    if( limit256 < 0 )
                        limit256 = 0;
                }
                console2.log(limit256);
                console2.log(price);
                console2.log(lc.isAbove);
                uint160 limit = uint160(uint256(limit256));
                // use <= and >= here because trading AT the limit results in 0 volume.  price must exceed the limit.
                if( lc.isAbove && price <= limit || !lc.isAbove && price >= limit )
                    revert('L');
                if( sqrtPriceLimitX96 == 0 ||
                    lc.isAbove && limit < sqrtPriceLimitX96 ||
                    !lc.isAbove && limit > sqrtPriceLimitX96
                )
                    sqrtPriceLimitX96 = limit;
            }
            else if (constraint.mode == ConstraintMode.Barrier) {
                console2.log('barrier constraint');
                revert('NI'); // not implemented
            }
            else // unknown constraint
                revert('UC'); // not implemented
        }
        console2.log('computing amount');
        console2.log(status.order.amount);
        console2.log(tranche.fraction);
        console2.log(status.order.amountIsInput);
        console2.log(status.filledIn);
        console2.log(status.filledOut);
        console2.log(status.trancheFilledIn[trancheIndex]);
        console2.log(status.trancheFilledOut[trancheIndex]);
        uint256 amount = status.order.amount * tranche.fraction / type(uint16).max // the most this tranche could do
                         - (status.order.amountIsInput ? status.trancheFilledIn[trancheIndex] : status.trancheFilledOut[trancheIndex]); // minus tranche fills
        console2.log('amount');
        console2.log(amount);
        console2.log('limit');
        console2.log(sqrtPriceLimitX96);
        console2.log('price');
        console2.log(sqrtPriceX96);
        // order amount remaining
        require( (status.order.amountIsInput ? status.filledIn : status.filledOut) <= status.order.amount, 'OVERFILL' );
        uint256 remaining = status.order.amount - (status.order.amountIsInput ? status.filledIn : status.filledOut);
        console2.log('remaining');
        console2.log(remaining);
        if (amount > remaining)  // not more than the order's overall remaining amount
            amount = remaining;
        require( amount > 0, 'TF' );
        console2.log(amount);
        address recipient = status.order.outputDirectlyToOwner ? owner : address(this);
        console2.log(recipient);
        uint256 amountIn;
        uint256 amountOut;
        if( status.order.route.exchange == Exchange.UniswapV3 )
            (amountIn, amountOut) = _do_execute_univ3(recipient, status.order, pool, amount, sqrtPriceLimitX96);
        //  todo other routes
        else
            revert('UR'); // unknown route
        status.filledIn += amountIn;
        status.filledOut += amountOut;
        status.trancheFilledIn[trancheIndex] += amountIn;
        status.trancheFilledOut[trancheIndex] += amountOut;
        emit DexorderSwapFilled(orderIndex, trancheIndex, amountIn, amountOut);
        _checkCompleted(self, orderIndex, status);
    }


    function _do_execute_univ3( address recipient, SwapOrder storage order, address pool, uint256 amount, uint160 sqrtPriceLimitX96) private
    returns (uint256 amountIn, uint256 amountOut)
    {
        // todo refactor this signature to be more low-level, taking only the in/out amounts and limit prices.  doesnt need self/status/index
        console2.log('price limit');
        console2.log(uint(sqrtPriceLimitX96));
        if (order.amountIsInput) {
            (amountIn, amountOut) = UniswapSwapper.swapExactInput(UniswapSwapper.SwapParams(
                    pool, order.tokenIn, order.tokenOut, recipient, order.route.fee, amount, sqrtPriceLimitX96));
        }
        else {
            (amountIn, amountOut) = UniswapSwapper.swapExactOutput(UniswapSwapper.SwapParams(
                    pool, order.tokenIn, order.tokenOut, recipient, order.route.fee, amount, sqrtPriceLimitX96));
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
