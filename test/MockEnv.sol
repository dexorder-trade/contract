
pragma solidity 0.8.28;

import "@forge-std/console2.sol";
import "../src/more/MockERC20.sol";
import "../src/core/Util.sol";
import "./MockUtil.sol";
import "../lib_uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../lib_uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "../lib_uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "../src/more/FeeManagerLib.sol";
import "../src/core/VaultImpl.sol";
import "../src/core/VaultFactory.sol";
import {ArbitrumRouter} from "../src/core/Router.sol";


contract MockEnv {

    IVaultFactory public factory;

    INonfungiblePositionManager private nfpm =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88); // Arbitrum

    IUniswapV3Pool public pool;
    uint24 public fee;
    MockERC20 public COIN;
    MockERC20 public USD;
    address public token0; // either COIN or USD depending on the order in the pool
    address public token1;
    bool public inverted;

    // sets up two mock coins COIN and USD, plus a uniswap v3 pool.
    function init() public {
        initNoFees();
    }

    function initDebugFees() public {
        return init(new ArbitrumRouter(), FeeManagerLib.debugFeeManager());
    }

    function initNoFees() public {
        return init(new ArbitrumRouter(), FeeManagerLib.freeFeeManager());
    }

    function init(IRouter router, FeeManager feeManager) public {
//        console2.log('init MockEnv...');
        VaultImpl impl = new VaultImpl(router, feeManager, address(0));
        factory = new VaultFactory(msg.sender, address(impl), 2*60); // 2 minutes upgrade notice

        console2.log('MockEnv: msg.sender:', msg.sender);
//        console2.log('MockEnv: tx.origin:' , tx.origin);
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
        console2.log('if this is the last line before a revert then make sure to run forge with --rpc-url');
        // if this reverts here make sure Anvil is started and you are running forge with --rpc-url
        pool = IUniswapV3Pool(nfpm.createAndInitializePoolIfNecessary(token0, token1, fee, oneSqrtX96()));
        console2.log('v3 pool');
        console2.log(address(pool));
        // stake a super wide range so we have liquidity everywhere.
        uint256 amount = 10_000*1774545 * 10**12; // 1774545 is the number of ticks so this is $10k liquidity per 0.1%
        stake(amount, amount, TickMath.MIN_TICK, TickMath.MAX_TICK);
    }


    function oneSqrtX96() public view returns (uint160) {
        return inverted ? uint160(79228162514264337593543950336000000) : uint160(79228162514264337593543); // $1.00 * 2^96 * 10^±12
    }


    function swapTo1() public {
        swapToPrice(oneSqrtX96());
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

        uint256 a0 = inverted ? usdAmount : coinAmount;
        uint256 a1 = inverted ? coinAmount : usdAmount;
        if (inverted) {
            lower = -upper;
            upper = -lower;
        }

        (tokenId, liquidity, amount0, amount1) = MockUtil.stake(pool, a0, a1, lower, upper);
    }

    function swap(MockERC20 inToken, MockERC20 outToken, uint256 amountIn) public returns (uint256 amountOut) {
        uint160 limit = address(inToken) == pool.token0() ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;
        return swap(inToken, outToken, amountIn, limit);
    }

    function swap(MockERC20 inToken, MockERC20 outToken, uint256 amountIn, uint160 sqrtPriceLimitX96) public returns (uint256 amountOut) {
        return MockUtil.swap(pool, inToken, outToken, amountIn, sqrtPriceLimitX96);
    }

    function price() public view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,,) = pool.slot0();
    }

    function swapToPrice(uint160 sqrtPriceLimitX96) public {
        MockUtil.swapToPrice(pool, sqrtPriceLimitX96);
    }
}
