#!/usr/bin/env bash

if [ "$1" == "" ]; then
  echo tag required
  echo $0 [tag]
fi

./bin/build.sh || exit 1

TAG=$1
PRIVKEY=${PRIVATE_KEY:='0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'}
RPC=${RPCURL:-http://localhost:8545}
CHAINID=$(cast chain-id --rpc-url "$RPC")

cpbroadcast() {
  CONTRACT=$1
  mkdir -p deployment/"$TAG"/broadcast/"$CONTRACT"/"$CHAINID"
  cp broadcast/"$CONTRACT"/"$CHAINID"/run-latest.json deployment/"$TAG"/broadcast/"$CONTRACT"/"$CHAINID"/run-"$TAG".json
}

PRIVATE_KEY=$PRIVKEY forge script script/Deploy.sol -vvvv --fork-url "$RPC" --broadcast
rm -rf deployment/"$TAG"
mkdir -p deployment/"$TAG"
cp -r out deployment/"$TAG"/
cpbroadcast Deploy.sol

if [ "$2" == "mock" ]; then
  PRIVATE_KEY=$PRIVKEY forge script script/DeployMock.sol -vvvv --fork-url "$RPC" --broadcast
  cpbroadcast DeployMock.sol
fi

