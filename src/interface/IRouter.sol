
pragma solidity 0.8.28;

import "../core/OrderSpec.sol";

interface IRouter {

    // Returns the current price of the pool for comparison with limit lines.
    function rawPrice(Exchange exchange, address tokenIn, address tokenOut, uint24 maxFee, bool inverted) external view
    returns (uint256);

    // Returns the oracle price, with protections against fast moving price changes (typically used in comparisons to slippage price)
    function protectedPrice(Exchange exchange, address tokenIn, address tokenOut, uint24 maxFee, bool inverted) external view
    returns (uint256);

    struct SwapParams {
        Exchange exchange;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 amount;
        uint256 minAmount;
        bool amountIsInput;
        bool inverted;
        uint256 limitPriceX96;
        uint24 maxFee;
    }

    function swap( SwapParams memory params ) external
    returns (uint256 amountIn, uint256 amountOut);

}
