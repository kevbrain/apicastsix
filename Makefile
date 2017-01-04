.DEFAULT_GOAL := help

DOCKER_COMPOSE = docker-compose
S2I = s2i
REGISTRY ?= quay.io/3scale
export TEST_NGINX_BINARY ?= openresty
NGINX = $(shell which $(TEST_NGINX_BINARY))
SHELL=/bin/bash -o pipefail
SEPARATOR="\n=============================================\n"

IMAGE_NAME ?= apicast-test
BUILDER_IMAGE ?= quay.io/3scale/s2i-openresty-centos7
RUNTIME_IMAGE ?= $(BUILDER_IMAGE)-runtime

lua_files = $(shell find apicast/src -type f -name '*.lua')
spec_files = $(shell find spec -type f -name '*.lua')

test: ## Run all tests
	$(MAKE) --keep-going busted prove test-builder-image prove-docker test-runtime-image

busted: dependencies ## Test Lua.
	@bin/busted
	@- luacov

check: dependencies ## Run luacheck to lint lua files
	luacheck $(lua_files) $(spec_files)

nginx:
	@ ($(NGINX) -V 2>&1 | grep -e '--with-ipv6' > /dev/null) || (>&2 echo "$(NGINX) `$(NGINX) -v 2>&1` does not have ipv6 support" && exit 1)

# TODO: implement check to verify carton is there
carton:
	@carton install > /dev/null

prove: carton nginx ## Test nginx
	@carton exec prove 2>&1 | awk '/found ONLY/ { print "FAIL: because found ONLY in test"; print; exit 1 }; { print }'

prove-docker: export IMAGE_NAME = apicast-test
prove-docker: ## Test nginx inside docker
	$(DOCKER_COMPOSE) run --rm prove

builder-image: ## Build builder image
	$(S2I) build . $(BUILDER_IMAGE) $(IMAGE_NAME) --context-dir=apicast --copy --incremental

runtime-image: PULL_POLICY ?= always
runtime-image: ## Build runtime image
	$(S2I) build . $(BUILDER_IMAGE) $(IMAGE_NAME) --context-dir=apicast --runtime-image=$(RUNTIME_IMAGE) --pull-policy=$(PULL_POLICY)

push: ## Push image to the registry
	docker tag $(IMAGE_NAME) $(REGISTRY)/$(IMAGE_NAME)
	docker push $(REGISTRY)/$(IMAGE_NAME)

bash: export IMAGE_NAME = apicast-test
bash: export SERVICE = gateway
bash: ## Run bash inside the builder image
	$(DOCKER_COMPOSE) run --user=root --rm --entrypoint=bash $(SERVICE) -i

test-builder-image: export IMAGE_NAME = apicast-test
test-builder-image: builder-image clean ## Smoke test the builder image. Pass any docker image in IMAGE_NAME parameter.
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway openresty -p . -t
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway openresty -p .
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway bin/entrypoint -d
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm test bash -c '(bin/entrypoint -d 2>&1 || :) | grep "error: no working DNS server found"'
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm test curl --fail http://gateway:8090/status/live
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm test curl --fail -X PUT http://gateway:8090/config --data '{"services":[{"id":42}]}'
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm test curl --fail http://gateway:8090/status/ready
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm test curl --fail -X POST http://gateway:8090/boot
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm -e THREESCALE_PORTAL_ENDPOINT=https://echo-api.3scale.net gateway /opt/app/libexec/boot | grep lua-resty-http
	@echo -e $(SEPARATOR)

test-runtime-image: export IMAGE_NAME = apicast-release-test
test-runtime-image: runtime-image clean ## Smoke test the runtime image. Pass any docker image in IMAGE_NAME parameter.
	$(DOCKER_COMPOSE) run --rm --user 100001 gateway apicast -d
	@echo -e $(SEPARATOR)
	$(DOCKER_COMPOSE) run --rm test sh -c 'sleep 5 && curl --fail http://gateway:8090/status/live'


dependencies:
	luarocks make apicast/*.rockspec
	luarocks make rockspec

clean: ## Remove all running docker containers
	$(DOCKER_COMPOSE) down --volumes --remove-orphans

# Check http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
