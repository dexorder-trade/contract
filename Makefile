tests:
	bin/test.sh

build:
	bin/build.sh

dependencies:
	# foundry
	curl -L https://foundry.paradigm.xyz | bash
	# jq
	sudo apt install jq
