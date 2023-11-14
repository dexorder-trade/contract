// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;
pragma abicoder v2;

import "forge-std/Test.sol";

library IEEE754 {

    // reduce (signed)) int to p bits

    function bits2int (uint256 b, uint256 p) internal pure returns (int256 r) {
        require(p >= 1 && p <= 256, "p invalid");
        uint256 s = 256 - p;
        r = int256( b << s ) >> s;
    }

    int32  internal constant EBIAS      = 127;
    int32  internal constant ENAN       = 0xff; // Also includes infinity
    int32  internal constant ESUBNORM   = 0;

    uint32 internal constant SIGN_MASK  = 0x8000_0000;
    uint32 internal constant EXP_MASK   = 0x7f80_0000;
    uint32 internal constant MANT_MASK  = 0x007f_ffff;
    uint32 internal constant ZERO_MASK  = EXP_MASK | MANT_MASK;
    int32  internal constant MSB        = 0x0080_0000;

    // Todo rounding

    function float2fixed(uint32 floatingPoint, uint32 fixedBits) internal pure returns (int256 fixedPoint) {unchecked{

        // Zero case

        if (floatingPoint & ZERO_MASK == 0) return 0;

        // Extract exponent field

        int32  exp = int32(floatingPoint & EXP_MASK) >> 23;
        require (exp != ENAN, "NaN not supported");

        // Extract mantisa
    
        int256 mant = int32(floatingPoint & MANT_MASK);
        if (exp != ESUBNORM) mant |= MSB;                 // Add implied MSB to non-subnormal
        if (floatingPoint & SIGN_MASK != 0) mant = -mant; // Negate if sign bit set

        // Compute shift amount

        exp = exp - EBIAS; // Remove exponent bias
        int256 rshft = 23 - int32(fixedBits) - exp; // Zero exp and integer fixedPoint throws away all but MSB

        // Shift to arrive at fixed point alignment

        if (rshft < 0) // Most likely case?
            fixedPoint = mant << uint256(-rshft);
        else if (rshft > 0)
            fixedPoint = mant >> uint256(rshft);
        else
            fixedPoint = mant;

        return fixedPoint;
    }}
}

contract TestIEEE754 is Test {

    function setUp() external pure {
        console2.log('TestFloat setup()');
    }

    // Useful constants

    uint256 constant internal umin = 0;
    uint256 constant internal umax = ~umin;           // 0xff...
    int256  constant internal imax = int256(umax>>1); // 0x7f...
    int256  constant internal imin = ~imax;           // 0x80...

    // must be external because called as this.sanityReverts

    function sanityReverts(int256 t) external pure {
        console2.log("sanityReverts", t);
        uint256 u;
        int256 i;
        if (t == 1) {
            u = umax+1; // Overflow
        } else if (t == 2) {
            u = umin-1; // Underflow
        } else if (t == 3) {
            i = imax+1; // Overflow
        } else if (t == 4) {
            i = imin-1; // Underflow
        } else {
            // Will not revert
        }
    }

    function testSanity() external {
        console2.log('Float.testSanity()');
        int256 i;
        for (i=1; i<=4; i++) {
            vm.expectRevert();
            this.sanityReverts(i); // Convoluted way to check reverts
        }
        i = imax << 1; // Changes sign bit, but should not over/underflow
        i = imin << 1; // Changes sign bit, but should not over/underflow
    }

    struct Item {
        uint32 floatingPoint;
        uint32 fixedBits;
        int256 fixedPoint;
    }

    function testFloat2fixed() external pure {
        console2.log('TestIEEE754.testFloat2fixed()');

        Item[6] memory items = [
            Item(0x3f800000, 0, 1 << 0),      // 1.0
            Item(0x3f800000, 128, 1 << 128),  // 1.0
            Item(0x3f800000, 254, 1 << 254),  // 1.0
            Item(0xbf800000, 128, -1 << 128), // -1.0
            Item(0x40000000, 128, 2 << 128),  // 1.0
            Item(0xc0000000, 128, -2 << 128)  // 1.0
            // ,Item(0xbf800001, 128, -1 << 128) // Failing case for test debugging purposes
        ];

        for (uint i=0; i<items.length; i++) {
            require(items[i].fixedPoint == IEEE754.float2fixed(
                items[i].floatingPoint, items[i].fixedBits
                ));
        }

    }
}
