
pragma solidity 0.8.26;

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";
import {MockEnv, MockERC20} from "./MockEnv.sol";
import {VaultFactory} from "../src/core/VaultFactory.sol";
import {Dexorder} from "../src/more/Dexorder.sol";
import {IVault} from "../src/interface/IVault.sol";
import "../src/core/OrderSpec.sol";
import {float} from "../src/core/IEEE754.sol";

contract TestOrder is MockEnv, Test {

    IVault public vault;

    // vault gets 100,000 COIN and 100,000 USD
    function setUp() public virtual {
        initNoFees();
        vault = IVault(factory.deployVault(address(this)));
        uint256 coinAmount = 100_000 * 10 ** COIN.decimals();
        COIN.mint(address(vault), coinAmount);
        uint256 usdAmount = 100_000 * 10 ** USD.decimals();
        USD.mint(address(vault), usdAmount);
    }


    function testPlaceOrder() public {
        placeOrder();
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
        console2.logBytes(abi.encode(order));
        console2.log("testPlaceOrder: calling vault.numSwapOrders");
        console2.log(vault.numSwapOrders());
        
        console2.log("testPlaceOrder: Placing order");
        vault.placeDexorder(order);
    }
}

contract TestExecute is TestOrder {

    uint256 public coinInitialBalance;
    uint256 public usdInitialBalance;
    uint64 public exactOutputOrderIndex;
    uint64 public exactInputOrderIndex;
    uint64 public limitOrderIndex;

    function setUp() public override {
        TestOrder.setUp();

        coinInitialBalance = 1_000_000 * 10**COIN.decimals();
        usdInitialBalance = 1_000_000 * 10**USD.decimals();
        COIN.mint(address(vault), coinInitialBalance);
        USD.mint(address(vault), usdInitialBalance);

        // #0: Exact Output Order
        Tranche[] memory tranches = new Tranche[](1);
        tranches[0].fraction = MAX_FRACTION;
        tranches[0].endTime = DISTANT_FUTURE;
        tranches[0].marketOrder = true;
        uint256 amount = 3 * 10**USD.decimals() / 10; // 0.3 USD
        SwapOrder memory order  = SwapOrder(
            address(COIN), address(USD), // sell COIN for USD
            Route(Exchange.UniswapV3, 500), amount, amount/100, false, false,
            false, NO_CONDITIONAL_ORDER, tranches
        );
        exactOutputOrderIndex = vault.numSwapOrders();
        vault.placeDexorder(order);

        // #1: Exact Input Order
        tranches = new Tranche[](1);
        tranches[0].fraction = MAX_FRACTION;
        tranches[0].endTime = DISTANT_FUTURE;
        tranches[0].marketOrder = true;
        amount = 3 * 10**COIN.decimals() / 10; // 0.3 COIN
        order  = SwapOrder(
            address(COIN), address(USD), // sell COIN for USD
            Route(Exchange.UniswapV3, fee), amount, amount/100, true, false,
            false, NO_CONDITIONAL_ORDER, tranches
        );
        exactInputOrderIndex = vault.numSwapOrders();
        vault.placeDexorder(order);

        buildLimitOrder();

    }

    function testExecuteOrderExactOutput() public {
        vault.execute(exactOutputOrderIndex, 0, PriceProof(0));
    }


    function testExecuteOrderExactInput() public {
        vault.execute(exactInputOrderIndex, 0, PriceProof(0));
    }


    function buildLimitOrder() private {
        // #2: Limit Order
        // test selling token0 above a certain price
        Tranche[] memory tranches = new Tranche[](1);
        tranches[0].fraction = MAX_FRACTION;
        tranches[0].endTime = DISTANT_FUTURE;
        tranches[0].minLine.intercept = inverted ? float.wrap(0x5368da9b) : float.wrap(0x2b8cc066); // float 1.0001e±12
        MockERC20 token = MockERC20(token0);
        uint256 amount = 3*10**token.decimals() / 10; // selling 0.3 token0
        SwapOrder memory order  = SwapOrder(
            token0, token1, // sell
            Route(Exchange.UniswapV3, fee), amount, amount/100, true, false,
            false, NO_CONDITIONAL_ORDER, tranches
        );
        limitOrderIndex = vault.numSwapOrders();
        vault.placeDexorder(order);
    }

    function testExecuteLimitOrder() public {
        swapTo1();
        vm.expectRevert(bytes('LL'));
        // should revert with code 'LL' because the initial limit is above the current price
        vault.execute(limitOrderIndex, 0, PriceProof(0));
        console2.log('inverted');
        console2.log(inverted);
        console2.log('original price');
        console2.log(price());
        // better price for token0
        uint160 newPrice = oneSqrtX96()*10002/10000;
        swapToPrice(newPrice); // move price to be above our limit
        console2.log('new price');
        console2.log(newPrice);
        vault.execute(limitOrderIndex, 0, PriceProof(0)); // should work now
    }

}
