tests: build
	bin/test.sh

build:
	bin/build.sh

# build_force:
# 	bin/build.sh --force

dependencies:
	# foundry
	curl -L https://foundry.paradigm.xyz | bash
	# jq
	sudo apt install jq
