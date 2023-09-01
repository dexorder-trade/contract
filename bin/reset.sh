#!/usr/bin/env bash
#cd ../server
#pwd
#db-migrate down
#db-migrate up
#cd ../contract

anvil -f arbitrum_ankr &
ANVIL_PID=$!
sleep 2
forge script script/Deploy.sol --fork-url http://localhost:8545 --broadcast

trap_ctrlc() {
  echo
  kill $ANVIL_PID
}

trap trap_ctrlc INT

# wait for all background processes to terminate
wait
