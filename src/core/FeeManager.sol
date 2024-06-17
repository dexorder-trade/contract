// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IFeeManager} from "../interface/IFeeManager.sol";
pragma abicoder v2;


//
// The FeeManager contract is the authoritative source and mediator for what fees Dexorder charges for orders.
//
// It implements three fees:
//   * a per-order fee, payable upon order placement in native token
//   * a per-execution fee, meant to cover future gas costs, payable upon order placement in native token
//   * a fill fee which is a fraction of the amount received from a swap
//
// FeeManager enforces maximum limits on these fees as well as a delay before any new fees take effect. These delays
// are called notice periods and they afford clients of Dexorder time to review new fee schedules before they take
// effect.  The fee schedule for any given order is locked-in at order creation time, and all future fills for that
// order will be charged the fill fee that was in effect when the order was created.
//
// There are two notice periods: a short notice period of 1 hour for changing the fee schedule within set limits, plus
// a longer 30-day notice period for changing the fee limits themselves.  This allows fees to be adjusted quickly as
// the market price of native token changes, while preventing a malicious fee manager to suddenly charge exhorbitant
// fees without customers noticing it. The up-front fees in native coin must be sent along with the order placement
// transaction, which means any wallet user will clearly see the fee amounts in their wallet software. The fill fee
// has less up-front transparency, but it is also hard-limited to never be more than 1.27%, by virtue of being
// represented as a uint8 value divided by 200.
//
// The fee administrator at Dexorder may propose changes to the fees at any time, but the proposed fees do not take
// effect until a sufficient "notice period" has elapsed. There are two notice periods: a short notice period of
// 1 hour to make changes to the fee schedule itself, but a longer 30-day notice period to change the maximum fee
// limits allowed.

// Any orders which were created with a promised fill fee
// will remember that fee and apply it to all fills for that order, even if Dexorder changes the prices while the
// order is open and not yet complete.
//


