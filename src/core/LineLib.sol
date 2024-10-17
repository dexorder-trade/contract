
pragma solidity 0.8.26;

import {IEEE754, float} from "./IEEE754.sol";


struct Line {
    float  intercept; // if marketOrder==true, this is the (positive) max slippage amount
    float  slope;
}


library LineLib {
    using IEEE754 for float;

    function isEnabled(Line storage l) internal view returns (bool) {
        return !l.intercept.isZero() || !l.slope.isZero();
    }

    // use this version for regular lines
    function priceNow(Line storage l) internal view
    returns (uint256 price) {
        int256 b = l.intercept.toFixed(96);
        if(l.slope.isZero())
            return uint256(b);
        int256 m = l.slope.toFixed(96);
        int256 x = int256(block.timestamp);
        price = computeLine(m,b,x);
    }

    // use this version for "ratio" lines that are displaced relative to a start time and price
    function ratioPrice(Line storage l, uint32 startTime, uint256 startPrice) internal view
    returns (uint256 price) {
        int256 ratio = l.intercept.toFixed(96);
        // first we compute the natural intercept using the slope from the start time and price
        // y = mx + b
        // b = y - mx
        int256 y = int256(startPrice);
        int256 m = l.slope.toFixed(96);
        int256 x = int32(startTime);
        int256 mx = m * x; // x is not in X96 format so no denominator adjustment is necessary after m*x
        int256 sb = y - mx;  // starting intercept
        // calculate the ratio
        int256 d = y * ratio / 2**96; // d is the intercept delta
        int256 b = sb + d; // apply the ratio delta to the starting intercept
        price = computeLine(m,b,x);
    }

    function computeLine(int256 m, int256 b, int256 x) internal pure
    returns (uint256 y) {
        // steep lines may overflow any bitwidth quickly, but this would be merely a numerical error not a semantic one.
        // we handle overflows here explicitly, bounding the result to the range [0,MAXINT]
        unchecked {
            int256 z = m * x + b;
            if ((z - b) / m == x) // check the reverse calculation
                y = z <= 0 ? 0 : uint256(z); // no overflow, but bounded to zero. negative prices are not supported.
            else // overflow. bounded to either zero or maxval depending on the slope.
                y = m > 0 ? type(uint256).max : 0;
        }
    }
}
