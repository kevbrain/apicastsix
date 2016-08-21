all: test

test: dependencies
	@bin/busted

dependencies:
	luarocks make --local
