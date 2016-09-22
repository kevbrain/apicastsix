.DEFAULT_GOAL := help

DOCKER_COMPOSE = docker-compose
S2I = s2i
REGISTRY ?= quay.io/3scale

IMAGE_NAME ?= docker-gateway-test

test: busted prove test-docker prove-docker ## Run all tests

busted: dependencies ## Test Lua.
	@bin/busted
	@- luacov

# TODO: implement check to verify carton is there
carton:
	@carton install > /dev/null

prove: carton ## Test nginx
	@carton exec prove

prove-docker: IMAGE_NAME = docker-gateway-test
prove-docker: ## Test nginx inside docker
	$(DOCKER_COMPOSE) run --rm prove

build: ## Build image for development
	$(S2I) build . quay.io/3scale/s2i-openresty-centos7 $(IMAGE_NAME) --copy --incremental

release: ## Build image for release
	$(S2I) build . quay.io/3scale/s2i-openresty-centos7 $(IMAGE_NAME) --pull-policy=always

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
	luarocks make --local *.rockspec
	luarocks make --local rockspec

# Check http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
