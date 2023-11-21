// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

library Constants {
    uint8 internal constant VERSION = 0;

    IUniswapV3Factory internal constant uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    INonfungiblePositionManager internal constant uniswapV3NonfungiblePositionManager
        = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    ISwapRouter internal constant uniswapV3SwapRouter
        = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

}
