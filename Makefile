DOCKER_COMPOSE = docker-compose
S2I = s2i

all: test test-nginx test-docker

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
	$(S2I) build . openresty-builder docker-gateway-test

bash:
	$(DOCKER_COMPOSE) run --user=root --rm --entrypoint=bash gateway -i

test-docker: build
	$(DOCKER_COMPOSE) down --volumes --remove-orphans
	$(DOCKER_COMPOSE) run --rm gateway openresty -p . -c nginx.conf -t
	$(DOCKER_COMPOSE) run --rm test curl -v http://gateway:8090/status/live
