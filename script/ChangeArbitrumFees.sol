pragma solidity 0.8.28;

import "../src/interface/IFeeManager.sol";
import "../src/interface/IVault.sol";
import "@forge-std/Script.sol";
import "@forge-std/console2.sol";
import {ArbitrumOne} from "../src/chain/ArbitrumOne.sol";
import {IVaultFactory} from "../src/interface/IVaultFactory.sol";

contract ChangeArbitrumFees is Script {
    function run() external {
        // Arbitrum
        assert(block.chainid==42161);
        IFeeManager feeManager = ArbitrumOne.feeManager;
        uint256 fillFeeHalfBpsBig = vm.envUint("FILL_FEE_HALF_BPS");
        assert(fillFeeHalfBpsBig<256);
        uint8 fillFeeHalfBps = uint8(fillFeeHalfBpsBig);

        IFeeManager.FeeSchedule memory fees = feeManager.fees();
        fees.fillFeeHalfBps = fillFeeHalfBps;

        console2.log("admin", feeManager.admin());
        console2.log("adjuster", feeManager.adjuster());

        // Setting fees can fail if the change violates the fee limits.
        vm.broadcast();
        feeManager.setFees(fees);

        // These fees do not take effect right away but enter a "proposed" state for an enforced period of time.
        // This ensures that everyone can see any upcoming fee changes before placing new orders.
        console2.log("New fees will take effect at timestamp", feeManager.proposedFeeActivationTime());
    }
}
