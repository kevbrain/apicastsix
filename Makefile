DOCKER_COMPOSE = docker-compose
S2I = s2i

IMAGE_NAME ?= docker-gateway-test

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
	$(S2I) build . quay.io/3scale/s2i-openresty-centos7 $(IMAGE_NAME) --pull-policy=always --copy

bash:
	$(DOCKER_COMPOSE) run --user=root --rm --entrypoint=bash gateway -i

test-docker: IMAGE_NAME = docker-gateway-test
test-docker: build
	$(DOCKER_COMPOSE) down --volumes --remove-orphans
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway openresty -p . -t
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway openresty -p .
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway /opt/app/entrypoint.sh
	$(DOCKER_COMPOSE) run --rm test /opt/app/entrypoint.sh | grep 'error: no working DNS server'
	$(DOCKER_COMPOSE) run --rm test curl --fail http://gateway:8090/status/live
	$(DOCKER_COMPOSE) run --rm test curl --fail -X PUT http://gateway:8090/config --data '{"services":[{"id":42}]}'
	$(DOCKER_COMPOSE) run --rm test curl --fail http://gateway:8090/status/ready
	$(DOCKER_COMPOSE) run --rm test curl --fail -X POST http://gateway:8090/boot
