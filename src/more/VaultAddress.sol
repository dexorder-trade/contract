
pragma solidity 0.8.26;

import "@forge-std/console2.sol";


library VaultAddress {
    // keccak-256 hash of the Vault's bytecode (not the deployed bytecode but the initialization bytecode)
    bytes32 public constant VAULT_INIT_CODE_HASH = 0x8b1347850b0b1f2e05548c065af07c78f2c0617f70a2915b3cb7e0ba1bd20630;

    // the contract being constructed must not have any constructor arguments or the determinism will be broken.
    // instead, use a callback to get construction arguments
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