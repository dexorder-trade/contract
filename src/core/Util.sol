
pragma solidity 0.8.26;

import "../../lib_uniswap/v3-core/contracts/libraries/FullMath.sol";

library Util {
    // from https://github.com/ethereum/dapp-bin/pull/50/files
    // the same logic as UniswapV2's version of sqrt
    function sqrt(uint x) internal pure returns (uint y) {
        // todo overflow is not possible in this algorithm, correct?  we may wrap it in unchecked {}
        if (x == 0) return 0;
        else if (x <= 3) return 1;
        uint z = (x + 1) / 2;
        y = x;
        while (z < y)
        {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function roundTick(int24 tick, int24 window) internal pure returns (int24) {
        // NOTE: we round half toward zero
        int24 mod = tick % window;
        if (tick < 0)
            return - mod <= window / 2 ? tick - mod : tick - (window + mod);
        else
            return mod > window / 2 ? tick + (window - mod) : tick - mod;
    }

    function sqrtToPrice( uint160 sqrtPriceX96, bool inverted ) internal pure returns (uint256) {
        return inverted ?
            FullMath.mulDiv(2**96 * 2**96 / sqrtPriceX96, 2**96, sqrtPriceX96) :
            FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 2**96);
    }

    function invertX96( uint256 valueX96 ) internal pure returns (uint256) {
        return 2**96 * 2**96 / valueX96;
    }
}
