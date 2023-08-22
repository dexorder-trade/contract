// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/console2.sol";
import "../src/MockERC20.sol";
import "../src/Util.sol";
import "../src/Constants.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";


contract MockEnv {

    INonfungiblePositionManager public nfpm = Constants.uniswapV3NonfungiblePositionManager;
    ISwapRouter public swapper = Constants.uniswapV3SwapRouter;
    IUniswapV3Pool public pool;
    uint24 public fee;
    MockERC20 public COIN;
    MockERC20 public USD;
    address public token0; // either WETH or USDC depending on the order in the pool
    address public token1;
    bool public inverted;


    function init() public {
        COIN = new MockERC20('Mock Coin', 'MOCK', 18);
        USD = new MockERC20('Universally Supported Dollars', 'USD', 6);
        fee = 500;
        inverted = address(COIN) > address(USD);
        token0 = inverted ? address(USD) : address(COIN);
        token1 = inverted ? address(COIN) : address(USD);
        uint160 initialPrice = 1 * 2**96;
        // if this reverts here make sure Anvil is started and you are running forge with --rpc-url
        pool = IUniswapV3Pool(nfpm.createAndInitializePoolIfNecessary(token0, token1, fee, initialPrice));
        int24 ts = pool.tickSpacing();
        (, int24 lower, , , , ,) = pool.slot0();
        int24 upper = lower;
        for (int8 i = 0; i < 10; i++) {
            lower -= ts;
            upper += ts;
            stake(1 * 10 ** COIN.decimals(), 1000 * 10 ** USD.decimals(), lower, upper);
        }
    }


    function stake(uint128 liquidity_, int24 lower, int24 upper) public
    returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    )
    {
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(lower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(upper);
        (uint160 sqrtPriceX96, , , , , ,) = pool.slot0();
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, liquidity_);
        return _stake(amount0, amount1, lower, upper);
    }

    function stake(uint256 coinAmount, uint256 usdAmount, int24 lower, int24 upper) public
    returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    )
    {
        return _stake(coinAmount, usdAmount, lower, upper);
    }

    function _stake(uint256 coinAmount, uint256 usdAmount, int24 lower, int24 upper) private
    returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    )
    {
        COIN.mint(address(this), coinAmount);
        COIN.approve(address(nfpm), coinAmount);
        USD.mint(address(this), usdAmount);
        USD.approve(address(nfpm), usdAmount);
        //   struct MintParams {
        //        address token0;
        //        address token1;
        //        uint24 fee;
        //        int24 tickLower;
        //        int24 tickUpper;
        //        uint256 amount0Desired;
        //        uint256 amount1Desired;
        //        uint256 amount0Min;
        //        uint256 amount1Min;
        //        address recipient;
        //        uint256 deadline;
        //    }
        int24 ts = pool.tickSpacing();
        lower = Util.roundTick(lower, ts);
        upper = Util.roundTick(upper, ts);
        (uint256 a0, uint256 a1) = inverted ? (usdAmount, coinAmount) : (coinAmount, usdAmount);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams(
            token0, token1, fee, lower, upper, a0, a1, 0, 0, msg.sender, block.timestamp
        );
        return nfpm.mint(params);
    }


    function swap(MockERC20 inToken, MockERC20 outToken, uint256 amountIn) public returns (uint256 amountOut) {
        uint160 limit = address(inToken) == pool.token0() ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        return swap(inToken, outToken, amountIn, limit);
    }

    function swap(MockERC20 inToken, MockERC20 outToken, uint256 amountIn, uint160 sqrtPriceLimitX96) public returns (uint256 amountOut) {
        inToken.approve(address(swapper), amountIn);
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
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            address(inToken), address(outToken), fee, msg.sender, block.timestamp, amountIn, 0, sqrtPriceLimitX96
        );
        return swapper.exactInputSingle(params);
    }
}
