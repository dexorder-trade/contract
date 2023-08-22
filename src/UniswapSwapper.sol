// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "./Constants.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


library UniswapSwapper {

    struct SwapParams {
        address pool;
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 amount;
        uint160 sqrtPriceLimitX96;
    }

    function swapExactInput(SwapParams memory params) internal returns (string memory error, uint256 amountOut)
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

        try Constants.uniswapV3SwapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.fee, recipient: address(this), // todo return directly to wallet?
            deadline: block.timestamp, amountIn: params.amount, amountOutMinimum: 0, sqrtPriceLimitX96: params.sqrtPriceLimitX96
        })) returns (uint256 filledOut) {
            amountOut = filledOut;
            error = Constants.SWAP_OK;
        }
        catch Error(string memory reason) {
            amountOut = 0;
            error = reason;
        }
    }


    function swapExactOutput(SwapParams memory params) internal returns (string memory error, uint256 amountIn)
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
            return ('IIA', 0);
        }
        try Constants.uniswapV3SwapRouter.exactOutputSingle(ISwapRouter.ExactOutputSingleParams({
            tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.fee, recipient: t, // todo return directly to wallet?
            deadline: block.timestamp, amountOut: params.amount, amountInMaximum: balance,     // todo use only the committed allocation?
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        })) returns (uint256 filledIn) {
            amountIn = filledIn;
            error = Constants.SWAP_OK;
        }
        catch Error(string memory reason) {
            amountIn = 0;
            error = reason;
        }
    }

}
