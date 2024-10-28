
pragma solidity 0.8.26;

import "../../lib_uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../../lib_uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "../../lib_uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "../../lib_uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IWETH9} from "../../lib_uniswap/v3-periphery/contracts/interfaces/external/IWETH9.sol";


library UniswapV3 {
    function getPool( IUniswapV3Factory factory, address tokenA, address tokenB, uint24 fee) internal pure
    returns (IUniswapV3Pool) {
        PoolAddress.PoolKey memory key = PoolAddress.getPoolKey(tokenA, tokenB, fee);
        return IUniswapV3Pool(PoolAddress.computeAddress(address(factory), key));
    }
}


// Uniswap v3 on Arbitrum One
library UniswapV3Arbitrum {
    IWETH9 public constant weth9 = IWETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IUniswapV3Factory public constant factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    INonfungiblePositionManager public constant nfpm = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
}

// TESTNET
library UniswapV3ArbitrumSepolia {
    IUniswapV3Factory public constant factory = IUniswapV3Factory(0x248AB79Bbb9bC29bB72f7Cd42F17e054Fc40188e);
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    INonfungiblePositionManager public constant nfpm = INonfungiblePositionManager(0x6b2937Bde17889EDCf8fbD8dE31C3C2a70Bc4d65);
}

