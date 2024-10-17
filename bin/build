#!/bin/bash
# this script requires the jq command $(sudo apt install jq)

# build_args=$(echo "$@" | sed 's/--debug//')
build_args=$(echo "$@")

## force full rebuild
#echo Full build, not incremental...
#rm -rf out/ broadcast/ cache/ gen/

# first-pass build
echo Building...
forge build $build_args || exit 1

# Debug print
# if echo "$@" | grep -wqe "--debug"; then
#     echo Orderlib.sol should be first, if not then build --force should be triggered
#     date
#     OrderLib_deps
# fi

# Rebuild --force if OrderLib dependencies not built due to bug in forge
# if [ "./src/OrderLib.sol" != $(OrderLib_deps | head -n 1 | colrm 1 36) ]; then
#     echo Rebuild --force because OrderLib dependencies not built due to forge bug...
#     rm -rf out
#     forge build --force "$@" || exit 1
# fi

# calculate the Vault init code hash using the bytecode generated for Vault
# shellcheck disable=SC2046
VAULT_INIT_CODE_HASH=$(cast keccak $(jq -r .bytecode.object < out/Vault.sol/Vault.json))

# put the hash value into the VaultAddress.sol source file
sed -i "s/VAULT_INIT_CODE_HASH = .*;/VAULT_INIT_CODE_HASH = $VAULT_INIT_CODE_HASH;/" src/more/VaultAddress.sol

# final build after init code hash is set
echo Build VaultAddress.sol...
forge build $build_args  || exit 1

# Debug print

# if echo "$@" | grep -wqe "--debug"; then
#     echo all compiled files:
#     dated_flist "./out/*/*.json"
#     dated_flist ./src/OrderLib.sol
# fi

echo Contracts built successfully.
