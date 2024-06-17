// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IVaultLogic} from "./IVault.sol";

pragma abicoder v2;

interface IVaultFactory {

    // Only vault number 0 is currently supported by the backend.
    function deployVault() external returns (address payable vault);
    function deployVault(uint8 num) external returns (address payable vault);
    function deployVault(address owner) external returns (address payable vault);
    function deployVault(address owner, uint8 num) external returns (address payable vault);

    function logic() external view returns (address);  // current implementation of the vault methods
    function upgrader() external view returns (address);
    function proposedLogicActivationTimestamp() external view returns (uint32);
    function proposedLogic() external view returns (address);
    function upgradeLogic( address newLogic ) external;  // used by the admin to propose an upgrade

    // used by the vault constructor to get arguments
    function parameters() external view returns (address owner, uint8 num, address vaultLogic);

}
