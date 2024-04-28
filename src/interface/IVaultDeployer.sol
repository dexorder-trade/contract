// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;
pragma abicoder v2;

interface IVaultDeployer {
    function parameters() external view returns (address owner, address vaultLogic, address dexorder);
}
