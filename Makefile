DOCKER_COMPOSE = docker-compose

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
	luarocks make --local *.rockspec
	luarocks make --local rockspec

build:
	$(DOCKER_COMPOSE) build

bash:
	$(DOCKER_COMPOSE) run --user=root --rm --entrypoint=bash gateway -i

test-docker: build
	$(DOCKER_COMPOSE) run --rm gateway -t
