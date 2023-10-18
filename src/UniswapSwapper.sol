// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "./Constants.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


library UniswapSwapper {

    struct SwapParams {
        address pool;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint24 fee;
        uint256 amount;
        uint160 sqrtPriceLimitX96;
    }

    function swapExactInput(SwapParams memory params) internal returns (uint256 amountOut)
    {
        //     struct ExactInputSingleParams {
        //        address tokenIn;
        //        address tokenOut;
        //        uint24 fee;
        //        address recipient;
        //        uint256 deadline;
        //        uint256 amountIn;
        //        uint256 amountOutMinimum;
        //        uint160 sqrtPriceLimitX96;
        //    }
        return Constants.uniswapV3SwapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.fee, recipient: params.recipient,
            deadline: block.timestamp, amountIn: params.amount, amountOutMinimum: 0, sqrtPriceLimitX96: params.sqrtPriceLimitX96
        }));
    }

    function swapExactOutput(SwapParams memory params) internal returns (uint256 amountIn)
    {
        //     struct ExactOutputSingleParams {
        //        address tokenIn;
        //        address tokenOut;
        //        uint24 fee;
        //        address recipient;
        //        uint256 deadline;
        //        uint256 amountOut;
        //        uint256 amountInMaximum;
        //        uint160 sqrtPriceLimitX96;
        //    }
        address t = address(this);
        uint256 balance = IERC20(params.tokenIn).balanceOf(t);
        if( balance == 0 ) {
            // todo dust?
            revert('IIA');
        }
        return Constants.uniswapV3SwapRouter.exactOutputSingle(ISwapRouter.ExactOutputSingleParams({
            tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.fee, recipient: params.recipient,
            deadline: block.timestamp, amountOut: params.amount, amountInMaximum: balance,     // todo use only the committed allocation?
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        }));
    }

}
