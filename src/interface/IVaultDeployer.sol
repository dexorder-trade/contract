// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
pragma abicoder v2;

interface IVaultDeployer {
    function parameters() external view returns (address owner);
}
