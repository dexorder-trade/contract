
pragma solidity 0.8.28;

import {IFeeManager,FeeManager} from "../core/FeeManager.sol";

library FeeManagerLib {

    function defaultFeeManager() internal returns (FeeManager) {
        address payable a = payable(msg.sender);
        return defaultFeeManager(a);
    }


    function defaultFeeManager(address payable owner) internal returns (FeeManager) {
        return FeeManagerLib.defaultFeeManager(owner, owner, owner, owner, owner);
    }


    function defaultFeeManager(
        address admin,
        address adjuster,
        address payable orderFeeAccount,
        address payable gasFeeAccount,
        address payable fillFeeAccount
    ) internal
    returns (FeeManager) {
        uint32 limitChangeNoticeDuration = 7 * 24 * 60 * 60; // 7 days
        uint32 feeChangeNoticeDuration = 1 * 60 * 60; // 1 hour
        uint8 maxIncreaseOrderFeePct = 10; // 10% per hour (within the limits)
        uint8 maxIncreaseTrancheFeePct = 10; // 10% per hour (within the limits) gas prices can change quickly

        // Arbitrum gas price is typically 65_000_000 when block space is competitive
        // gasPrice = 65_000_000;
        // orderGas = 425_000;
        // executeGas = 275_000;
        //
        // This leads to the following values:

        uint8 orderFee = 201;
        uint8 orderExp = 37;
        uint8 gasFee = 130;
        uint8 gasExp = 37;
        uint8 fillFeeHalfBps = 30; // 15 bps fill fee

        IFeeManager.FeeSchedule memory fees = IFeeManager.FeeSchedule(
            orderFee, orderExp,
            gasFee, gasExp,
            fillFeeHalfBps
        );
        // we set the limits to 16x the baseline by adding 4 to the exponent
        uint8 expShift = 4;
        IFeeManager.FeeSchedule memory limits = IFeeManager.FeeSchedule(
            orderFee, orderExp + expShift,
            gasFee, gasExp + expShift,
            fillFeeHalfBps
        );
        FeeManager.ConstructorArgs memory args = FeeManager.ConstructorArgs(
            limitChangeNoticeDuration, feeChangeNoticeDuration, maxIncreaseOrderFeePct, maxIncreaseTrancheFeePct,
            fees, limits, admin, adjuster, orderFeeAccount, gasFeeAccount, fillFeeAccount
        );
        return new FeeManager(args);
    }


    function freeFeeManager() internal returns (FeeManager) {
        address payable a = payable(msg.sender);
        return freeFeeManager(a);
    }


    function freeFeeManager(address payable owner) internal returns (FeeManager) {
        return FeeManagerLib.freeFeeManager(owner, owner, owner, owner, owner);
    }


    function freeFeeManager(
        address admin,
        address adjuster,
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
            fees, limits, admin, adjuster, orderFeeAccount, gasFeeAccount, fillFeeAccount
        );
        return new FeeManager(args);
    }


    function debugFeeManager() internal returns (FeeManager) {
        return debugFeeManager(payable(msg.sender));
    }


    function debugFeeManager(address payable owner) internal returns (FeeManager) {
        return FeeManagerLib.debugFeeManager(owner, owner, owner, owner, owner);
    }


    function debugFeeManager(
        address admin,
        address adjuster,
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
            fees, limits, admin, adjuster, orderFeeAccount, gasFeeAccount, fillFeeAccount
        );
        return new FeeManager(args);
    }


}

