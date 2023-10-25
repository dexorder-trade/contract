// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
pragma abicoder v2;

library Util {
    function roundTick(int24 tick, int24 window) public pure returns (int24) {
        // NOTE: we round half toward zero
        int24 mod = tick % window;
        if (tick < 0)
            return - mod <= window / 2 ? tick - mod : tick - (window + mod);
        else
            return mod > window / 2 ? tick + (window - mod) : tick - mod;
    }
}
