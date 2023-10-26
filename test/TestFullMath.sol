// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";
import '@uniswap/v3-core/contracts/libraries/FullMath.sol';

// FullMath relies on wrapping behavior. However, Solidity 0.8 checks by
// default and so FullMath will fail indicating overflow. We have modified
// FullMath to be unchecked. These tests verify that it still operated as
// intended.

contract TestFullMath is Test {

    function setUp() public pure {
        console2.log('FullMath setup()');
    }

    function testFullMath() public pure {

        console2.log('FullMath testFullMath()');

        // Constants

        uint256 MinusOne = uint256(int256(-1));
        uint256 MAXneg = 2**255;
        uint256 MAXpos = ~MAXneg;

        // Check Constants
        require(MAXpos == MinusOne>>1);
        require(MAXneg == MAXpos+1);
        unchecked{
            require(MinusOne+1 == 0);
        }

        // Case 1 -- Max negative values

        uint256 q = FullMath.mulDiv(MAXneg, MAXneg, MAXneg); // DUT
        require(q == MAXneg, "case 1 failed"); // check

        // Case 2 -- All ones (-1) case

        q = FullMath.mulDiv(MinusOne, MinusOne, MinusOne);
        require(q == MinusOne, "case 2 failed");

        // Case 3 -- All max positive values case

        q = FullMath.mulDiv(MAXpos, MAXpos, MAXpos);
        require(q == MAXpos, "case 3 failed");

        // Case 4 -- Mixed pos and neg

        q = FullMath.mulDiv(MAXpos, MAXneg, MAXpos);
        require(q == MAXneg, "case 4a failed");
        q = FullMath.mulDiv(MAXpos, MAXneg, MAXneg);
        require(q == MAXpos, "case 4b failed");
        q = FullMath.mulDiv(MAXpos, MinusOne, MAXpos);
        require(q == MinusOne, "case 4c failed");
        q = FullMath.mulDiv(MAXneg, MinusOne, MAXneg);
        require(q == MinusOne, "case 4d failed");
        q = FullMath.mulDiv(MAXpos, MinusOne, MinusOne);
        require(q == MAXpos, "case 4e failed");
        q = FullMath.mulDiv(MAXneg, MinusOne, MinusOne);
        require(q == MAXneg, "case 4f failed");

        // Case 10 -- various exponents

        uint256 aExp;
        uint256 bExp;
        uint256 dExp;
        uint256 a;
        uint256 b;
        uint256 d;
        uint256 qExpected;

        aExp = 255;
        bExp = 255;
        dExp = 255;

        a = 2**aExp;
        b = 2**bExp;
        d = 2**dExp;
        qExpected = 2**(aExp+bExp-dExp);

        q = FullMath.mulDiv(a,b,d); // DUT
        require(q == qExpected, "case 10 failed"); // check

    }
}
