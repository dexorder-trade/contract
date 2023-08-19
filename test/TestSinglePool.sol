// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "forge-std/console2.sol";
import "../src/MockERC20.sol";
import "uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "uniswap/v3-core/contracts/libraries/TickMath.sol";
import "uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";


contract TestSinglePool {

    IUniswapV3Factory public factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    INonfungiblePositionManager public nfpm = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    ISwapRouter public swapper = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Pool public immutable pool;
    uint24 public fee;
    MockERC20 public WETH;
    MockERC20 public USDC;
    MockERC20 public token0; // either WETH or USDC depending on the order in the pool
    MockERC20 public token1;

    function setUp() public {
        MockERC20 weth = MockERC20('Mock Wrapped Ethereum', 'WETH', 18);
        MockERC20 usdc = MockERC20('Mock USD Coin', 'USDC', 6);
        uint24 fee_ = 500;
        fee = fee_;
        WETH = weth;
        USDC = usdc;
        IUniswapV3Pool pool_ = UniswapV3Pool(factory.createPool(address(weth), address(usdc), fee_));
        pool = pool_;
        token0 = pool_.token0();
        token1 = pool_.token1();
    }

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

    function stake(uint160 liquidity, uint24 lower, uint24 upper) public {
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(lower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(upper);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(liquidity, sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96);
        token0.mint(amount0);
        token1.mint(amount1);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams(
            address(token0), address(token1), fee, lower, upper, amount0, amount1, 0, 0, msg.sender, block.timestamp
        );
        nfpm.mint(params);
    }


    function swap() public {

    }
}

