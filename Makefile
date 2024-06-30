# TEST_ARGS=-vvvv
TEST_ARGS=-v --gas-report

tests: build
	forge test $(TEST_ARGS) --fork-url arbitrum_test #"$@"

build:
	bin/build

dependencies:
	# foundry
	curl -L https://foundry.paradigm.xyz | bash
	# jq
	sudo apt install jq

one:
	# forge test $(TEST_ARGS) --fork-url arbitrum_test --mt testCancelOrder
	# forge test $(TEST_ARGS) --fork-url arbitrum_test --mt testProxy
	# forge test $(TEST_ARGS) --fork-url arbitrum_test --mt testDeterministicAddress
	# forge test $(TEST_ARGS) --fork-url arbitrum_test --mt testPlaceOrder
	# forge test -vvv --fork-url arbitrum_test --mt testWithdrawERC20
	# forge test -vvv --fork-url arbitrum_test --mt testReentrancyGuard
	forge test -vv --fork-url arbitrum_test --mt testFees
