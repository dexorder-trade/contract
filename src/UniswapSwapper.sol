// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
pragma abicoder v2;

import "./Constants.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "v3-periphery/libraries/TransferHelper.sol";
import "forge-std/console2.sol";


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

    function swapExactInput(SwapParams memory params) internal returns (uint256 amountIn, uint256 amountOut)
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
        console2.log('swapExactInput approve...');
        console2.log(address(this));
        console2.log(params.tokenIn);
        console2.log(params.tokenOut);
        console2.log(uint(params.fee));
        console2.log(address(params.recipient));
        console2.log(params.amount);
        console2.log(uint(params.sqrtPriceLimitX96));
        console2.log(address(Constants.uniswapV3SwapRouter));

        amountIn = params.amount;
        uint256 balance = IERC20(params.tokenIn).balanceOf(address(this));
        if( balance == 0 ) {
            // todo dust?
            revert('IIA');
        }
        if( balance < amountIn )
            amountIn = balance;

        TransferHelper.safeApprove(params.tokenIn, address(Constants.uniswapV3SwapRouter), amountIn);
//        if (params.sqrtPriceLimitX96 == 0)
//            params.sqrtPriceLimitX96 = params.tokenIn < params.tokenOut ? TickMath.MIN_SQRT_RATIO+1 : TickMath.MAX_SQRT_RATIO-1;

        console2.log('swapping...');
        amountOut = Constants.uniswapV3SwapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.fee, recipient: params.recipient,
            deadline: block.timestamp, amountIn: amountIn, amountOutMinimum: 1, sqrtPriceLimitX96: params.sqrtPriceLimitX96
        }));
        console2.log('swapped');
        console2.log(amountOut);
        TransferHelper.safeApprove(params.tokenIn, address(Constants.uniswapV3SwapRouter), 0);
    }

    function swapExactOutput(SwapParams memory params) internal returns (uint256 amountIn, uint256 amountOut)
    {
        // TODO copy changes over from swapExactInput

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
        uint256 balance = IERC20(params.tokenIn).balanceOf(address(this));
        if( balance == 0 ) {
            // todo dust?
            revert('IIA');
        }
        uint256 maxAmountIn = balance;

        console2.log('swapExactOutput approve...');
        console2.log(address(this));
        console2.log(params.tokenIn);
        console2.log(params.tokenOut);
        console2.log(uint(params.fee));
        console2.log(address(params.recipient));
        console2.log(params.amount);
        console2.log(uint(params.sqrtPriceLimitX96));
        console2.log(address(Constants.uniswapV3SwapRouter));
        console2.log('approve');
        console2.log(maxAmountIn);

        TransferHelper.safeApprove(params.tokenIn, address(Constants.uniswapV3SwapRouter), maxAmountIn);

//        if (params.sqrtPriceLimitX96 == 0)
//            params.sqrtPriceLimitX96 = params.tokenIn < params.tokenOut ? TickMath.MIN_SQRT_RATIO+1 : TickMath.MAX_SQRT_RATIO-1;

        console2.log('swapping...');
        try Constants.uniswapV3SwapRouter.exactOutputSingle(ISwapRouter.ExactOutputSingleParams({
            tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.fee, recipient: params.recipient,
            deadline: block.timestamp, amountOut: params.amount, amountInMaximum: maxAmountIn,
            sqrtPriceLimitX96: params.sqrtPriceLimitX96
        })) returns (uint256 amtIn) {
            amountIn = amtIn;
            amountOut = params.amount;
        }
        catch Error( string memory reason ) {
            // todo check reason before trying exactinput
            // if the input amount was insufficient, use exactInputSingle to spend whatever remains.
            try Constants.uniswapV3SwapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams({
                tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.fee, recipient: params.recipient,
                deadline: block.timestamp, amountIn: maxAmountIn, amountOutMinimum: 1, sqrtPriceLimitX96: params.sqrtPriceLimitX96
            })) returns (uint256 amtOut) {
                amountIn = maxAmountIn;
                amountOut = amtOut;
            }
            catch Error( string memory ) {
                revert(reason); // revert on the original reason
            }
        }

        console2.log('swapped');
        console2.log(amountIn);
        console2.log(amountOut);

        TransferHelper.safeApprove(params.tokenIn, address(Constants.uniswapV3SwapRouter), 0);
    }

}
