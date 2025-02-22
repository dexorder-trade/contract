
pragma solidity 0.8.28;

//import "@forge-std/console2.sol";
import "../lib_uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IUniswapV3Pool} from "../lib_uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {MockERC20} from "../src/more/MockERC20.sol";
import "../lib_uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../lib_uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "../src/core/Util.sol";
import "../src/core/UniswapV3.sol";


library MockUtil {
    // 200 is the largest tick spacing. We move our edges inward to prevent violating the extremum when rounding
    int24 constant public FAR_LOWER_TICK = TickMath.MIN_TICK + 200;
    int24 constant public FAR_UPPER_TICK = TickMath.MAX_TICK - 200;

    function swap(IUniswapV3Pool pool,
        MockERC20 inToken, MockERC20 outToken, uint256 amountIn) internal
    returns (uint256 amountOut) {
        return swap(UniswapV3Arbitrum.swapRouter, pool, inToken, outToken, amountIn);
    }


    function swap(ISwapRouter swapper, IUniswapV3Pool pool,
        MockERC20 inToken, MockERC20 outToken, uint256 amountIn) internal
    returns (uint256 amountOut) {
        uint160 limit = address(inToken) == pool.token0() ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        return swap(swapper, pool, inToken, outToken, amountIn, limit);
    }

    function swap(IUniswapV3Pool pool, MockERC20 inToken, MockERC20 outToken,
                  uint256 amountIn, uint160 sqrtPriceLimitX96) internal
    returns (uint256 amountOut) {
        return swap(UniswapV3Arbitrum.swapRouter, pool, inToken, outToken, amountIn, sqrtPriceLimitX96);
    }


    function swap(ISwapRouter swapper, IUniswapV3Pool pool, MockERC20 inToken, MockERC20 outToken,
                  uint256 amountIn, uint160 sqrtPriceLimitX96) internal
    returns (uint256 amountOut) {
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
            address(inToken), address(outToken), pool.fee(), msg.sender, block.timestamp, amountIn, 0, sqrtPriceLimitX96
        );
        return swapper.exactInputSingle(params);
    }

    function price(IUniswapV3Pool pool) internal view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,,) = pool.slot0();
    }


    function swapToPrice(IUniswapV3Pool pool, uint160 sqrtPriceLimitX96) internal {
        return swapToPrice(UniswapV3Arbitrum.swapRouter, pool, sqrtPriceLimitX96);
    }


    function swapToPrice(ISwapRouter swapper, IUniswapV3Pool pool, uint160 sqrtPriceLimitX96) internal {
//        console2.log('swapToPrice');
//        console2.log(sqrtPriceLimitX96);
        uint160 curPrice = price(pool);
//        console2.log(curPrice);
        if( curPrice == sqrtPriceLimitX96 ) {
//            console2.log('no swap needed');
            return;
        }
        MockERC20 token0 = MockERC20(pool.token0());
        MockERC20 token1 = MockERC20(pool.token1());
        MockERC20 inToken = curPrice > sqrtPriceLimitX96 ? MockERC20(token0) : MockERC20(token1);
        MockERC20 outToken = curPrice < sqrtPriceLimitX96 ? MockERC20(token0) : MockERC20(token1);
        // instead of calculating how much we need, we just mint an absurd amount
        uint256 aLot = 2**100;
        inToken.mint(address(this), aLot);
        swap(swapper, pool, inToken, outToken, aLot, sqrtPriceLimitX96);
    }


    function stakeWide(IUniswapV3Pool pool, uint256 amount) internal
    returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        return stake(UniswapV3Arbitrum.nfpm, pool, amount/2, amount/2, FAR_LOWER_TICK, FAR_UPPER_TICK);
    }

    function stakeWide(INonfungiblePositionManager nfpm, IUniswapV3Pool pool, uint256 amount0, uint256 amount1) internal
    returns (uint256 tokenId, uint128 liquidity, uint256 stakedAmount0, uint256 stakedAmount1) {
        return stake(nfpm, pool, amount0, amount1, FAR_LOWER_TICK, FAR_UPPER_TICK);
    }

    function stake(IUniswapV3Pool pool, uint256 amount, int24 width) internal
    returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        return stake(UniswapV3Arbitrum.nfpm, pool, amount, width);
    }


    function stake(INonfungiblePositionManager nfpm, IUniswapV3Pool pool, uint256 amount, int24 width) internal
    returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        require(width>0);
        (, int24 tick, , , , ,) = pool.slot0();
        return stake(nfpm, pool, amount/2, amount/2, tick-width, tick+width);
    }


    function stake(IUniswapV3Pool pool, uint256 token0Amount, uint256 token1Amount, int24 lower, int24 upper) internal
    returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        return stake(UniswapV3Arbitrum.nfpm, pool, token0Amount, token1Amount, lower, upper);
    }


    function stake(INonfungiblePositionManager nfpm, IUniswapV3Pool pool, uint256 token0Amount, uint256 token1Amount, int24 lower, int24 upper) internal
    returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        return _stake(nfpm, pool, token0Amount, token1Amount, lower, upper);
    }

    function _stake(INonfungiblePositionManager nfpm, IUniswapV3Pool pool,
        uint256 token0Amount, uint256 token1Amount, int24 lower, int24 upper) private
    returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
//        console2.log('stake amounts');
//        console2.log(token0Amount);
//        console2.log(token1Amount);
        MockERC20 token0 = MockERC20(pool.token0());
        MockERC20 token1 = MockERC20(pool.token1());
        token0.mint(address(this), token0Amount);
        token0.approve(address(nfpm), token0Amount);
//        console2.log('token0 minted');
        token1.mint(address(this), token1Amount);
        token1.approve(address(nfpm), token1Amount);
//        console2.log('token1 minted');
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
//        console2.log('lower / upper');
//        console2.log(lower);
//        console2.log(upper);
        address recipient = msg.sender;
        if (recipient == address(0) ) // anvil will set msg.sender=0x0 this if there is no specific account and this breaks the NFT mint, so we assign the position to ourselves instead
            recipient = address(this);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams(
            address(token0), address(token1), pool.fee(), lower, upper,
            token0Amount, token1Amount, 0, 0, recipient, block.timestamp
        );
        (tokenId, liquidity, amount0, amount1) = nfpm.mint(params);
//        console2.log('minted liquidity');
//        console2.log(liquidity);
//        console2.log(amount0);
//        console2.log(amount1);
    }

}
