#!/usr/bin/env bash

# the FACTORY env var must also be defined
PRIVKEY=${PRIVATE_KEY:='0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'}
RPC=${RPC_URL:-http://localhost:8545}

forge script script/Upgrade.sol -vvvv --fork-url "$RPC" --broadcast --private-key $PRIVKEY
