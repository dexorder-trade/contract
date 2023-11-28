// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
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
    address public token0; // either COIN or USD depending on the order in the pool
    address public token1;
    bool public inverted;

    // sets up two mock coins COIN and USD, plus a uniswap v3 pool.
    // the initial price is 1.000000, but since COIN has 18 decimals and USD only has 6, the raw pool price is 1e-12
    // therefore the sqrt price is 1e-6
    // 1000e12 liquidity is put into the pool at each tick spacing for 10 tick spacings to either side of $1
    function init() public {
        COIN = new MockERC20('Mock Ethereum Hardfork', 'MEH', 18);
        console2.log('MEH');
        console2.log(address(COIN));
        USD = new MockERC20('Joke Currency XD', 'USXD', 6);
        console2.log('USXD');
        console2.log(address(USD));
        fee = 500;
        inverted = address(COIN) > address(USD);
        token0 = inverted ? address(USD) : address(COIN);
        token1 = inverted ? address(COIN) : address(USD);
        uint160 initialPrice = inverted ? uint160(79228162514264337593543950336000000) : uint160(79228162514264337593543); // $1.00
        console2.log('if this is the last line before a revert then make sure to run forge with --rpc-url');
        // if this reverts here make sure Anvil is started and you are running forge with --rpc-url
        pool = IUniswapV3Pool(nfpm.createAndInitializePoolIfNecessary(token0, token1, fee, initialPrice));
        console2.log('v3 pool');
        console2.log(address(pool));
        // stake a super wide range so we have liquidity everywhere.
        stake(10_000_000, TickMath.MIN_TICK, TickMath.MAX_TICK);
    }


    function stake(uint256 amount, int24 width) public {
        require(width>0);
        (, int24 tick, , , , ,) = pool.slot0();
        stake(amount, tick-width, tick+width);
    }


    function stake(uint256 amount, int24 lower, int24 upper) public {
        uint256 coinAmount = amount * 10**18 / 2;
        uint256 usdAmount = amount * 10**6 / 2;
        stake(coinAmount, usdAmount, lower, upper);
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
//        console2.log('stake amounts');
//        console2.log(coinAmount);
//        console2.log(usdAmount);
        COIN.mint(address(this), coinAmount);
        COIN.approve(address(nfpm), coinAmount);
//        console2.log('COIN minted');
        USD.mint(address(this), usdAmount);
        USD.approve(address(nfpm), usdAmount);
//        console2.log('USD minted');
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
        uint256 amount0 = inverted ? usdAmount : coinAmount;
        uint256 amount1 = inverted ? coinAmount : usdAmount;
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams(
            token0, token1, fee, lower, upper, amount0, amount1, 0, 0, msg.sender, block.timestamp
        );
        (tokenId, liquidity, amount0, amount1) = nfpm.mint(params);
        console2.log('minted');
        console2.log(liquidity);
        console2.log(amount0);
        console2.log(amount1);
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

    function price() public view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,,) = pool.slot0();
    }

    function swapToPrice(uint160 sqrtPriceLimitX96) public {
        console2.log('swapToPrice');
        console2.log(sqrtPriceLimitX96);
        uint160 curPrice = price();
        console2.log(curPrice);
        if( curPrice == sqrtPriceLimitX96 )
            return;
        MockERC20 inToken = curPrice > sqrtPriceLimitX96 ? MockERC20(token0) : MockERC20(token1);
        MockERC20 outToken = curPrice < sqrtPriceLimitX96 ? MockERC20(token0) : MockERC20(token1);
        // instead of calculating how much we need, we just mint an absurd amount
        uint256 aLot = 2**100;
        inToken.mint(address(this), aLot);
        swap(inToken, outToken, aLot, sqrtPriceLimitX96);
    }
}
