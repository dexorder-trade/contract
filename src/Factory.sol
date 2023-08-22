// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "v3-core/contracts/UniswapV3Factory.sol";
import "./VaultDeployer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
pragma abicoder v2;

contract Factory is VaultDeployer, Ownable {

}
