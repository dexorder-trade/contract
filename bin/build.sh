#!/bin/bash
# this script requires the jq command $(sudo apt install jq)

# first-pass build
cp src/VaultAddress-default.sol src/VaultAddress.sol
forge build "$@" || exit 1

# calculate the Vault init code hash using the bytecode generated for Vault
# shellcheck disable=SC2046
VAULT_INIT_CODE_HASH=$(cast keccak $(jq -r .bytecode.object < out/Vault.sol/Vault.json))

# put the hash value into the VaultAddress.sol source file
sed -i "s/VAULT_INIT_CODE_HASH = .*;/VAULT_INIT_CODE_HASH = $VAULT_INIT_CODE_HASH;/" src/VaultAddress.sol

# generate a javascript file with the constant
mkdir gen &> /dev/null
echo "export const VAULT_INIT_CODE_HASH='$VAULT_INIT_CODE_HASH';" > gen/vaultHash.js

# final build after hash values are set
forge build "$@" || exit 1
