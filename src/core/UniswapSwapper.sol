
pragma solidity 0.8.26;

import "@forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Util} from "./Util.sol";
import {UniswapV3} from "../core/UniswapV3.sol";
import {IUniswapV3Pool} from "../../lib_uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "../../lib_uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {TickMath} from "../../lib_uniswap/v3-core/contracts/libraries/TickMath.sol";
import {ISwapRouter} from "../../lib_uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../../lib_uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {PoolAddress} from "../../lib_uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {IRouter} from "../interface/IRouter.sol";


contract UniswapV3Swapper {
    // The top of this contract implements the ISwapper interface in terms of the UniswapV3 specific methods
    // at the bottom

    ISwapRouter private immutable swapRouter;
    IUniswapV3Factory private immutable factory;
    uint32 private immutable oracleSeconds;

    constructor( IUniswapV3Factory factory_, ISwapRouter swapRouter_, uint32 oracleSeconds_ ) {
        factory = factory_;
        swapRouter = swapRouter_;
        oracleSeconds = oracleSeconds_;
    }

    function _univ3_rawPrice(address tokenIn, address tokenOut, uint24 maxFee) internal view
    returns (uint256 price) {
        (IUniswapV3Pool pool, bool inverted) = UniswapV3.getPool(factory, tokenIn, tokenOut, maxFee);
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        return Util.sqrtToPrice(sqrtPriceX96, inverted);
    }

    // Returns the stabilized (oracle) price
    function _univ3_protectedPrice(address tokenIn, address tokenOut, uint24 maxFee) internal view
    returns (uint256)
    {
        // console2.log('oracle');
        // console2.log(oracleSeconds);
        if (oracleSeconds!=0){
            (IUniswapV3Pool pool, bool inverted) = UniswapV3.getPool(factory, tokenIn, tokenOut, maxFee);
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = oracleSeconds;
            secondsAgos[1] = 0;
            try pool.observe(secondsAgos) returns (int56[] memory cumulative, uint160[] memory) {
                int56 delta = cumulative[1] - cumulative[0];
                int32 secsI = int32(oracleSeconds);
                int24 mean = int24(delta / secsI);
                if (delta < 0 && (delta % secsI != 0))
                    mean--;
                // use Uniswap's tick-to-sqrt-price because it's verified
                uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(mean);
                return Util.sqrtToPrice(sqrtPriceX96, inverted);
            }
            catch Error( string memory /*reason*/ ) {
                //fall through to return the rawPrice
                // console2.log('oracle broken');
            }
        }
        return _univ3_rawPrice(tokenIn, tokenOut, maxFee);
    }

    function _univ3_swap(IRouter.SwapParams memory params) internal
    returns (uint256 amountIn, uint256 amountOut) {
        if( params.limitPriceX96 != 0 ) {
            bool inverted = params.tokenIn > params.tokenOut;
            if (inverted) {
                // console2.log('inverting params.limitPriceX96');
                // console2.log(params.limitPriceX96);
                params.limitPriceX96 = 2**96 * 2**96 / params.limitPriceX96;
            }
            // console2.log('params.limitPriceX96');
            // console2.log(params.limitPriceX96);
        }
        if (params.amountIsInput)
            (amountIn, amountOut) = _univ3_swapExactInput(params);
        else
            (amountIn, amountOut) = _univ3_swapExactOutput(params);
    }


    function _univ3_swapExactInput(IRouter.SwapParams memory params) internal
    returns (uint256 amountIn, uint256 amountOut)
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
        // console2.log('swapExactInput');
        // console2.log(address(this));
        // console2.log(params.tokenIn);
        // console2.log(params.tokenOut);
        // console2.log(uint(params.maxFee));
        // console2.log(address(params.recipient));
        // console2.log(params.amount);
        // console2.log(params.amountIsInput);
        // console2.log(uint(params.limitPriceX96));
        // console2.log(address(swapRouter));

        amountIn = params.amount;
        uint256 balance = IERC20(params.tokenIn).balanceOf(address(this));
        // console2.log('amountIn balance');
        // console2.log(balance);
        if( balance == 0 || balance < params.minAmount ) // minAmount is units of input token
            revert('IIA');
        if( balance < amountIn )
            amountIn = balance;

        TransferHelper.safeApprove(params.tokenIn, address(swapRouter), amountIn);
//        if (params.sqrtPriceLimitX96 == 0)
//            params.sqrtPriceLimitX96 = params.tokenIn < params.tokenOut ? TickMath.MIN_SQRT_RATIO+1 : TickMath.MAX_SQRT_RATIO-1;

        uint160 sqrtPriceLimitX96 = uint160(Util.sqrt(uint256(params.limitPriceX96)<<96));
        // console2.log('sqrt price limit x96');
        // console2.log(uint(sqrtPriceLimitX96));

        // console2.log('swapping...');
        amountOut = swapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams({
            tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.maxFee, recipient: params.recipient,
            deadline: block.timestamp, amountIn: amountIn, amountOutMinimum: 1, sqrtPriceLimitX96: sqrtPriceLimitX96
        }));
        // console2.log('swapped');
        // console2.log(amountOut);
        TransferHelper.safeApprove(params.tokenIn, address(swapRouter), 0);
        // console2.log('revoked approval');
    }

    function _univ3_swapExactOutput(IRouter.SwapParams memory params) internal
    returns (uint256 amountIn, uint256 amountOut)
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
        uint256 balance = IERC20(params.tokenIn).balanceOf(address(this));
        if( balance == 0 )
            revert('IIA');
        uint256 maxAmountIn = balance;

        // console2.log('swapExactOutput');
        // console2.log(address(this));
        // console2.log(params.tokenIn);
        // console2.log(params.tokenOut);
        // console2.log(uint(params.maxFee));
        // console2.log(address(params.recipient));
        // console2.log(params.amount);
        // console2.log(uint(params.limitPriceX96));
        // console2.log(address(swapRouter));
        // console2.log('approve');
        // console2.log(maxAmountIn);

        TransferHelper.safeApprove(params.tokenIn, address(swapRouter), maxAmountIn);

        uint160 sqrtPriceLimitX96 = uint160(Util.sqrt(uint256(params.limitPriceX96)<<96));
        // console2.log('sqrt price limit x96');
        // console2.log(uint(sqrtPriceLimitX96));

        // console2.log('swapping...');
        try swapRouter.exactOutputSingle(ISwapRouter.ExactOutputSingleParams({
            tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.maxFee, recipient: params.recipient,
            deadline: block.timestamp, amountOut: params.amount, amountInMaximum: maxAmountIn,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        })) returns (uint256 amtIn) {
            amountIn = amtIn;
            amountOut = params.amount;
        }
        catch Error( string memory reason ) {
            // todo check reason before trying exactinput
            // if the input amount was insufficient, use exactInputSingle to spend whatever remains.
            try swapRouter.exactInputSingle(ISwapRouter.ExactInputSingleParams({
                tokenIn: params.tokenIn, tokenOut: params.tokenOut, fee: params.maxFee, recipient: params.recipient,
                deadline: block.timestamp, amountIn: maxAmountIn, amountOutMinimum: 1, sqrtPriceLimitX96: sqrtPriceLimitX96
            })) returns (uint256 amtOut) {
                amountIn = maxAmountIn;
                amountOut = amtOut;
            }
            catch Error( string memory ) {
                revert(reason); // revert on the original reason
            }
        }
        // Why should we short-circuit output amounts that are below the minAmount?  We have already paid the gas to
        // get this far. Might as well accept any amount.
        // require( amountOut >= params.minAmount, 'IIA' );
        // console2.log('swapped');
        // console2.log(amountIn);
        // console2.log(amountOut);

        // revoke approval
        TransferHelper.safeApprove(params.tokenIn, address(swapRouter), 0);
    }

}
