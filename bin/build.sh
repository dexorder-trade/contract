#!/bin/bash
# this script requires the jq command $(sudo apt install jq)

# # Check OrderLib dependencies and rebuild them if forge fails due to bug
# # Search for files that import OrderLib -- imperfect criteria may get too many, for example comments
# ORDERLIB_DEPENDENCIES=$(grep -rl "/OrderLib.sol" | grep -E '(^test|^src)' | awk -F/ '{print $NF}')
# # ORDERLIB_DEPENDENCIES="OrderLib Dexorder QueryHelper Vault VaultLogic IVault TestOrder TestCancelOrder"
# dated_flist() {
#     find $1 -type f -print0 | xargs -0 stat -c '%y %n' | sort;
# }
# OrderLib_deps() {
#     (
#     dated_flist ./src/OrderLib.sol
#     dated_flist "./out/OrderLib.sol/*.json"
#     for item in $ORDERLIB_DEPENDENCIES; do dated_flist "./out/$item/*.json"; done
#     ) | sort
# }

# build_args=$(echo "$@" | sed 's/--debug//')
build_args=$(echo "$@")

# force full rebuild
echo Full build, not incremental...
rm -rf out/ broadcast/ cache/ gen/

# first-pass build
cp src/VaultAddress-default.sol src/VaultAddress.sol
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
sed -i "s/VAULT_INIT_CODE_HASH = .*;/VAULT_INIT_CODE_HASH = $VAULT_INIT_CODE_HASH;/" src/VaultAddress.sol

# final build after hash values are set
echo Rebuild VaultAddress.sol if needed...
forge build $build_args  || exit 1

# Debug print

# if echo "$@" | grep -wqe "--debug"; then
#     echo all compiled files:
#     dated_flist "./out/*/*.json"
#     dated_flist ./src/OrderLib.sol
# fi
