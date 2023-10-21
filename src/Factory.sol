// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "./VaultDeployer.sol";
pragma abicoder v2;


contract Factory is VaultDeployer {
    address public admin;


    constructor() {
        admin = msg.sender;
    }
}
