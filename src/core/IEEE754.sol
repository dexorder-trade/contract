
pragma solidity 0.8.26;

type float is uint32; // https://docs.soliditylang.org/en/latest/types.html#user-defined-value-types

float constant FLOAT_0 = float.wrap(0);

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


    function toFixed(float floatValue, uint8 fixedBits) internal pure returns (int256 fixedPoint) {unchecked{

        uint32 floatingPoint = float.unwrap(floatValue); // compile-time typecast

        // Zero case

        if (floatingPoint & ZERO_MASK == 0) return 0;

        // Extract exponent field

        int32  exp = int32(floatingPoint & EXP_MASK) >> 23;
        require (exp != ENAN, "NaN");

        // Extract mantissa

        int256 mant = int32(floatingPoint & MANT_MASK);
        if (exp == ESUBNORM) mant <<= 1;
        else mant |= MSB;                 // Add implied MSB to non-subnormal
        if (floatingPoint & SIGN_MASK != 0) mant = -mant; // Negate if sign bit set

        // Compute shift amount

        exp = exp - EBIAS; // Remove exponent bias
        int256 rshft = 23 - int32(uint32(fixedBits)) - exp; // Zero exp and integer fixedPoint throws away all but MSB

        // Shift to arrive at fixed point alignment

        if (rshft < 0) // Most likely case?
            fixedPoint = mant << uint256(-rshft);
        else if (rshft > 0)
            fixedPoint = mant >> uint256(rshft);
        else
            fixedPoint = mant;

        return fixedPoint;
    }}

    function isPositive(float f) internal pure returns (bool) {
        return float.unwrap(f) & SIGN_MASK == 0;
    }

    function isNegative(float f) internal pure returns (bool) {
        return float.unwrap(f) & SIGN_MASK != 0;
    }

    function isZero(float f) internal pure returns (bool) {
        return float.unwrap(f) == 0;
    }

}