contract FeeManager is IFeeManager {

    //
    // FEE CHANGE LIMITS
    //

    // This many seconds must elapse before any change to the limits on fees takes effect.
//    uint32 constant public LIMIT_CHANGE_NOTICE_DURATION = 30 * 24 * 60 * 60; // 30 days
    uint32 immutable public LIMIT_CHANGE_NOTICE_DURATION; // todo remove debug timing of 5 minutes

    // This many seconds must elapse before new fees (within limits) take effect.
//    uint32 constant public FEE_CHANGE_NOTICE_DURATION = 1 * 60 * 60;  // 1 hour
    uint32 immutable public FEE_CHANGE_NOTICE_DURATION;

    // The per-order fee should not need to change too dramatically.
    uint8 immutable public MAX_INCREASE_ORDER_FEE_PCT;

    // tranche fees cover gas costs, which can spike dramatically, so we allow up to a doubling each day
    uint8 immutable public MAX_INCREASE_TRANCHE_FEE_PCT;  // 100%


    FeeSchedule private _fees;  // use fees()
    FeeSchedule private _limits;  // use limits()

    FeeSchedule private _proposedFees;   // proposed change to the fee schedule
    function proposedFees() external view returns (FeeSchedule memory) { return _proposedFees; }
    uint32 public override proposedFeeActivationTime;  // time at which the proposed fees will become active

    FeeSchedule private _proposedLimits;
    function proposedLimits() external view returns (FeeSchedule memory) { return _proposedLimits; }
    uint32 public override proposedLimitActivationTime;


    address public immutable override admin;

    address payable public override orderFeeAccount;
    address payable public override gasFeeAccount;
    address payable public override fillFeeAccount;

    struct ConstructorArgs {
        uint32 LIMIT_CHANGE_NOTICE_DURATION;
        uint32 FEE_CHANGE_NOTICE_DURATION;
        uint8 MAX_INCREASE_ORDER_FEE_PCT;
        uint8 MAX_INCREASE_TRANCHE_FEE_PCT;

        FeeSchedule fees;
        FeeSchedule limits;

        address admin;
        address payable orderFeeAccount;
        address payable gasFeeAccount;
        address payable fillFeeAccount;
    }

    constructor (ConstructorArgs memory args) {
        LIMIT_CHANGE_NOTICE_DURATION = args.LIMIT_CHANGE_NOTICE_DURATION;
        FEE_CHANGE_NOTICE_DURATION = args.FEE_CHANGE_NOTICE_DURATION;
        MAX_INCREASE_ORDER_FEE_PCT = args.MAX_INCREASE_ORDER_FEE_PCT;
        MAX_INCREASE_TRANCHE_FEE_PCT = args.MAX_INCREASE_TRANCHE_FEE_PCT;

        _fees = args.fees;
        _limits = args.limits;

        admin = args.admin;
        orderFeeAccount = args.orderFeeAccount;
        gasFeeAccount = args.gasFeeAccount;
        fillFeeAccount = args.fillFeeAccount;

        emit FeesChanged(args.fees);
        emit FeeLimitsChanged(args.limits);
    }


    function fees() public view override returns (FeeSchedule memory) {
        return proposedFeeActivationTime != 0 && proposedFeeActivationTime <= block.timestamp ? _proposedFees : _fees;
    }


    function limits() public view override returns (FeeSchedule memory) {
        return proposedLimitActivationTime != 0 && proposedLimitActivationTime <= block.timestamp ? _proposedLimits : _limits;
    }


    //
    // Admin
    //

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }


    function _push() internal {
        // if existing proposals have become active, set them as the main schedules.
        if (proposedLimitActivationTime != 0 && proposedLimitActivationTime <= block.timestamp) {
            _limits = _proposedLimits;
            proposedLimitActivationTime = 0;
        }
        if (proposedFeeActivationTime != 0 && proposedFeeActivationTime <= block.timestamp) {
            _fees = _proposedFees;
            proposedFeeActivationTime = 0;
        }
    }


    function setFees(FeeSchedule calldata sched) public override onlyAdmin {
        _push();

        // check limits
        FeeSchedule memory limit = limits();

        uint256 orderFee = sched.orderFee << sched.orderExp;
        uint256 orderFeeLimit = limit.orderFee << limit.orderExp;
        require( orderFee <= orderFeeLimit );

        uint256 gasFee = sched.gasFee << sched.gasExp;
        uint256 gasFeeLimit = limit.gasFee << limit.gasExp;
        require( gasFee <= gasFeeLimit );

        require( sched.fillFeeHalfBps <= limit.fillFeeHalfBps );

        _proposedFees = sched;
        proposedFeeActivationTime = uint32(block.timestamp + FEE_CHANGE_NOTICE_DURATION);
        emit FeesProposed(sched, proposedFeeActivationTime);
    }


    function setLimits(FeeSchedule calldata sched) public override onlyAdmin {
        _push();
        // Fee Limits may be changed with a much longer notice period.
        _proposedLimits = sched;
        proposedLimitActivationTime = uint32(block.timestamp + LIMIT_CHANGE_NOTICE_DURATION);
        emit FeeLimitsProposed(sched, proposedLimitActivationTime);
    }


    function setFeeAccounts(
        address payable fillFeeAccount_,
        address payable orderFeeAccount_,
        address payable gasFeeAccount_
    ) public override onlyAdmin {
        fillFeeAccount = fillFeeAccount_;
        orderFeeAccount = orderFeeAccount_;
        gasFeeAccount = gasFeeAccount_;
    }

}


