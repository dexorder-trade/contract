// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;

import "./VaultDeployer.sol";
pragma abicoder v2;


contract Factory is VaultDeployer {
    address public admin;

    constructor() {
        admin = msg.sender;
    }
}
