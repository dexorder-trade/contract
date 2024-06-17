// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {MockEnv, MockERC20} from "./MockEnv.sol";
import {VaultFactory} from "../src/core/VaultFactory.sol";
import {Dexorder} from "../src/more/Dexorder.sol";
import {IVault} from "../src/interface/IVault.sol";
import {OrderLib} from "../src/core/OrderLib.sol";
import {float} from "../src/core/IEEE754.sol";

contract TestOrder is MockEnv, Test {

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


    function testPlaceOrder() public {
        OrderLib.Tranche[] memory tranches = new OrderLib.Tranche[](3);
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
        OrderLib.SwapOrder memory order  = OrderLib.SwapOrder(
            0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            OrderLib.Route(OrderLib.Exchange.UniswapV3, 500), amount, amount/100, true, false,
            OrderLib.NO_CONDITIONAL_ORDER, tranches
        );
        console2.logBytes(abi.encode(order));
        // console2.log("testPlaceOrder: calling vault.numSwapOrders");
        // console2.log(vault.numSwapOrders());
        
        // console2.log("testPlaceOrder: Placing order");
        vault.placeDexorder(order);
    }

    function testExecuteOrderExactOutput() public {
        OrderLib.Tranche[] memory tranches = new OrderLib.Tranche[](1);
        tranches[0].fraction = OrderLib.MAX_FRACTION;
        tranches[0].endTime = OrderLib.DISTANT_FUTURE;
        tranches[0].marketOrder = true;
        uint256 amount = 3*10**USD.decimals() / 10; // 0.3 USD
        COIN.mint(address(vault), amount); // create COIN to sell
        OrderLib.SwapOrder memory order  = OrderLib.SwapOrder(
            address(COIN), address(USD), // sell COIN for USD
            OrderLib.Route(OrderLib.Exchange.UniswapV3, 500), amount, amount/100, false, false,
            OrderLib.NO_CONDITIONAL_ORDER, tranches
        );
        uint64 orderIndex = vault.numSwapOrders();
        vault.placeDexorder(order);
        console2.log('placed order');
        console2.log(uint(orderIndex));
        vault.execute(orderIndex, 0, OrderLib.PriceProof(0));
        console2.log('executed');
    }


    function testExecuteOrderExactInput() public {
        OrderLib.Tranche[] memory tranches = new OrderLib.Tranche[](1);
        tranches[0].fraction = OrderLib.MAX_FRACTION;
        tranches[0].endTime = OrderLib.DISTANT_FUTURE;
        tranches[0].marketOrder = true;
        uint256 amount = 3*10**COIN.decimals() / 10; // 0.3 COIN
        COIN.mint(address(vault), amount); // create COIN to sell
        OrderLib.SwapOrder memory order  = OrderLib.SwapOrder(
            address(COIN), address(USD), // sell COIN for USD
            OrderLib.Route(OrderLib.Exchange.UniswapV3, fee), amount, amount/100, true, false,
            OrderLib.NO_CONDITIONAL_ORDER, tranches
        );
        uint64 orderIndex = vault.numSwapOrders();
        vault.placeDexorder(order);
        console2.log('placed order');
        console2.log(uint(orderIndex));
        vault.execute(orderIndex, 0, OrderLib.PriceProof(0));
        console2.log('executed');
    }


    function testExecuteLimitOrder() public {
        // test selling token0 above a certain price
        OrderLib.Tranche[] memory tranches = new OrderLib.Tranche[](1);
        tranches[0].fraction = OrderLib.MAX_FRACTION;
        tranches[0].endTime = OrderLib.DISTANT_FUTURE;
        tranches[0].maxIntercept = float.wrap(0x3f800347); // float 1.0001
        MockERC20 token = MockERC20(token0);
        uint256 amount = 3*10**token.decimals() / 10; // selling 0.3 token0
        token.mint(address(vault), amount);
        OrderLib.SwapOrder memory order  = OrderLib.SwapOrder(
            token0, token1, // sell
            OrderLib.Route(OrderLib.Exchange.UniswapV3, fee), amount, amount/100, true, false,
            OrderLib.NO_CONDITIONAL_ORDER, tranches
        );
        uint64 orderIndex = vault.numSwapOrders();
        vault.placeDexorder(order);
        console2.log('placed order');
        console2.log(uint(orderIndex));

        vm.expectRevert(bytes('LU'));
        vault.execute(orderIndex, 0, OrderLib.PriceProof(0)); // should revert with code 'L'
        console2.log('successfully failed to execute below limit price');

        swapToPrice(price()*10002/10000); // move price to be above our limit
        console2.log('successfully executed at limit price');
    }

}
