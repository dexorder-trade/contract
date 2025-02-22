
pragma solidity 0.8.28;

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";
import {MockEnv} from  "./MockEnv.sol";
import {VaultFactory} from "../src/core/VaultFactory.sol";
import {Dexorder} from "../src/more/Dexorder.sol";
import {IVault} from "../src/interface/IVault.sol";
import "../src/core/OrderSpec.sol";

contract TestCancelOrder is MockEnv, Test {

    IVault public vault;

    // vault gets 100,000 COIN and 100,000 USD
    function setUp() public {
        initNoFees();
        vault = IVault(factory.deployVault(address(this)));
        vm.deal(payable(address(vault)), 1 ether); // native for fees
        uint256 coinAmount = 100_000 * 10 ** COIN.decimals();
        COIN.mint(address(vault), coinAmount);
        uint256 usdAmount = 100_000 * 10 ** USD.decimals();
        USD.mint(address(vault), usdAmount);
    }

    function placeOrder() public {
        Tranche[] memory tranches = new Tranche[](3);
        tranches[0].fraction = 21845;
        tranches[0].startTimeIsRelative = true;
        tranches[0].startTime = 0;
        tranches[1].fraction = 21845;
        tranches[1].startTimeIsRelative = true;
        tranches[1].startTime = 60;
        tranches[2].fraction = 21845;
        tranches[2].startTimeIsRelative = true;
        tranches[2].startTime = 120;
        uint256 amount = 100000000000000000000;

        SwapOrder memory order  = SwapOrder(
            0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            Route(Exchange.UniswapV3, 500), amount, amount/100, true, false, false,
            NO_CONDITIONAL_ORDER, tranches
        );
        vault.placeDexorder(order);
    }

    // Simple test

    function testCancelOrder() public {
       placeOrder();
       placeOrder();
       placeOrder();
       assert( vault.numSwapOrders() == 3 );

       vault.cancelDexorder(0);
       assert( vault.orderCanceled(0) );
       assert( !vault.orderCanceled(1) );
       assert( !vault.orderCanceled(2) );

       vault.cancelDexorder(2);
       assert( vault.orderCanceled(0) );
       assert( !vault.orderCanceled(1) );
       assert( vault.orderCanceled(2) );

       vault.cancelAllDexorders();
       assert( vault.orderCanceled(0) );
       assert( vault.orderCanceled(1) );
       assert( vault.orderCanceled(2) );

       placeOrder();
       assert( vault.numSwapOrders() == 4 );
       assert( vault.orderCanceled(0) );
       assert( vault.orderCanceled(1) );
       assert( vault.orderCanceled(2) );
       assert( !vault.orderCanceled(3) );

       vault.cancelAllDexorders();
       assert( vault.orderCanceled(0) );
       assert( vault.orderCanceled(1) );
       assert( vault.orderCanceled(2) );
       assert( vault.orderCanceled(3) );
    }

}
