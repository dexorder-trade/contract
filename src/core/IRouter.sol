// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {OrderLib} from "../core/OrderLib.sol";
pragma abicoder v2;

interface IRouter {

    // Returns the current price of the pool for comparison with limit lines.
    function price(OrderLib.Exchange exchange, address tokenIn, address tokenOut, uint24 maxFee) external view
    returns (uint256);

    // Returns the stabilized (oracle) price for comparison with the slippage setting.
    function slippagePrice(OrderLib.Exchange exchange, address tokenIn, address tokenOut, uint24 maxFee) external view
    returns (uint256);

    struct SwapParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 amount;
        uint256 minAmount;
        bool amountIsInput;
        uint256 limitPriceX96;
        uint24 maxFee;
    }

    function swap( OrderLib.Exchange exchange, SwapParams memory params ) external
    returns (uint256 amountIn, uint256 amountOut);

}