library FeeManagerLib {

    function defaultFeeManager() internal returns (FeeManager) {
        address payable a = payable(msg.sender);
        return defaultFeeManager(a);
    }


    function defaultFeeManager(address payable owner) internal returns (FeeManager) {
        return FeeManagerLib.defaultFeeManager(owner, owner, owner, owner);
    }


    function defaultFeeManager(
        address admin,
        address payable orderFeeAccount,
        address payable gasFeeAccount,
        address payable fillFeeAccount
    ) internal
    returns (FeeManager) {
        uint32 limitChangeNoticeDuration = 30 * 24 * 60 * 60; // 30 days
        uint32 feeChangeNoticeDuration = 1 * 60 * 60; // 1 hour
        uint8 maxIncreaseOrderFeePct = 10; // 10% per hour (within the limits)
        uint8 maxIncreaseTrancheFeePct = 100; // 100% per hour (within the limits) gas prices can change quickly

        // todo limits
        // about $1 at $4000 ETH
        uint8 orderFee = 227;
        uint8 orderExp = 40;
        // about 5¢ at $4000 ETH
        uint8 gasFee = 181;
        uint8 gasExp = 36;
        uint8 fillFeeHalfBps = 30; // 15 bps fill fee

        IFeeManager.FeeSchedule memory fees = IFeeManager.FeeSchedule(
            orderFee, orderExp,
            gasFee, gasExp,
            fillFeeHalfBps
        );
        IFeeManager.FeeSchedule memory limits = IFeeManager.FeeSchedule(
            orderFee, orderExp,
            gasFee, gasExp,
            fillFeeHalfBps
        );
        FeeManager.ConstructorArgs memory args = FeeManager.ConstructorArgs(
            limitChangeNoticeDuration, feeChangeNoticeDuration, maxIncreaseOrderFeePct, maxIncreaseTrancheFeePct,
            fees, limits, admin, orderFeeAccount, gasFeeAccount, fillFeeAccount
        );
        return new FeeManager(args);
    }


    function freeFeeManager() internal returns (FeeManager) {
        address payable a = payable(msg.sender);
        return freeFeeManager(a);
    }


    function freeFeeManager(address payable owner) internal returns (FeeManager) {
        return FeeManagerLib.freeFeeManager(owner, owner, owner, owner);
    }


    function freeFeeManager(
        address admin,
        address payable orderFeeAccount,
        address payable gasFeeAccount,
        address payable fillFeeAccount
    ) internal
    returns (FeeManager) {
        uint32 limitChangeNoticeDuration = 5 * 60 * 60; // LIMIT_CHANGE_NOTICE_DURATION 5 minutes
        uint32 feeChangeNoticeDuration = 2 * 60 * 60; // FEE_CHANGE_NOTICE_DURATION 2 minutes
        uint8 maxIncreaseOrderFeePct = 10; // 10% per hour (within the limits)
        uint8 maxIncreaseTrancheFeePct = 100; // 100% per hour (within the limits) gas prices can change quickly

        uint8 orderFee = 0;
        uint8 orderExp = 0;
        uint8 gasFee = 0;
        uint8 gasExp = 0;
        uint8 fillFeeHalfBps = 0;

        IFeeManager.FeeSchedule memory fees = IFeeManager.FeeSchedule(
            orderFee, orderExp,
            gasFee, gasExp,
            fillFeeHalfBps
        );
        IFeeManager.FeeSchedule memory limits = IFeeManager.FeeSchedule(
            orderFee, orderExp,
            gasFee, gasExp,
            fillFeeHalfBps
        );
        FeeManager.ConstructorArgs memory args = FeeManager.ConstructorArgs(
            limitChangeNoticeDuration, feeChangeNoticeDuration, maxIncreaseOrderFeePct, maxIncreaseTrancheFeePct,
            fees, limits, admin, orderFeeAccount, gasFeeAccount, fillFeeAccount
        );
        return new FeeManager(args);
    }


    function debugFeeManager() internal returns (FeeManager) {
        address payable a = payable(msg.sender);
        return debugFeeManager(a);
    }


    function debugFeeManager(address payable owner) internal returns (FeeManager) {
        return FeeManagerLib.debugFeeManager(owner, owner, owner, owner);
    }


    function debugFeeManager(
        address admin,
        address payable orderFeeAccount,
        address payable gasFeeAccount,
        address payable fillFeeAccount
    ) internal
    returns (FeeManager) {
        uint32 limitChangeNoticeDuration = 5 * 60 * 60; // LIMIT_CHANGE_NOTICE_DURATION 5 minutes
        uint32 feeChangeNoticeDuration = 2 * 60 * 60; // FEE_CHANGE_NOTICE_DURATION 2 minutes
        uint8 maxIncreaseOrderFeePct = 10; // 10% per hour (within the limits)
        uint8 maxIncreaseTrancheFeePct = 100; // 100% per hour (within the limits) gas prices can change quickly

        // todo limits
        // about $1 at $4000 ETH
        uint8 orderFee = 227;
        uint8 orderExp = 40;
        // about 5¢ at $4000 ETH
        uint8 gasFee = 181;
        uint8 gasExp = 36;
        uint8 fillFeeHalfBps = 30; // 15 bps fill fee

        IFeeManager.FeeSchedule memory fees = IFeeManager.FeeSchedule(
            orderFee, orderExp,
            gasFee, gasExp,
            fillFeeHalfBps
        );
        IFeeManager.FeeSchedule memory limits = IFeeManager.FeeSchedule(
            orderFee, orderExp,
            gasFee, gasExp,
            fillFeeHalfBps
        );
        FeeManager.ConstructorArgs memory args = FeeManager.ConstructorArgs(
            limitChangeNoticeDuration, feeChangeNoticeDuration, maxIncreaseOrderFeePct, maxIncreaseTrancheFeePct,
            fees, limits, admin, orderFeeAccount, gasFeeAccount, fillFeeAccount
        );
        return new FeeManager(args);
    }


}

