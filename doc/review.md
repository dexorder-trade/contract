# Introduction

## Audience

This document targets technical users who are familiar with Solidity, the EVM,
the ERC20 protocol, the Uniswap V3 API, and common design patterns in blockchain
financial protocols, such as oracles.

## Purpose of This Document

After reviewing this document the reader should have a good grasp of the
operating principles of Dexorder, and feel able to directly utilize the public
Dexorder contract functions. However, Dexorder is intended as a system primarily
used by end-users via the [Dexorder Web3 UX](https://dexorder.trade).

Instead, the purpose of this document is to foster understanding of the system
so that the community and auditors may evaluate the Dexorder contracts for
safety, trust, and correct implementation.

# Dexorder's Construction

Dexorder comprises several cooperating technologies that implement complex order
behaviors not otherwise supported by Uniswap. Dexorders are also executed in a
context that is at least partially externalized from Uniswap. 

The technologies supporting these advanced order types include the Dexorder:

* EVM contracts (the focus of this document)
* Backend
* Web3 user interface

The two basic order types supported by Dexorder include limit orders and market
orders. Dexorder powerfully augments these two basic order types by (optionally)
combining them with algorithms that determine parameters of those orders
including the time, price and quantity at which an order may execute.

## The Dexorder EVM contracts

Dexorder's contracts implement several logical components of the overall
Dexorder system, as follows:

* Vaults
  * Proxy
    * Kill system
    * Upgrade system
  * Vault Factory
  * Vault
  * Orders
  * Tranches
* FeeManager
* Router

### Proxy

By the fundamental design of the EVM, contracts cannot be changed once deployed.
Instead of upgrades, contracts may delegate their implementation via proxies. By
changing the address to which a proxy delegates, deployers can effectively
change (upgrade) contracts. Dexorder employs this well established proxy upgrade
pattern. Thus, Dexorder Vault contract addresses are in fact the address of a proxy.
That proxy forwards most contract calls to an implementation contract.

The Dexorder vault proxy implements certain core functions directly. Any
function it does not directly implement is forwarded to the implementation
contract. Therefore the functionality of those calls it directly implements can
never be changed. Those functions are also not part of the kill system described
in the next section.

The directly implemented functions are the ones used for moving funds in and out
of vaults. Thus, users may have full confidence that proxy implementation
upgrades cannot interfere with fund movement.

#### Kill system

An individual Vault may be killed by the owner of that vault. Vaults may also be
globally killed by Dexorder. When a vault is killed, only deposit and withdraw
operations continue to function for that vault. These kill switches are
implemented directly in the proxy. Thus, they cannot be disabled or upgraded.

The Kill functionality may be useful in the event of some unforeseen attack on
the overall system, or when an individual user is attacked, or suspects
compromised keys.

Killing takes immediate effect and is irreversible.

#### Upgrade system

Upgrades to the vault implementation may be proposed by Dexorder via the VaultFactory
(see below). When proposed, the vault implementation upgrade goes into a pending state
for a pre-determined period. This pre-determined pendency period is fixed within
the non-upgradable VaultFactory contract at the time it is initially deployed.
Therefore, the pendency period cannot be changed, even by Dexorder.

During the pendency period of an upgrade, users have the opportunity to review
the proposed upgrade. At any time, a user may choose to kill their individual
vault, remain on the version of the vault implementation they are currently on, or
upgrade their vault's implementation (only if an upgrade is currently available
and past its pendency period).

In this way, users may be confident that they will be able to review upgrades
before any possibility that those upgrades will take effect. Irrespective of the
pendency system, upgrades anyway never automatically take effect. Instead,
individual Vaults must be explicitly upgraded to the current vault implementation. This
upgrade operation may only be done by the vault owner (the user), and is on a
strictly opt-in basis.

There is no other global upgrade mechanism. Thus, vault upgrades (and therefore
any changes to the vault implementation) are always controlled by users. If a user does
not explicitly upgrade their vault, their vault will continue to function using
whatever version of the system is currently active on that vault.

This system ensures that users always feel secure relative to Dexorder's upgrade
proposals. If a user does not trust an upgrade, they can simply refuse that
upgrade.

