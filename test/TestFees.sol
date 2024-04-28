// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

import {Test} from  "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {FullMath} from '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {MockEnv, MockERC20} from "./MockEnv.sol";
import {Factory} from "../src/Factory.sol";
import {Dexorder} from "../src/Dexorder.sol";
import {IVault} from "../src/interface/IVault.sol";
import {OrderLib} from "../src/OrderLib.sol";
import {float} from "../src/IEEE754.sol";

contract TestFees is MockEnv, Test {

    Factory public factory;
    IVault public vault;
    Dexorder public dexorder;

    Dexorder.FeeSched feeSched = Dexorder.FeeSched(100,1,2,3,1);

    function getPriceX96(address poolAddress) public view returns (uint256) {
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddress).slot0();
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1<<96);
    }

    // function logPrice() public view {
    //     uint256 priceX96 = getPriceX96(address(pool));
    //     console2.log("getPrice:", priceX96>>96, priceX96&(1<<96-1), priceX96);
    //     console2.log("fee:", IUniswapV3Pool(address(pool)).fee());
    // }

    function setUp() public {
        init();
        dexorder = new Dexorder();
        vm.prank(address(0));
        dexorder.SetFeeSched(feeSched);
        factory = new Factory(dexorder);
        vault = IVault(factory.deployVault(address(this)));
        vm.deal(payable(address(vault)), 1 ether);
    }

    uint64 constant nOrders = 5;
    uint64 constant nSingles = 2; // nSingles must be <= nOrders
    uint16 constant nTranches = 3;

    function testFees() public {

        require(nSingles <= nOrders, "testFees: nSingles <= nOrders violated");

        address fillFeeAccount   = dexorder.fillFeeAccount.address;
        address nativeFeeAccount = dexorder.orderFeeAccount.address;
        assert(dexorder.orderFeeAccount.address == dexorder.trancheFeeAccount.address);

        // Set up Tranches and fund USD

        OrderLib.Tranche[] memory tranches = new OrderLib.Tranche[](nTranches);
        for (uint i=0; i<nTranches; i++) {
            tranches[i].fraction = OrderLib.MAX_FRACTION / nTranches;
            tranches[i].endTime = OrderLib.DISTANT_FUTURE;
            tranches[i].marketOrder = true;
        }

        uint256 trancheAmount = 1 * 10**COIN.decimals() / 10; // 0.3 COIN
        uint256 amount = trancheAmount * nTranches;
        // console2.log("COIN.decimals():", COIN.decimals());
        // console2.log("USD.decimals():", USD.decimals());
        // console2.log("amount * nOrders:", amount * nOrders);
        COIN.mint(address(vault), amount * nOrders); // create COIN to sell
        // console2.log("Mint: COIN.balanceOf:", COIN.balanceOf(address(vault)));

        // Swap order

        OrderLib.SwapOrder memory order = OrderLib.SwapOrder(
            address(COIN), address(USD), // sell COIN for USD
            OrderLib.Route(OrderLib.Exchange.UniswapV3, fee), amount, amount/100, true, false,
            OrderLib.NO_CHAIN, tranches
        );
        
        // Place order and verify fees

        uint256 vaultBalance = address(vault).balance;
        uint256 expectedFee = (feeSched.order<<feeSched.orderExp);
            expectedFee += tranches.length*(feeSched.tranche<<feeSched.trancheExp);
            expectedFee *= nOrders;

        // try some placeDexorder

        for (uint8 i=0; i<nSingles; i++)
            vault.placeDexorder(order);

        // try some placeDexorders

        OrderLib.SwapOrder[] memory orders = new OrderLib.SwapOrder[](nOrders-nSingles);
        for (uint8 i=0; i<nOrders-nSingles; i++)
            orders[i] = order;
        vault.placeDexorders(orders, OrderLib.OcoMode.NO_OCO);

        // Check fees

        require(address(vault).balance == vaultBalance - expectedFee, "native order fee wrong");
        require(nativeFeeAccount.balance == expectedFee, "native order fee wrong");

        // Execute and verify fees

        // logPrice();
        uint256 expectedCOINbalance = COIN.balanceOf(address(vault));
        uint256 vaultUSDbalance = USD.balanceOf(address(vault));
        uint256 expectedUSDbalance_afterPrice = vaultUSDbalance;
        uint256 expectedUSDbalance_beforePrice = vaultUSDbalance;

        for (uint8 trancheIndex=0; trancheIndex<nTranches; trancheIndex++)
            for (uint8 orderIndex=0; orderIndex<nOrders; orderIndex++) {

                uint256 beforePrice = getPriceX96(address(pool));
                vault.execute(orderIndex, trancheIndex, OrderLib.PriceProof(0));
                uint256 afterPrice = getPriceX96(address(pool));
                require(afterPrice >= beforePrice, "testFees: beforePrice > afterPrice!");

                expectedCOINbalance -= trancheAmount;
                require(
                    COIN.balanceOf(address(vault)) == expectedCOINbalance,
                    "testFees: Bad COIN balance"
                    );
                // console2.log("vault balances: COIN, USD:", COIN.balanceOf(address(vault)), USD.balanceOf(address(vault)));
                // logPrice();

                // expectedUSDbalance using beforePrice

                uint256 expectedTrancheUSD;
                uint256 dexorderFeeAmount_beforePrice;
                expectedTrancheUSD = FullMath.mulDiv(trancheAmount, 1<<96, beforePrice);
                expectedTrancheUSD = FullMath.mulDiv(expectedTrancheUSD, 1000000 - IUniswapV3Pool(address(pool)).fee(), 1000000);
                dexorderFeeAmount_beforePrice = FullMath.mulDiv(expectedTrancheUSD, feeSched.fillFeeBP, 20000);
                expectedTrancheUSD -= dexorderFeeAmount_beforePrice;
                expectedUSDbalance_beforePrice += expectedTrancheUSD;

                // expectedUSDbalance using afterPrice

                uint256 dexorderFeeAmount_afterPrice;
                expectedTrancheUSD = FullMath.mulDiv(trancheAmount, 1<<96, afterPrice);
                expectedTrancheUSD = FullMath.mulDiv(expectedTrancheUSD, 1000000 - IUniswapV3Pool(address(pool)).fee(), 1000000);
                dexorderFeeAmount_afterPrice = FullMath.mulDiv(expectedTrancheUSD, feeSched.fillFeeBP, 20000);
                expectedTrancheUSD -= dexorderFeeAmount_afterPrice;
                expectedUSDbalance_afterPrice += expectedTrancheUSD;

                // Check that vaultUSDbalance matches expected

                vaultUSDbalance = USD.balanceOf(address(vault));

                console2.log("expected USD balance:", expectedUSDbalance_beforePrice);
                console2.log("expected USD balance:", expectedUSDbalance_afterPrice);
                console2.log("vault    USD balance:", vaultUSDbalance);
                console2.log("fillFee  USD balance:", USD.balanceOf(fillFeeAccount));

                require(
                    expectedUSDbalance_beforePrice >= vaultUSDbalance
                    && vaultUSDbalance >= expectedUSDbalance_afterPrice,
                    "testFees: Bad USD balance"
                    );

            }

    }

}
