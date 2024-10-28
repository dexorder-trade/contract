
pragma solidity 0.8.26;

import "@forge-std/Test.sol";
import {IEEE754, float} from "../src/core/IEEE754.sol";

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
        float floatingPoint;
        uint8 fixedBits;
        int256 fixedPoint;
    }

    function testToFixed() external pure {
        console2.log('TestIEEE754.testToFixed()');

        Item[11] memory items = [
            Item(float.wrap(0x3f800000), 0, 1 << 0),      // 1.0
            Item(float.wrap(0x3f800000), 128, 1 << 128),  // 1.0
            Item(float.wrap(0x3f800000), 254, 1 << 254),  // 1.0
            Item(float.wrap(0xbf800000), 128, -1 << 128), // -1.0
            Item(float.wrap(0x40000000), 128, 2 << 128),  // 1.0
            Item(float.wrap(0xc0000000), 128, -2 << 128),  // 1.0
            Item(float.wrap(0x00200000), 128, int256(uint256(0x1))), // smallest positive is subnormal
            Item(float.wrap(0x80200000), 128, int256(uint256(int256(-0x1)))), // smallest negative is subnormal
            Item(float.wrap(0x7effffff), 128, int256(uint256(0x7fffff8000000000000000000000000000000000000000000000000000000000))), // largest positive
            Item(float.wrap(0xff7fffff), 128, -int256(uint256(0xffffff0000000000000000000000000000000000000000000000000000000000))), // largest negative
            Item(float.wrap(0x7f7fffff), 128, int256(uint256(0xffffff0000000000000000000000000000000000000000000000000000000000)))
        ];

        for (uint i=0; i<items.length; i++) {
            console2.log("index", i);
            console2.log("exp: %x", uint256(items[i].fixedPoint));
            int256 fixedPoint = IEEE754.toFixed(
                items[i].floatingPoint, items[i].fixedBits
                );
            console2.log("got: %x", uint256(fixedPoint));
            console2.log(IEEE754.isPositive(items[i].floatingPoint)?'     positive':'     negative');
            require(items[i].fixedPoint == fixedPoint, 'conversion mismatch!');
        }

    }
}
