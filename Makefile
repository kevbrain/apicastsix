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
	$(S2I) build . quay.io/3scale/s2i-openresty-centos7 docker-gateway-test -p always -c

bash:
	$(DOCKER_COMPOSE) run --user=root --rm --entrypoint=bash gateway -i

test-docker: build
	$(DOCKER_COMPOSE) down --volumes --remove-orphans
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway openresty -p . -t
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway openresty -p .
	$(DOCKER_COMPOSE) run --rm test curl -v http://gateway:8090/status/live
