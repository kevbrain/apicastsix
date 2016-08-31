all: test

test: dependencies
	@bin/busted
	@- luacov

# TODO: implement check to verify carton is there
carton:

test-nginx: carton
	@carton exec prove

dependencies:
	luarocks make --local
