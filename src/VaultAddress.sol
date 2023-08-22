// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import "./Constants.sol";


library VaultAddress {
    // keccak-256 hash of the Vault's bytecode (not the deployed bytecode but the initialization bytecode)
    // can paste into:
    // https://emn178.github.io/online-tools/keccak_256.html
    bytes32 internal constant VAULT_INIT_CODE_HASH = 0xbf043f7035d5aa3be2b3c94df5b256fbe24675689327af4ab71c48194c463031;

    // the contract being constructed must not have any constructor arguments or the determinism will be broken.  instead, use a callback to
    // get construction arguments
    // Uniswap example
    // https://github.com/Uniswap/v3-periphery/blob/6cce88e63e176af1ddb6cc56e029110289622317/contracts/libraries/PoolAddress.sol#L33C5-L47C6
    function computeAddress(address factory, address owner) internal pure returns (address vault) {
        vault = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex'ff',
                        factory,
                        keccak256(abi.encode(owner)),
                        VAULT_INIT_CODE_HASH
                    )
                )
            )
        );
    }
}
