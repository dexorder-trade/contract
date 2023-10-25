tests: build_force
	bin/test.sh

build:
	bin/build.sh

build_force:
	bin/build_force.sh

dependencies:
	# foundry
	curl -L https://foundry.paradigm.xyz | bash
	# jq
	sudo apt install jq
