// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

library OrderLib {

    uint64 internal constant NO_CHAIN = type(uint64).max;
    uint8 internal constant NUM_OCO_GROUPS = 6;

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
        Tranche[] tranches;
        uint64 chainOrder; // use NO_CHAIN for no chaining. chainOrder index must be < than this order's index for safety (written first) and chainOrder state must be Template
    }

    struct SwapOrderStatus {
        SwapOrderState state;
        SwapOrder order;
        uint256 filled;
        uint256 net;  // received after fees, conversions, taxes, etc
        bool[NUM_OCO_GROUPS] ocoTriggered; // if true then the group has been canceled
    }

    enum ConstraintMode {
        Limit,
        Barrier,
        Trailing,
        Time
    }

    struct PriceConstraint {
        PriceConstraintMode mode;
        bool isAbove;
        bool isRatio;
        uint160 valueSqrtX96;
    }


    enum TimeMode {
        Timestamp,      // absolute timestamp
        SinceOrderStart // relative to order creation (useful for chained orders)
    }

    struct Time {
        TimeMode mode;
        uint32 time;
    }

    Time constant DISTANT_PAST = Time(TimeMode.Timestamp, 0);
    Time constant DISTANT_FUTURE = Time(TimeMode.Timestamp, type(uint32).max);

    uint8 internal constant NO_OCO = 255;

    struct Tranche {
        uint64 fraction; // 18-decimal fraction of the order amount which is available to this tranche. must be <= 1
        uint8 ocoGroup; // 0-5 are six valid groups, indexing ocoTriggered. use NO_OCO to disable oco functionality.
        Time earliest; // earliest block timestamp for execution. use DISTANT_PAST to disable
        Time latest; // latest block timestamp for execution (inclusive).  use DISTANT_FUTURE to disable
        PriceConstraint[] constraints;
    }

}
