all: test test-nginx

test: dependencies
	@bin/busted
	@- luacov

# TODO: implement check to verify carton is there
carton:
	@carton install > /dev/null

test-nginx: carton
	@carton exec prove

dependencies:
	luarocks make --local
