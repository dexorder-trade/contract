// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "./VaultDeployer.sol";
pragma abicoder v2;


contract Factory is VaultDeployer {
    address public admin;
    constructor(Dexorder _dexorder) VaultDeployer(_dexorder) {
        admin = msg.sender;
    }
}