> Note: Dexorder cannot guarantee that its Web3 UX or backend will indefinitely support
> all prior versions of vaults.

### Vault Factory

The factory implements APIs used by the Dexorder Web3 UX when onboarding new
users. The UX uses the VaultFactory to deploy individual user vaults. The
VaultFactory API may be used by anyone.

The VaultFactory also adjudicates vault implementation upgrade proposals,
storing the proposed vault implementation upgrade and the proposed block time
after which the new implementation becomes valid.

As mentioned above, the proposed upgrade block time is always a fixed time
interval after the proposal is made, an interval fixed when the VaultFactory itself
is deployed.

The VaultFactory also contains a global "kill switch" for all vaults, as
described above in "Kill system".

### Vault

Each user Vault is deployed by the Dexorder VaultFactory and is in fact a Proxy,
delegating the functionality for most of its contract calls to an implementation
contract. User funds are in the custody of their individual Vault.

The implementation contract address for a given Vault is set at the time of the
Vault's creation according to the then current implementation contract address
set in the VaultFactory. Users may optionally upgrade their Vault's
implementation contract address to the one currently set in the Vault Factory,
after the pendency period for the new implementation address is fulfilled.

If a user does not upgrade, their Vault's Dexorder functionality will remain
intact and they will not benefit from bug fixes or new features. Future versions
of the Dexorder UX and backend may or may not continue to support older Vault
implementations, but that Vault's API will continue to function. Thus, even in
the worst case, users may directly call the Vault API.

> Note: Currently, user Vaults are completely self contained except for their
> reliance on the shared implementation contract. There are no on-chain central
> data stores or external functions that create dependencies on user Vault
> versions, and therefore there is no reciprocal version dependence within a
> Vault on any external components. A Vault's functionality can thus continue
> indefinitely, even if the overall Dexorder system (backend, UX, etc) is not
> functioning (so long as the VaultFactory central Kill function has not been
> invoked--see above). However, future versions of the Vault implementation
> logic may have end up having broader dependencies. Hypothetically, such future
> dependencies could imply changes to the optionality of upgrades. Irrespective
> of this possibility, users will always have the option to opt out of an
> upgrade, losing functionality if that upgrade is mandated by related
> contracts. Again, users would still maintain the ability to independently kill
> their individual vault and withdraw funds. In this hypothetical scenario,
> which is not currently the case, such users would only lose the functionality
> of their Dexorders.

### Orders

