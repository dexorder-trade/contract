
pragma solidity 0.8.26;

//import "@forge-std/console2.sol";
import "../src/more/MockERC20.sol";
import "../src/core/Util.sol";
import {IUniswapV3Pool} from "../lib_uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "../lib_uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {ISwapRouter} from "../lib_uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20Metadata} from "../lib_uniswap/v3-periphery/contracts/interfaces/IERC20Metadata.sol";
import "./MockUtil.sol";


contract MirrorEnv {

    struct MockPool {
        IUniswapV3Pool pool;
        bool inverted; // true iff the mock pool's token0/1 are flipped relative to the original pool
    }

    // map original token addresses to their mock counterparts
    mapping(IERC20Metadata=>MockERC20) public tokens;
    // map original pool addresses to their mock counterparts
    mapping(IUniswapV3Pool=>MockPool) public pools;

    INonfungiblePositionManager immutable public nfpm;
    ISwapRouter immutable public swapRouter;

    constructor (INonfungiblePositionManager nfpm_, ISwapRouter swapRouter_) {
        nfpm = nfpm_;
        swapRouter = swapRouter_;
    }

    struct TokenInfo {
        IERC20Metadata addr;
        string name;
        string symbol;
        uint8 decimals;
    }

    function mirrorToken( TokenInfo memory info ) public returns (MockERC20 mock) {
//        console2.log('MirrorEnv.mirrorToken()');
//        console2.log(address(info.addr));
        mock = tokens[info.addr];
        if ( address(mock) == address(0) ) {
//            console2.log('creating mock token');
//            console2.log(info.name);
//            console2.log(info.symbol);
//            console2.log(info.decimals);
            mock = new MockERC20(info.name, info.symbol, info.decimals);
//            console2.log('setting tokens[]');
            tokens[info.addr] = mock;
//            console2.log('set tokens[]');
        }
//        console2.log(address(mock));
//        console2.log('mirrorToken complete');
    }


    struct PoolInfo {
        IUniswapV3Pool pool;
        IERC20Metadata token0;
        IERC20Metadata token1;
        uint24 fee;
        uint160 sqrtPriceX96;
        uint256 amount0;
        uint256 amount1;
    }

    // given the original pool address, create a similar pool using mock tokens
    function mirrorPool( PoolInfo memory info ) public returns (MockPool memory mock) {
//        console2.log('MirrorEnv.mirrorPool()');
//        console2.log(address(info.pool));
        mock = pools[info.pool];
//        console2.log(address(mock.pool));
        if ( address(mock.pool) == address(0) ) {
//            console2.log('creating mirror pool');
            MockERC20 token0 = tokens[info.token0];
            MockERC20 token1 = tokens[info.token1];
//            console2.log(address(info.token0));
//            console2.log(address(token0));
//            console2.log(address(info.token1));
//            console2.log(address(token1));
            require(address(token0)!=address(0), 'token0 not mirrored');
            require(address(token1)!=address(0), 'token1 not mirrored');
            // put 100th of the total liquidity on each of the 1774545 ticks
            uint256 amount0 = info.amount0 * 1774545 / 100;
            uint256 amount1 = info.amount1 * 1774545 / 100;
            uint160 initialPrice = info.sqrtPriceX96;
            bool inverted = token0 > token1;
//            console2.log('got tokens.  inverted?');
            if( inverted ) {
                (token0, token1) = (token1, token0);
                (amount0, amount1) = (amount1, amount0);
                initialPrice = uint160(2**96 * 2**96 / uint256(initialPrice));
            }
//            console2.log(inverted);
//            console2.log(address(token0));
//            console2.log(address(token1));
//            console2.log(info.fee);
//            console2.log(initialPrice);
            IUniswapV3Pool mockPool = IUniswapV3Pool(nfpm.createAndInitializePoolIfNecessary(
                address(token0), address(token1), info.fee, initialPrice));
            mock = MockPool(mockPool, inverted);
//            console2.log('mirror pool / inverted');
//            console2.log(address(mockPool));
//            console2.log(inverted);
            pools[info.pool] = mock;
//            console2.log('staking');
            MockUtil.stakeWide( nfpm, mockPool, amount0, amount1);
//            console2.log('staked');
        }
//        console2.log('mirrored pool');
    }

    function mirrorPools( PoolInfo[] memory pool ) public returns (MockPool[] memory mock) {
        mock = new MockPool[](pool.length);
        for( uint i=0; i<pool.length; i++ )
            mock[i] = mirrorPool(pool[i]);
    }

    // change the price of a mock pool based on the original pool price
    function updatePool( IUniswapV3Pool pool, uint160 sqrtPriceX96 ) public returns (MockPool memory mock) {
//        console2.log('updating');
//        console2.log(address(pool));
        mock = pools[pool];
        require( address(mock.pool) != address(0), 'not mirrored' );
        if (mock.inverted) {
//            console2.log('inverting');
//            console2.log(sqrtPriceX96);
            sqrtPriceX96 = uint160(uint256(2**96 * 2**96) / uint256(sqrtPriceX96));
        }
        MockUtil.swapToPrice(swapRouter, mock.pool, sqrtPriceX96);
//        console2.log('updated pool');
    }

    struct PoolUpdateInfo {
        IUniswapV3Pool pool;
        uint160 sqrtPriceX96;
    }

    function updatePools( PoolUpdateInfo[] memory infos ) public returns (MockPool[] memory mock) {
        mock = new MockPool[](infos.length);
        for( uint i=0; i<infos.length; i++ ) {
            PoolUpdateInfo memory info = infos[i];
            mock[i] = updatePool(info.pool, info.sqrtPriceX96);
        }
    }

}
