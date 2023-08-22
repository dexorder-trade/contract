// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./OrderStatus.sol";
import "./UniswapSwapper.sol";


contract TimedOrder is Ownable {

    struct Spec {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint32 deadline; // uint32 is big enough to hold dates through the year 2105
        uint32 leeway; // if a tranche is not traded within this number of seconds of its scheduled time, it is skipped.  If 0, then a reasonable value is generated.
        uint160 minSqrtPriceX96; // must be in terms of token1/token0 regardless of which token is in/out
        uint160 maxSqrtPriceX96;
        uint8 numTranches;
        uint256 amount;  // amount PER TRANCHE
        bool amountIsInput;
    }

    struct Status {
        // includes Spec but has additional status fields
        OrderStatus status;
        uint32 start;
        uint8 tranche;
        uint8 tranchesExecuted; // may be less than tranche if a tranche was skipped
        uint256 filledIn;
        uint256 filledOut;
    }

    event TimedOrderCreated (address owner, uint64 index, Spec spec);

    event TimedOrderFilled (address owner, uint64 index, uint256 amountIn, uint256 amountOut);

    event TimedOrderCompleted (address owner, uint64 index);

    event TimedOrderError (address owner, uint64 index, string reason);


    Spec[] public timedOrderSpecs;
    Status[] public timedOrderStatuses;


    function timedOrder(Spec memory spec) public onlyOwner returns (uint64 index) {
        uint32 start = uint32(block.timestamp);
        require(spec.deadline >= start);
        require(spec.numTranches >= 1);
        Status memory status = Status(OrderStatus.ACTIVE, start, 0, 0, 0, 0);
        require(timedOrderStatuses.length < type(uint64).max);
        index = uint64(timedOrderStatuses.length);
        timedOrderStatuses.push(status);
        uint32 trancheInterval = (spec.deadline - uint32(block.timestamp)) / spec.numTranches;
        spec.leeway = spec.leeway > 0 ? spec.leeway : trancheInterval / 10;
        if (spec.leeway < 60) // todo configure per chain?
            spec.leeway = 60;
        timedOrderSpecs.push(spec);
        emit TimedOrderCreated(address(this), index, spec);
    }


    function cancelTimedOrder(uint64 index) public onlyOwner {
        require(index < timedOrderStatuses.length);
        Status storage s = timedOrderStatuses[index];
        if (s.status == OrderStatus.ACTIVE)
            s.status = OrderStatus.CANCELED;
    }


    function triggerTimedOrder(uint64 index) public returns (bool changed) {
        return _triggerTimedOrder(index);
    }


    function triggerTimedOrders(uint64[] calldata indexes) public returns (bool[] memory changed) {
        changed = new bool[](indexes.length);
        for (uint256 i = 0; i < indexes.length; i++) {
            changed[i] = _triggerTimedOrder(indexes[i]);
        }
    }

    struct _TriggerTimedOrderVars {
        uint32 interval;
        uint32 triggerTime;
        address pool;
        uint160 sqrtPriceX96;
        uint160 limit;
        uint256 amountIn;
        uint256 amountOut;
        string error;
    }

    function _triggerTimedOrder(uint64 index) internal returns (bool changed) {
        if (!(index < timedOrderStatuses.length)) // ensure valid order index
            return false;
        Status storage s = timedOrderStatuses[index];
        if (!(s.status == OrderStatus.ACTIVE)) // ensure order is active
            return false;
        Spec storage c = timedOrderSpecs[index];
        _TriggerTimedOrderVars memory v;
        // compute trigger times.  try to find a tranche which starts before this block but hasnt expired yet
        v.interval = (c.deadline - s.start) / c.numTranches;
        v.triggerTime = s.start + s.tranche * v.interval;
        while (s.tranche < c.numTranches) {
            if (v.triggerTime > block.timestamp)
                return false; // not time yet to trigger
            if (block.timestamp <= v.triggerTime + c.leeway)
                break; // triggerTime <= block.timestamp <= triggerTime + intervalLeeway
            // we have not yet found a tranche which hasn't expired
            s.tranche++;
            v.triggerTime += v.interval;
        }
        if (_checkCompleted(index, s, c.numTranches))
            return true;
        // we have found a valid tranche
        // check prices
        v.pool = Constants.uniswapV3Factory.getPool(c.tokenIn, c.tokenOut, c.fee);
        (v.sqrtPriceX96, , , , , ,) = IUniswapV3Pool(v.pool).slot0();
        require(v.sqrtPriceX96 >= c.minSqrtPriceX96);
        require(v.sqrtPriceX96 <= c.maxSqrtPriceX96);
        // todo swap
        v.limit = c.tokenIn < c.tokenOut ? c.minSqrtPriceX96 : c.maxSqrtPriceX96;
        if (c.amountIsInput) {
            v.amountIn = c.amount;
            (v.error, v.amountOut) = UniswapSwapper.swapExactInput(UniswapSwapper.SwapParams(
                v.pool, c.tokenIn, c.tokenOut, c.fee, c.amount, v.limit));
            if(!_checkSwapError(index, v.error))
                return false;
        }
        else {
            v.amountOut = c.amount;
            (v.error, v.amountIn) = UniswapSwapper.swapExactOutput(UniswapSwapper.SwapParams(
                v.pool, c.tokenIn, c.tokenOut, c.fee, c.amount, v.limit));
            if(!_checkSwapError(index, v.error))
                return false;
        }

        s.filledIn += v.amountIn;
        s.filledOut += v.amountOut;
        s.tranchesExecuted++;
        s.tranche++;
        emit TimedOrderFilled(address(this), index, v.amountIn, v.amountOut);
        _checkCompleted(index, s, c.numTranches);
        return true;
    }


    function _checkCompleted(uint64 index, Status storage s, uint8 numTranches) internal returns (bool completed) {
        if (s.tranche >= numTranches) {
            // last tranche has finished
            s.status = s.tranchesExecuted == numTranches ? OrderStatus.FILLED : OrderStatus.EXPIRED;
            emit TimedOrderCompleted(address(this), index);
            return true;
        }
        return false;
    }

    function _checkSwapError( uint64 index, string memory status ) internal returns (bool ok) {
        if( bytes(status).length == 0 )
            return true;
        emit TimedOrderError(address(this), index, status);
        return false;
    }

}
