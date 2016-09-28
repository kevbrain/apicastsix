.DEFAULT_GOAL := help

DOCKER_COMPOSE = docker-compose
S2I = s2i
REGISTRY ?= quay.io/3scale
TEST_NGINX_BINARY ?= nginx
NGINX = $(shell which $(TEST_NGINX_BINARY))
SHELL=/bin/bash -o pipefail

IMAGE_NAME ?= docker-gateway-test

test: ## Run all tests
	$(MAKE) --keep-going busted prove test-docker prove-docker

busted: dependencies ## Test Lua.
	@bin/busted
	@- luacov

nginx:
	@ ($(NGINX) -V 2>&1 | grep -e '--with-ipv6' > /dev/null) || (>&2 echo "$(NGINX) `$(NGINX) -v 2>&1` does not have ipv6 support" && exit 1)

# TODO: implement check to verify carton is there
carton:
	@carton install > /dev/null

prove: carton nginx ## Test nginx
	@carton exec prove 2>&1 | awk '/found ONLY/ { print "FAIL: because found ONLY in test"; print; exit 1 }; { print }'

prove-docker: IMAGE_NAME = docker-gateway-test
prove-docker: ## Test nginx inside docker
	$(DOCKER_COMPOSE) run --rm prove

build: ## Build image for development
	$(S2I) build . quay.io/3scale/s2i-openresty-centos7 $(IMAGE_NAME) --context-dir=apicast --copy --incremental

release: ## Build image for release
	$(S2I) build . quay.io/3scale/s2i-openresty-centos7 $(IMAGE_NAME) --context-dir=apicast --pull-policy=always

push: ## Push image to the registry
	docker tag $(IMAGE_NAME) $(REGISTRY)/$(IMAGE_NAME)
	docker push $(REGISTRY)/$(IMAGE_NAME)

bash: ## Run bash inside the build image
	$(DOCKER_COMPOSE) run --user=root --rm --entrypoint=bash gateway -i

test-docker: IMAGE_NAME = docker-gateway-test
test-docker: build ## Test build docker
	$(DOCKER_COMPOSE) down --volumes --remove-orphans
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway openresty -p . -t
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway openresty -p .
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway /opt/app/entrypoint.sh
	$(DOCKER_COMPOSE) run --rm test /opt/app/entrypoint.sh | grep 'error: no working DNS server'
	$(DOCKER_COMPOSE) run --rm test curl --fail http://gateway:8090/status/live
	$(DOCKER_COMPOSE) run --rm test curl --fail -X PUT http://gateway:8090/config --data '{"services":[{"id":42}]}'
	$(DOCKER_COMPOSE) run --rm test curl --fail http://gateway:8090/status/ready
	$(DOCKER_COMPOSE) run --rm test curl --fail -X POST http://gateway:8090/boot
	$(DOCKER_COMPOSE) run --rm -e THREESCALE_PORTAL_ENDPOINT=https://echo-api.3scale.net gateway /opt/app/libexec/boot | grep lua-resty-http

dependencies:
	luarocks make --local apicast/*.rockspec
	luarocks make --local rockspec

# Check http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
