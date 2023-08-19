# Order Types
## TWAP
* time-to-expiry is required
* number of tranches > 1
* optional lower and upper price bounds

## DCA
* similar to a TWAP, but the tranches are divided by value instead of quantity

## Timed Entry
* specific time when an order is triggered
* can be market/limit TWAP, whatever

## Limit

## Stop
* enabled on a price condition instead of at a specific time
    * how to enforce this in the contract? would need a price history of when the stop was touched.  perhaps this is a use case for a "chain" order where one set of constraints doesn't invoke a trade but instead creates a subsequent order 

## Ladder
* split into many traches across a range of prices
* required number of tranches
* required upper and lower bounds of the ladder


# Conditions

* current price above/below
* historical price touched above/below (e.g. trailing stop): keep an updated data structure of swing highs & lows.  this structure must only be updated once before the relevant observation rolls off the back of the window.  "management gas"
* volume above/below
* historical volume touched above/below: this could work like historical price swing high/lows if we first bucket the volumes into sizes <= the pool observation window
* per-swap slippage constraint


# Gas

* an amount for gas is reserved ahead of time
* excess gas is kept
* Dexible has a gas refund delay, saying:
  > `get/setLockoutBlocks` Retrieves or sets the number of blocks a trader must wait before withdrawing their gas deposit. This is to prevent traders from front-running a relay that submitted an order in order to circumvent paying for the execution or forcing a failed txn.

