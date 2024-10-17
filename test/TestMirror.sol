
pragma solidity 0.8.26;

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";
import {UniswapV3Arbitrum} from "../src/core/UniswapV3.sol";
import "./MirrorEnv.sol";

contract TestMirror is Test {

    MirrorEnv public mirror;
    MirrorEnv.TokenInfo public tokenInfo0;
    MirrorEnv.TokenInfo public tokenInfo1;

    function setUp() public virtual {
        mirror = new MirrorEnv(UniswapV3Arbitrum.nfpm, UniswapV3Arbitrum.swapRouter);
        tokenInfo0 = MirrorEnv.TokenInfo(IERC20Metadata(address(0x1234)), 'Test', 'TST', 18);
        tokenInfo1 = MirrorEnv.TokenInfo(IERC20Metadata(address(0x12345)), 'Testy', 'TSTY', 8);
    }

}


contract TestMirrorToken is TestMirror {
    function testMirrorToken() public {
        mirror.mirrorToken(tokenInfo0);
    }
}


contract TestMirrorPool is TestMirror {

    MockERC20 public mock0;
    MockERC20 public mock1;

    function setUp() public override {
        TestMirror.setUp();
        mock0 = mirror.mirrorToken(tokenInfo0);
        mock1 = mirror.mirrorToken(tokenInfo1);
        console2.log('MirrorPool setUp');
    }

    function testMirrorPool() public {
        MirrorEnv.PoolInfo memory poolInfo = MirrorEnv.PoolInfo(
            IUniswapV3Pool(address(0x4321)), // IUniswapV3Pool pool;
            tokenInfo0.addr, // IERC20Metadata token0;
            tokenInfo1.addr, // IERC20Metadata token1;
            3000, // uint24 fee;
            2**96, // uint160 sqrtPriceX96;
            1_000_000 * 10 ** tokenInfo0.decimals, // uint256 amount0;
            1_000_000 * 10 ** tokenInfo1.decimals  // uint256 amount1;
        );
        mirror.mirrorPool(poolInfo);
    }
}

