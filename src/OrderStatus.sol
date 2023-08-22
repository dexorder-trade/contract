// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;


enum OrderStatus {
    ACTIVE,   // the only status while the order is still executing
    CANCELED, // canceled by the owner
    FILLED,   // full trade amount was filled
    EXPIRED   // trade ended without completing its fills
}