Individual orders are stored in a user's vault. The code for executing orders
(in other words, the orders' functionality) is defined by the vault
implementation contract currently associated with that user's vault.

Supported order behaviors are described in detail below, in the Order Types
section.

Orders have two separate representations in blockchain storage, which will be
discussed in more detail in a subsequent section of this document:

* The "as entered" order: SwapOrder
* The "as executing" order status: SwapOrderStatus
  
The SwapOrder stores the user's intention for the order, while the
SwapOrderStatus stores the necessary state variables that allow the execution
API to correctly execute the order.

### Tranches

All Dexorders are executed by dividing them into one or more Tranches. A Tranche
consists of a set of parameters that define the order's behavior, because they
are used to calculate parameters of physical requests sent to a liquidity pool
for the purpose of executing a swap.

Like orders, Tranches have two separate representations in blockchain storage,
and will be discussed in more detail subsequently:

* The "as entered" Tranche: Tranche
* The "as executing" Tranche status: TrancheStatus

Each Dexorder storage structure, SwapOrder or SwapOrderStatus, contains an array
of Tranche or TrancheStatus. The simplest possible Dexorder is a market order
that has one Tranche, with no rate limiting, and an immediate activation time.
For such an order, the Dexorder system will typically attempt to match (swap)
the order on the DeFi pool in a single transaction.

Orders may be split into more than one Tranche. Each Tranche executes
according to its own time, price, and amount attributes. It is possible to
define start and end times for two Tranches such that they overlap, in which case
the execution ordering of co-activated Tranches is not deterministic. In no event
will the system execute swaps that cause the overarching SwapOrder parameters to 
be violated. For example, a SwapOrder will never swap an amount in excess of 
what's defined in the SwapOrder, even if the amounts defined in two tranches 
exceed the SwapOrder amount.

Tranches are the mechanisms that allows the Dexorder execution system to split
up an order's executions into separate swaps against the associated DeFi pool.
Complex order behavior is achieved by encoding the necessary features into an
order's Tranches.

#### Example: Time Weighted Average Price (TWAP)
A market order for 1 WETH is split up into 10 Tranches for 0.1 WETH each, where
the start time of each Tranche is 10 minutes after the start time of the prior
Tranche.  

> TWAP functionality is usually better provided by the Rate Limiting mechanism
> on a single tranche rather than by constructing many tranches. This is only
> here as an illustrative example of Tranches. If an execution should happen
> near an exact time, creating tranches that activate at absolute timestamps 
> should be used.

#### Example: Chase to a Level

An order could want to increase its swap limit price over some time period, to
get more urgent about crossing the market as time goes on, but then want to
stop increasing the price at a certain maximum amount, not chasing the market
too far. This can be encoded using two tranches: one tranche for the full 
amount with a sloped limit line that expires when it reaches the plateau price,
plus a second tranche activating when the first expires, also for the full 
amount but with a flat limit price.

### FeeManager

The Fee Manager is a separate contract used to encode (and report) Dexorder's
currently active fee schedule, as well as manage changes to those fees. Orders
copy the active fee settings out of the Fee Manager at the time the Order is
stored in a user's Vault (i.e., when the order is placed). This locks in the
fees a user will pay to execute an existing order, at the time it is entered
into the Vault.

The FeeManager is referenced by each user's Vault implementation, and is
therefore an upgradable component of the Vault. It is the authoritative source
and mediator for what fees Dexorder charges and can possibly charge.

VaultManager implements three fees:
  * a per-order "order fee", payable upon order placement in native token
  * a per-anticipated-execution "gas fee", payable upon order placement in 
    native token
  * a "fill fee", paid as a fraction of the proceeds token received from each
    executed DeFi swap

FeeManager enforces maximum limits on these fees as well as a delay before any
new fees take effect. These delays are called notice periods and they afford
clients of Dexorder time to review new fee schedules before they take effect.
The fee schedule for any given order is locked-in at order creation time, and
all future fills for that order will be charged the fill fee that was in effect
when the order was created.

There are two notice periods: a short notice period for changing the
fee schedule within set limits, plus a longer notice period for changing
the fee limits themselves.  This allows fees to be adjusted quickly as the
market price of native token changes, while preventing a malicious fee manager
from suddenly charging exorbitant fees. The up-front fees in native 
coin must be sent along with the order placement transaction, which
means any wallet user will clearly see the fee amounts in their wallet
software. The fill fee has less up-front transparency, but it is also
hard-limited to never be more than 1.275%, by virtue of being represented as
a uint8 value of half basis points (divided by 20_000).

The fee administrator at Dexorder may propose changes to the fees at any time,
but the proposed fees do not take effect until a sufficient "notice period" has
elapsed. There are two notice periods: a short notice period to make
changes to the fee schedule itself (within the fee limits,) but a longer notice
period to change the maximum fee limits allowed.

As mentioned above, any orders which were created with a promised fill fee will
remember that fee and apply it to all fills for that order, even if Dexorder
changes the fee schedule while the order is open but not yet executed.

### Router

The Router is implemented as an external contract in order to reduce
the Vault implementation contract's size. It provides internal APIs used
by Dexorder to route immediately executable swaps to DeFi pools, and to
query those pools for current prices.

## The Dexorder Backend

### Overview of the Dexorder Execution Model

The EVM processes transactions by request only. Therefore, Dexorders stored in
user Vaults must be explicitly executed via the Vault's execution API.
Dexorder's execution model is simple:

* Dexorders are "entered" into a user's Vault via that Vault's order placement API
* Dexorders are "executed" by calling a user's Vault's execution API

Anyone may request the execution of a given Dexorder, even if the order is in a
Vault they do not own. Of course, that execution will only succeed if the
parameters of the order, as evaluated against the instant state of the world,
would result in a valid execution.

Although anyone may request execution of a Dexorder, the Dexorder system also
implements an automated execution request system: The "backend." This system is
described in more detail below.

Presumably, no one would waste resources by requesting the execution of
non-executable orders, but doing so is in any case of no negative impact on
Dexorder, except insofar as reverted execution transactions clog up the
blockchain itself.

The Dexorder execution model is optimistic and opportunistic. Dexorders enforce
that they will only execute in accordance with their definition, but not that
they will execute in some specific way relative to either all their Tranches,
all other orders in a user's Vault, nor all other Dexorders across all other
users' Vaults. So long as an order can execute, if a transaction requesting its
execution is submitted to the blockchain, it will execute.

#### Example

It's possible to define a Dexorder with Tranches whose start and end times
overlap, and which specify a total of more than 100% of the overall SwapOrder's
asset amount. Which of these two overlapping Tranches would execute (or even,
whether both would execute) during a given blockchain transaction depends only
on which Tranches are requested to execute, and in what order.

Imagine two overlapping Tranches that together request 200% of an order's base
amount: Tranche 1 is for 100% of the order's base amount rate limited over some
period, and Tranche 2 is also for 100% of the order's base amount over some
overlapping period.

Despite this, no execution would ever exceed the base order's amount because the
execution logic limits the amounts swapped on liquidity pools according to the
SwapOrder's limits. Either or both Tranches may execute during the
overlapping period in which they are both active, depending only on whether a
transaction requesting that Tranche to execute is submitted.

### What does the backend do?

Dexorder's backed is a system that runs outside the blockchain. It consists of
multiple cooperating on and off-chain components that service all extant
Dexorder vaults and the orders stored within them. It monitors the blockchain in
order to call users' Vaults' execution APIs automatically when orders become
executable.

As previously mentioned, anyone may call those APIs. Dexorder's backend in fact
uses the very same API that anyone else can call to perform that same service.
There is no special access API utilized by the backend for executing Dexorders.

If there is a problem with Dexorder's backend, users (or third parties) may
nevertheless execute Dexorders by invoking the on-chain execution API directly.
The only difference will be who pays the gas.

Further details of Dexorder's backend are beyond the scope of this
document.

### Security and Economics of the Backend

The backend has no security implications for Dexorder users' Vaults, funds, or
orders. Relative to on-chain operations involving those elements, the backend
operates in the same security context as any third-party would.

However, the Dexorder backend does have access to Dexorder's own assets, such as
assets used to pay for gas costs of executing users' orders. If Dexorder does
not have funds to pay for the gas to execute orders, those orders cannot be
executed. If a user (or third party) chooses to execute their own orders, those
gas costs would not be paid by Dexorder.

In a worst case scenario, anyone can execute Dexorders by calling the execution
API.

User funds are only ever stored in the user's vault, and transfer of those funds
can never be disabled. Fund transfers do not depend on the backend, nor on
Dexorder's gas resources.

## The Dexorder Web3 User Interface

The Dexorder user interface is beyond the scope of this document. Suffice it to
say that there exist no non-public APIs for user Vaults. The Dexorder interface
is just one possible interface to the Dexorder system, and users are free to
build their own interfaces, or to use the public APIs directly, and anyone can
build an alternative interface to Dexorder Vaults.

In fact, as we will see in the following sections, the Dexorder system allows
users to compose complex orders that may not be currently composable via the
Dexorder user interface.

## Storage Structs Detail

As described above, each Dexorder is in fact a SwapOrder within which one or
more Tranches are defined. During execution of that SwapOrder, its status is
tracked in a corresponding SwapOrderStatus, within which each Tranche has a
corresponding TrancheStatus.

### SwapOrder & SwapOrder Status

```
struct SwapOrder {
    address tokenIn;
    address tokenOut;
    Route route;
    uint256 amount;
    uint256 minFillAmount;
    bool amountIsInput;
    bool outputDirectlyToOwner;
    uint64 conditionalOrder;
    Tranche[] tranches;
}

struct SwapOrderStatus {
    SwapOrder order;
    uint8 fillFeeHalfBps;
    bool canceled;
    uint32 startTime;
    uint64 ocoGroup;
    uint64 originalOrder;
    uint256 startPrice;
    uint256 filled;
    TrancheStatus[] trancheStatus;
}
```

Most of the SwapOrder elements are self explanatory. `minFillAmount` controls
the minimum amount that will ever be requested in a DeFi swap; therefore, it
also defines the amount below which any remaining quantity in the SwapOrder or
in any given Tranche of the SwapOrder is treated as 0 (i.e., the Tranche is
treated as complete). `conditionalOrder` and `tranches` are discussed below.

A user's Vault contains an array of SwapOrderStatus structs. Each
SwapOrderStatus contains the state variables used by the Dexorder system to
execute the contained SwapOrder. When a Vault receives a SwapOrder for
placement, it appends a new SwapOrderStatus onto this array, and copies the
SwapOrder into the `order` field. Indexes into this array identify specific
Dexorders, and are used throughout the Dexorder execution system for this
purpose.

The `conditionalOrder` field is an example of such an index: It references a new
order to place when conditions are met during execution of the containing
SwapOrder. When there is no conditional order (no dependent order), the field is
set to `NO_CONDITIONAL_ORDER`.

`conditionalOrder` is usually an absolute index into the Vault's SwapOrderStatus
array. However, when passing in multiple orders to a Vault API call, its value
may have the `CONDITIONAL_ORDER_IN_CURRENT_GROUP` bit set. In that case, the
index (after masking the bit) is interpreted as relative to the beginning of the
set of orders passed into the Vault API call. For example, when placing a new
set of orders, one of which is the `conditionalOrder` of another order, the Web3
UX sets this bit in order to refer to the dependent order being placed in 
the same batch.

> NOTE 1: A conditional order must be placed before any parent order can 
> reference it. This is true whether placing orders separately or within 
> a batch: the conditional order index must be lower than the index of any
> order referencing it.

> NOTE 2: In these docs, the "conditional order" (or "dependent order") is the
> order "pointed to" by the "triggering" or "parent" order. Thus, the
> `conditionalOrder` field points to the "template" SwapOrder that will be
> placed anew under the right conditions. In turn, the newly placed order will
> have its `originalOrder` pointing back.

> NOTE 3: When placing an order that has `conditionalOrder` set, the referenced
> conditional order must meet certain criteria: (1) it must not itself have a
> `conditionalOrder` and (2) it must have an 0 amount. This avoids the
> possibility of order placement loops, or execution of a conditional order.
> If the conditional order is ever activated (placed anew), the amount will
> be set to a non-zero value in the newly placed order.

`startTime` stores the blocktime of the transaction that placed the SwapOrder.
The value of this field is relevant to resolving other times within the
SwapOrder and its Tranches when those dependent times are configured to be
relative to `startTime`.

`ocoGroup` is a calculated index into an internal table that lists all of the
SwapOrder indexes that are part of that `ocoGroup`. All of those orders will be
canceled as a group if the "one cancels the other" condition associated with the
the group occurs. The Vault's table of "ocoGroups" is managed by the Vault
logic, and is populated at the time of Dexorders' placement into the Vault.

When an order has a `conditionalOrder` set, and the condition is met, a new
order based on the referenced order is placed. The newly placed order will have
an `originalOrder` tracking that originally referenced order. Otherwise
`originalOrder` refers to the instant order's index.

`startPrice` is set to the router's `protectedPrice()`, which is not the pool's
current price but a manipulation resistant price.  For UniswapV3 this is a
short-term TWAP. Not all orders require the `startPrice`, so to save
gas, the value is not always set.

All prices are specified in terms of the input token as the base and the output
token as the quote. That is, all swaps are priced as if they are sells. This
means that the `minPrice` line is always the standard limit line, and the max
line is used rarely, for example to wait for a breakout in the order's 
direction before executing.

### Tranche & TrancheStatus

```
struct Tranche {
    uint16 fraction;
    bool   startTimeIsRelative;
    bool   endTimeIsRelative;
    bool   minIsBarrier;
    bool   maxIsBarrier;
    bool   marketOrder;
    bool   minIsRatio;
    bool   maxIsRatio;
    bool   _reserved7;
    uint16 rateLimitFraction;
    uint24 rateLimitPeriod;

    uint32 startTime;
    uint32 endTime;

    Line   minLine;
    Line   maxLine;
}

struct TrancheStatus {
    uint256 filled;
    uint32  activationTime;
    uint32  startTime;
    uint32  endTime;
}
```

Like SwapOrder and SwapOrderStatus, Tranche contains the definition of a Tranche
while the corresponding TrancheStatus stores the state variables necessary to
properly trade the Tranche. Tranches are stored in an array within the
SwapOrder, while TrancheStatuses are in an array in the SwapOrderStatus.

If more than one Tranche is eligible for execution, whether only one or both 
execute, and in what order, is not defined. However, under no circumstance will
the execution of one or more Tranches result in execution of more than the
SwapOrder's `amount`.

`fraction` stores an integer representing the maximum amount of the containing
SwapOrder that this Tranche can fill. The tranche's size is `order.amount *
(tranche.fraction / MAX_FRACTION)`.

`startTimeIsRelative` and `endTimeIsRelative` indicate whether the `startTime`
and `endTime` fields are values relative to the `startTime` stored in the
SwapOrderStatus. If true, the values of the `startTime` and `endTime` fields in
the TrancheStatus will be set by adding the corresponding Tranche's time to the
SwapOrderStatus' `startTime`

`marketOrder` is true when the Tranche should be executable at any price. If
`marketOrder` is true then the `minLine.intercept` is treated as a slippage
parameter. Market orders use the Router's `protectedPrice()` adjusted by this
slippage float to determine their instantaneous limit price. If slippage is
set to 0, then slippage management is disabled and a true market order will
be placed.

`minIsRatio` and `maxIsRatio` are true when the `minLine` and `maxLine` should
be interpreted as ratios. More on this below.

The Vault code that executes Tranches intrinsically supports a rate limiting
feature, parameterized by `rateLimitFraction` and `rateLimitPeriod`. The
`rateLimitFraction` parameter, like the `fraction` parameter, expresses a ratio
vs `MAX_FRACTION` that is the largest portion of the total Tranche amount that
should be filled per `rateLimitPeriod`. The amount implied by the
`rateLimitFraction` is the `order.amount * (tranche.fraction / MAX_FRACTION) *
(tranche.rateLimitFraction / MAX_FRACTION)`.

If executed, a rate-limited Tranche will not be eligible for further executions 
until at least a pro-rata portion of the `rateLimitPeriod` elapses, based on the
executed amount. For example, if 82% of the amount implied by the 
`rateLimitFraction` is executed, then 82% of the `rateLimitPeriod` must elapse 
before the Tranche is once again eligible for execution. However, when it becomes 
eligible for execution once again, the full amount implied by `rateLimitFraction` 
may be executed. Thus, the executions of a Tranche may be more frequent than 
implied by `rateLimitPeriod` if each execution is in fact smaller than requested 
from the pool. `activationTime` tracks the next time at which a Tranche is 
eligible for execution, if rate limiting is in effect.

`minLine` and `maxLine` define lines in "mx + b" (slope + y-intercept) form,
unless the corresponding "ratio" boolean is true. In that case, the line's
slope is maintained, but its intercept is calculated such that the line passes
through the current price adjusted by the ratio specified in the "intercept"
part of the `minLine` or `maxLine`. If both slope and intercept are zero, then
the line is disabled.

Whether in ratio or normal mode, the `minLine` and `maxLine` parameters are used
to calculate min and max prices. A Tranche is only eligible for execution if the
pool's instantaneous price is between the min and max prices.

Finally, `filled` tacks the amount for which this Tranche has been filled so
far. In no case will a Tranche fill more than its `fraction` of the SwapOrder's
`amount`.


# Supported Use Cases & Order Types

## Algorithm: OCO (One Cancels Other)

Orders may be entered such that execution of one order, in whole or in part, 
cancels all other orders in the OCO group.

### Example Use Case

* A trader wishes to avoid buying asset A if they successfully buy asset B
  instead.

## Algorithm: Line following limit price

The price of an order may be set according to a line determined by two points on
a chart. This allows, for example, a limit order to increase or decrease the
limit price as time goes on.

### Example Use Case

* A trader is willing to pay more for an asset as time goes on, if the market is
  trending up.

## Algorithm: Rate limit / Time Slice

The quantity matched at a single point in time may be limited such that the
total quantity of an order matches across a given time frame.

### Example Use Case

* A trader wants to minimize market impact, so they only want to swap 5% of
  their total target qty every 15 minutes until they've acquired 100%.

