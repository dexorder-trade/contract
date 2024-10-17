
pragma solidity 0.8.26;

import "./UniswapV3.sol";
import "./OrderSpec.sol";
import "./UniswapSwapper.sol";
import {IRouter} from "../interface/IRouter.sol";

contract Router is IRouter, UniswapV3Swapper {

    constructor (
        IUniswapV3Factory uniswapV3Factory, ISwapRouter uniswapV3SwapRouter, uint32 uniswapV3OracleSeconds
    )
    UniswapV3Swapper(uniswapV3Factory, uniswapV3SwapRouter, uniswapV3OracleSeconds)
    {
    }


    function rawPrice(Exchange exchange, address tokenIn, address tokenOut, uint24 maxFee) external view
    returns (uint256) {
        if (exchange == Exchange.UniswapV3)
            return _univ3_rawPrice(tokenIn, tokenOut, maxFee);
        revert('UR');
    }

    function protectedPrice(Exchange exchange, address tokenIn, address tokenOut, uint24 maxFee) external view
    returns (uint256) {
        if (exchange == Exchange.UniswapV3)
            return _univ3_protectedPrice(tokenIn, tokenOut, maxFee);
        revert('UR');
    }

    function swap( Exchange exchange, SwapParams memory params ) external
    returns (uint256 amountIn, uint256 amountOut) {
        if (exchange == Exchange.UniswapV3)
            return _univ3_swap(params);
        revert('UR');
    }

}


contract ArbitrumRouter is Router {
    constructor()
    Router(
        UniswapV3Arbitrum.factory,
        UniswapV3Arbitrum.swapRouter,
        10  // Slippage TWAP window
    ) {}
}


contract ArbitrumSepoliaRouter is Router {
    constructor()
    Router(
        UniswapV3ArbitrumSepolia.factory,
        UniswapV3ArbitrumSepolia.swapRouter,
        10  // Slippage TWAP window
    ) {}
}

