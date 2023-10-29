// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
pragma abicoder v2;

import "./MockEnv.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Factory.sol";
import "../src/OrderLib.sol";

contract TestOrder is MockEnv, Test {
    using OrderLib for OrderLib.OrdersInfo;

    Factory public factory;
    Vault public vault;

    // vault gets 100,000 COIN and 100,000 USD
    function setUp() public {
        init();
        factory = new Factory();
        vault = Vault(factory.deployVault(address(this)));
        uint256 coinAmount = 100_000 * 10 ** COIN.decimals();
        COIN.mint(address(vault), coinAmount);
        uint256 usdAmount = 100_000 * 10 ** USD.decimals();
        USD.mint(address(vault), usdAmount);
    }


    function testPlaceOrder() public {
        OrderLib.Tranche[] memory tranches = new OrderLib.Tranche[](3);
        OrderLib.Constraint[] memory constraints1 = new OrderLib.Constraint[](1);
        constraints1[0] = OrderLib.Constraint(OrderLib.ConstraintMode.Time, bytes(hex"0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000046500"));
        OrderLib.Constraint[] memory constraints2 = new OrderLib.Constraint[](1);
        constraints2[0] = OrderLib.Constraint(OrderLib.ConstraintMode.Time, bytes(hex"000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000464fb0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000008c9fb"));
        OrderLib.Constraint[] memory constraints3 = new OrderLib.Constraint[](1);
        constraints3[0] = OrderLib.Constraint(OrderLib.ConstraintMode.Time, bytes(hex"0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000008c9f6000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000d2ef6"));
        tranches[0] = OrderLib.Tranche(21845,constraints1);
        tranches[1] = OrderLib.Tranche(21845,constraints2);
        tranches[2] = OrderLib.Tranche(21845,constraints3);
        OrderLib.SwapOrder memory order  = OrderLib.SwapOrder(
            0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            OrderLib.Route(OrderLib.Exchange.UniswapV3, 500), 100000000000000000000, true, false,
            18446744073709551615, tranches
        );
        console2.logBytes(abi.encode(order));
        vault.placeOrder(order);
    }

    function testExecuteOrderExactOutput() public {
        OrderLib.Tranche[] memory tranches = new OrderLib.Tranche[](1);
        OrderLib.Constraint[] memory constraints1 = new OrderLib.Constraint[](1);
        constraints1[0] = OrderLib.Constraint(OrderLib.ConstraintMode.Time, bytes(hex"0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000046500"));
        tranches[0] = OrderLib.Tranche(type(uint16).max,constraints1);
        uint256 amount = 3*10**USD.decimals() / 10; // 0.3 USD
        COIN.mint(address(vault), amount); // create COIN to sell
        OrderLib.SwapOrder memory order  = OrderLib.SwapOrder(
            address(COIN), address(USD), // sell COIN for USD
            OrderLib.Route(OrderLib.Exchange.UniswapV3, 500), amount, false, false,
            OrderLib.NO_CHAIN, tranches
        );
        uint64 orderIndex = vault.numSwapOrders();
        vault.placeOrder(order);
        console2.log('placed order');
        console2.log(uint(orderIndex));
        vault.execute(orderIndex, 0, OrderLib.PriceProof(0));
        console2.log('executed');
    }


    function testExecuteOrderExactInput() public {
        OrderLib.Tranche[] memory tranches = new OrderLib.Tranche[](1);
        OrderLib.Constraint[] memory constraints1 = new OrderLib.Constraint[](1);
        constraints1[0] = OrderLib.Constraint(OrderLib.ConstraintMode.Time, bytes(hex"0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000046500"));
        tranches[0] = OrderLib.Tranche(type(uint16).max,constraints1);
        uint256 amount = 3*10**COIN.decimals() / 10; // 0.3 COIN
        COIN.mint(address(vault), amount); // create COIN to sell
        OrderLib.SwapOrder memory order  = OrderLib.SwapOrder(
            address(COIN), address(USD), // sell COIN for USD
            OrderLib.Route(OrderLib.Exchange.UniswapV3, 500), amount, true, false,
            OrderLib.NO_CHAIN, tranches
        );
        uint64 orderIndex = vault.numSwapOrders();
        vault.placeOrder(order);
        console2.log('placed order');
        console2.log(uint(orderIndex));
        vault.execute(orderIndex, 0, OrderLib.PriceProof(0));
        console2.log('executed');
    }

}
