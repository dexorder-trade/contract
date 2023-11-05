// SPDX-License-Identifier: UNLICENSED
//pragma solidity =0.7.6;
pragma solidity >=0.8.0;
pragma abicoder v2;

import "./Constants.sol";
import "forge-std/console2.sol";


library VaultAddress {
    // keccak-256 hash of the Vault's bytecode (not the deployed bytecode but the initialization bytecode)
    // can paste into:
    // https://emn178.github.io/online-tools/keccak_256.html
    bytes32 public constant VAULT_INIT_CODE_HASH = 0x2d636e2b474d9ffd48b3a184f529f2216824023721f63454590c8cb5d4412e93;

    // the contract being constructed must not have any constructor arguments or the determinism will be broken.  instead, use a callback to
    // get construction arguments
    // Uniswap example
    // https://github.com/Uniswap/v3-periphery/blob/6cce88e63e176af1ddb6cc56e029110289622317/contracts/libraries/PoolAddress.sol#L33C5-L47C6
    function computeAddress(address factory, address owner) internal pure returns (address vault) {
        return computeAddress(factory, owner, 0);
    }

    function computeAddress(address factory, address owner, uint8 num) internal pure returns (address vault) {
        bytes32 salt = keccak256(abi.encodePacked(owner,num));
        vault = address(uint160(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex'ff',
                        factory,
                        salt,
                        VAULT_INIT_CODE_HASH
                    )
                )
            )
        ));
    }
}