all: test

test: dependencies
	@bin/busted
	@- luacov
	@carton exec prove

# TODO: implement check to verify carton is there
carton:

test-nginx: carton
	carton exec prove

dependencies:
	luarocks make --local
