
pragma solidity 0.8.26;

import {float} from "./IEEE754.sol";
import {Line} from "./LineLib.sol";

uint64 constant NO_CONDITIONAL_ORDER = type(uint64).max;
uint64 constant CONDITIONAL_ORDER_IN_CURRENT_GROUP = 1 << 63;  // high bit flag
uint64 constant NO_OCO_INDEX = type(uint64).max;
uint16 constant MAX_FRACTION = type(uint16).max;
uint32 constant DISTANT_PAST = 0;
uint32 constant DISTANT_FUTURE = type(uint32).max;


struct OrdersInfo {
    uint64 cancelAllIndex;
    SwapOrderStatus[] orders;
    OcoGroup[] ocoGroups;
}

event DexorderSwapPlaced (uint64 indexed startOrderIndex, uint8 numOrders, uint256 orderFee, uint256 gasFee);

event DexorderSwapFilled (
    uint64 indexed orderIndex, uint8 indexed trancheIndex,
    uint256 amountIn, uint256 amountOut, uint256 fillFee,
    uint32 nextExecutionTime
);

event DexorderSwapCanceled (uint64 orderIndex);
event DexorderCancelAll (uint64 cancelAllIndex);

enum Exchange {
    UniswapV2,  // 0
    UniswapV3   // 1
}

// todo does embedding Route into SwapOrder take a full word?
struct Route {
    Exchange exchange; // only ever UniswapV3 currently
    uint24 fee; // as of now, used as the "maxFee" parameter when placing swaps onto UniswapV3
}

// Primary data structure for order specification. These fields are immutable after order placement.
struct SwapOrder {
    address tokenIn;
    address tokenOut;
    Route route;
    uint256 amount; // the maximum quantity to fill
    uint256 minFillAmount;  // if a tranche has less than this amount available to fill, it is considered completed
    bool amountIsInput; // whether amount is an in or out amount
    bool outputDirectlyToOwner; // whether the swap proceeds should go to the vault, or directly to the vault owner

    // Tranche prices are expressed as either inToken/outToken or outToken/inToken depending on this `inverted` flag.
    // A line in one space is a curve in the other, so the specification of e.g. WETH/USDC or USDC/WETH is essential.
    // The "natural" ordering of inverted=false follows Uniswap: the lower-address token is the base currency and the
    // higher-address token is the quote.
    bool inverted;

    uint64 conditionalOrder; // use NO_CONDITIONAL_ORDER for normal orders.  If the high bit is set, the order number is relative to the currently placed group of orders. e.g. `CONDITIONAL_ORDER_IN_CURRENT_GROUP & 2` refers to the third item in the order group currently being placed.
    Tranche[] tranches; // see Tranche below
}

// "Status" includes dynamic information about the trade in addition to its static SwapOrder specification.
struct SwapOrderStatus {
    SwapOrder order;
    // the fill fee is remembered from the active fee schedule at order creation time.
    // 1/20_000 "half bps" means the maximum representable value is 1.275%
    uint8 fillFeeHalfBps;
    bool canceled; // if true, the order is considered canceled, irrespective of its index relative to cancelAllIndex
    uint32 startTime; // the earliest time that an order can execute (as compared with block.timestamp)
    uint64 ocoGroup; // the "one cancels the other" group index in ocoGroups
    uint64 originalOrder; // Index of the original order in the orders array
    uint256 startPrice; // the price at which an order starts (e.g., the starting limit price)
    uint256 filled;  // total amount filled so far
    TrancheStatus[] trancheStatus; // the status of each individual Tranche
}

struct Tranche {
    uint16  fraction; // the fraction of the order's total amount that this tranche will, at most, fill
    //note: relative times become concrete when an order is placed for execution, this means that a
    //conditional order will calculate a concrete time once its condition becomes true
    bool   startTimeIsRelative;
    bool   endTimeIsRelative;
    bool   minIsBarrier; // not yet supported
    bool   maxIsBarrier; // not yet supported
    bool   marketOrder;  // if true, both min and max lines are ignored, and minIntercept is treated as a maximum slippage value (use positive numbers)
    bool   minIsRatio;   // todo price isRatio: recalculate intercept
    bool   maxIsRatio;
    bool   _reserved7;
    uint16 rateLimitFraction;  // max fraction of this tranche's amount per rate-limited execution
    uint24 rateLimitPeriod;  // seconds between rate limit resets

    uint32 startTime;  // use DISTANT_PAST to effectively disable
    uint32 endTime;    // use DISTANT_FUTURE to effectively disable

    // If intercept and slope are both 0, the line is disabled
    // Prices are expressed as either inToken/outToken or outToken/inToken depending on the order `inverted` flag.
    // A line in one space is a curve in the other, so the specification of e.g. WETH/USDC or USDC/WETH is critical

    // The minLine is equivalent to a traditional limit order constraint, except this limit line can be diagonal.
    Line minLine;
    // The maxLine will be relatively unused, since it represents a boundry on TOO GOOD of a price.
    Line maxLine;
}

struct TrancheStatus {
    uint256 filled;  // sum(trancheFilled) == filled
    uint32 activationTime;  // related to rate limit: the earliest time at which each tranche can execute. If 0, indicates TrancheStatus not concrete
    uint32 startTime;
    uint32 endTime;
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
