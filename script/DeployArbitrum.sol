
pragma solidity 0.8.26;

import "@forge-std/Script.sol";
import "@forge-std/console2.sol";
import "../src/more/FeeManagerLib.sol";
import "../src/core/VaultImpl.sol";
import "../src/core/VaultFactory.sol";
import "../src/more/QueryHelper.sol";
import "../src/more/Dexorder.sol";
import "../src/core/Router.sol";

contract DeployArbitrum is Script {
    function run() external {
        address admin = address(0x12DB90820DAFed100E40E21128E40Dcd4fF6B331);
        address payable orderFeeAccount = payable(0x078E0C1112262433375b9aaa987BfF09a08e863C);
        address payable gasFeeAccount = payable(0x411c418C005EBDefB551e5E6B734520Ef2591f51);
        address payable fillFeeAccount = payable(0x152a3a04cE063dC77497aA06b6A09FeFD271E716);
        address WETH = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

        vm.startBroadcast();

        Dexorder dexorder = new Dexorder();
        IRouter router = new ArbitrumRouter();
        FeeManager feeManager = FeeManagerLib.defaultFeeManager(admin, orderFeeAccount, gasFeeAccount, fillFeeAccount);
        VaultImpl impl = new VaultImpl(router, feeManager, WETH);
        VaultFactory factory = new VaultFactory(admin, address(impl), 24 * 60 * 60); // 24-hour upgrade notice
        QueryHelper query = new QueryHelper(UniswapV3Arbitrum.factory);

        vm.stopBroadcast();

        console2.log('ArbitrumRouter', address(router));
        console2.log('Dexorder', address(dexorder));
        console2.log('FeeManager', address(feeManager));
        console2.log('QueryHelper', address(query));
        console2.log('VaultFactory', address(factory));
        console2.log('VaultImpl', address(impl));
    }
}
