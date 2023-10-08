#!/usr/bin/env bash
#cd ../server
#pwd
#db-migrate down
#db-migrate up
#cd ../contract

#source ./bin/build.sh
anvil -f arbitrum_ankr --chain-id 1338 &
# todo check anvil result
ANVIL_PID=$!
sleep 2

forge script script/Deploy.sol -vvvv --fork-url http://localhost:8545 --broadcast

trap_ctrlc() {
  echo exiting anvil
  kill $ANVIL_PID
}

trap trap_ctrlc INT

# wait for all background processes to terminate
wait
