all: test

test: dependencies
	busted

dependencies:
	luarocks make --local
