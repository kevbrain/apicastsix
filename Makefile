all: test

test: dependencies
	@bin/busted
	@- luacov

dependencies:
	luarocks make --local
