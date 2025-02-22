
pragma solidity 0.8.28;

interface IFeeManager {

    struct FeeSchedule {
        uint8 orderFee;
        uint8 orderExp;
        uint8 gasFee;
        uint8 gasExp;
        uint8 fillFeeHalfBps;
    }

    // Emitted when a new VaultImpl is proposed by the upgrader account
    event FeesProposed(FeeSchedule indexed fees, uint32 indexed activationTime);

    // Emitted when a new VaultImpl contract has fulfilled its waiting period and become the new default implementation
    event FeesChanged(FeeSchedule indexed fees);

    // Emitted when a new fee limits are proposed by the upgrader account
    event FeeLimitsProposed(FeeSchedule indexed limits, uint32 indexed activationTime);

    // Emitted when a new fee limit schedule has fulfilled its waiting period and become the new fee limits
    event FeeLimitsChanged(FeeSchedule indexed limits);

    event FeeAccountsChanged(
        address payable orderFeeAccount,
        address payable gasFeeAccount,
        address payable fillFeeAccount
    );

    // Currently active fee schedule. Orders follow the FeeSchedule in effect at placement time.
    function fees() external view returns (FeeSchedule memory);

    // The fee schedule cannot exceed these maximum values unless the upgrader account proposes a new set of limits
    // first, which is subject to the extended waiting period imposed by proposedLimitActivationTime()
    function limits() external view returns (FeeSchedule memory);

    function proposedFees() external view returns (FeeSchedule memory);
    function proposedFeeActivationTime() external view returns (uint32);
    function proposedLimits() external view returns (FeeSchedule memory);
    function proposedLimitActivationTime() external view returns (uint32);


    //
    // Accounts
    //

    // The admin account may change the fees, limits, and fee account addresses.
    function admin() external view returns (address);

    // The adjuster account may change the fees.
    function adjuster() external view returns (address);

    // The three fee types are each sent to a separate address for accounting.
    function orderFeeAccount() external view returns (address payable);
    function gasFeeAccount() external view returns (address payable);
    function fillFeeAccount() external view returns (address payable);

    // The admin or the adjuster may change the fees within the limits after only a short delay
    function setFees(FeeSchedule calldata sched) external;

    // Only the admin may change the fee limits themselves after a long delay
    function setLimits(FeeSchedule calldata sched) external;

    // Only the admin may change the adjuster account.
    function setAdjuster(address adjuster) external;

    // The admin may adjust the destination of fees at any time
    function setFeeAccounts(
        address payable orderFeeAccount,
        address payable gasFeeAccount,
        address payable fillFeeAccount
    ) external;

}
