#!/bin/bash

RPC=${RPC_URL:-http://localhost:8545}

c() {
#  echo cast "$1" --rpc-url $RPC "${@:2}" >&2
  cast "$1" --rpc-url "$RPC" "${@:2}"
}

CHAINID=$(c chain-id)

FILE_TAG=${TAG:-mock}

if [ "$FILE_TAG" == "mock" ]; then
  BROADCAST=broadcast
  FILE_TAG=latest
else
  BROADCAST=deployment/$TAG/broadcast
fi

MOCKENV=$(jq -r '.transactions[] | select(.contractName=="MockEnv") | select(.function==null).contractAddress' "$BROADCAST/DeployMock.sol/$CHAINID/run-latest.json") || echo WARNING no MockEnv detected
export MOCKENV
MIRRORENV=$(jq -r '.transactions[] | select(.contractName=="MirrorEnv") | select(.function==null).contractAddress' "$BROADCAST/DeployMirror.sol/$CHAINID/run-latest.json") || echo WARNING no MirrorEnv detected
export MIRRORENV
FACTORY=$(jq -r '.transactions[] | select(.contractName=="Factory") | select(.function==null).contractAddress' "$BROADCAST/Deploy.sol/$CHAINID/run-latest.json") || exit 1
export FACTORY
HELPER=$(jq -r '.transactions[] | select(.contractName=="QueryHelper") | select(.function==null).contractAddress' "$BROADCAST/Deploy.sol/$CHAINID/run-latest.json") || exit 1
export HELPER

VAULT_INIT_CODE_HASH=$(cast keccak $(jq -r .bytecode.object < out/Vault.sol/Vault.json)) || exit 1
export VAULT_INIT_CODE_HASH

POOL=$(c call $MOCKENV "pool()" | cast parse-bytes32-address) || exit 1
export POOL
MEH=$(c call $MOCKENV "COIN()" | cast parse-bytes32-address) || exit 1
export MEH
USXD=$(c call $MOCKENV "USD()" | cast parse-bytes32-address) || exit 1
export USXD
MOCK=$MEH
export MOCK
USD=$USDX
export USD
TOKEN0=$(c call $MOCKENV "token0()" | cast parse-bytes32-address) || exit 1
export TOKEN0
TOKEN1=$(c call $MOCKENV "token1()" | cast parse-bytes32-address) || exit 1
export TOKEN1
T0DEC=$(c call $TOKEN0 "decimals()" | cast to-dec) || exit 1
export T0DEC
T1DEC=$(c call $TOKEN1 "decimals()" | cast to-dec) || exit 1
export T1DEC
POOLDEC=$(echo $T1DEC - $T0DEC | bc)
export POOLDEC
MEH_INT=$(cast to-dec $MEH)
USXD_INT=$(cast to-dec $USXD)
#echo $MEH_INT $USXD_INT
INVERTED=$(echo $MEH_INT '>' $USXD_INT | bc)
export INVERTED

#echo "\$MOCKENV    $MOCKENV"
#echo "\$MIRRORENV  $MIRRORENV"
#echo "\$MEH        $MEH"
#echo "\$USXD       $USXD"
#echo "\$POOL       $POOL"
