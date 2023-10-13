#!/usr/bin/env bash
./bin/build.sh || exit 1
PRIVATE_KEY=${PRIVATE_KEY:='0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'}
forge script script/Deploy.sol -vvvv --fork-url http://localhost:8545 --broadcast
