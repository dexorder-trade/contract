#!/usr/bin/env bash
./bin/build.sh
forge script script/Deploy.sol -vvvv --fork-url http://localhost:8545 --broadcast
