# Example run command:
# make LABKEY_VERSION=24.3.4-6 DEBUG=1 NEW_DOWNLOAD=0 LABKEY_BUILD_DATE=$(date "+%Y-%m-%d-%H-%M") all

SHELL := /usr/bin/env bash
PLATFORM := $(shell uname -o)

ifeq ($(PLATFORM),Darwin)
_G := g
else
_G :=
endif

DEBUG ?=
NEW_DOWNLOAD ?= 0

FROM_TAG ?= 17-jre

CACHE_FLAG ?= --no-cache

TAG_LATEST ?=
PUSH_LATEST ?=
IDENT ?= labkey

PULL_TAG ?= latest

LABKEY_VERSION ?= 24.3.4-6
LABKEY_BUILD_DATE ?= 
LABKEY_DISTRIBUTION ?= community
LABKEY_EK ?= 123abc456

# repo/image:tags must be lowercase
BUILD_VERSION ?= $(shell echo '$(LABKEY_VERSION)' | tr A-Z a-z)
BUILD_DISTRIBUTION := $(shell echo '$(LABKEY_DISTRIBUTION)' | tr A-Z a-z)

BUILD_REPO_URI ?= registry.nersc.gov
BUILD_REPO_NAME := m2650/lims/labkey/$(BUILD_DISTRIBUTION)
BUILD_REMOTE_REPO := $(BUILD_REPO_URI)/$(BUILD_REPO_NAME)

BUILD_LOCAL_TAG ?= $(BUILD_REPO_NAME):$(BUILD_VERSION)_$(LABKEY_BUILD_DATE)
BUILD_REMOTE_TAG ?= $(BUILD_REMOTE_REPO):$(BUILD_VERSION)_$(LABKEY_BUILD_DATE)

# ifeq (1,$(DEBUG))
#   BUILD_LOCAL_TAG := $(addsuffix -debug,$(BUILD_LOCAL_TAG))
#   BUILD_REMOTE_TAG ?= $(addsuffix -debug,$(BUILD_REMOTE_TAG))
# endif

define tc
$(shell printf "%steamcity[progressMessage '%s%n']" '##' '$1' ; )
endef

ifeq (1,$(NEW_DOWNLOAD))
$(shell ./scripts/download_lims_distribution.sh $(LABKEY_VERSION) ./labkey/)
endif

.PHONY: all build tag login push up up-build down clean

.EXPORT_ALL_VARIABLES:

# default actions are: login, build, tag, then push
all: login build tag push

login:
	$(call tc,logging in to NERSC)
	docker login $(BUILD_REPO_URI)


ifeq ($(PLATFORM),Darwin)
build:
	$(call tc,building docker container)
	docker buildx build \
		--platform linux/amd64 \
		--load \
		--rm \
		--compress \
		$(CACHE_FLAG) \
		-t $(BUILD_REPO_NAME):latest \
		-t $(BUILD_LOCAL_TAG) \
		--build-arg 'FROM_TAG=$(FROM_TAG)' \
		--build-arg 'DEBUG=$(DEBUG)' \
		--build-arg 'LABKEY_VERSION=$(LABKEY_VERSION)' \
		--build-arg 'LABKEY_DISTRIBUTION=$(BUILD_DISTRIBUTION)' \
		--build-arg 'LABKEY_EK=$(LABKEY_EK)' \
		.
else
build:
	$(call tc,building docker container)
	docker build \
		--load \
		--rm \
		--compress \
		$(CACHE_FLAG) \
		-t $(BUILD_REPO_NAME):latest \
		-t $(BUILD_LOCAL_TAG) \
		--build-arg 'FROM_TAG=$(FROM_TAG)' \
		--build-arg 'DEBUG=$(DEBUG)' \
		--build-arg 'LABKEY_VERSION=$(LABKEY_VERSION)' \
		--build-arg 'LABKEY_DISTRIBUTION=$(BUILD_DISTRIBUTION)' \
		--build-arg 'LABKEY_EK=$(LABKEY_EK)' \
		.
endif

tag:
	$(call tc,tagging docker container)
	docker tag \
		$(BUILD_LOCAL_TAG) \
		$(BUILD_REMOTE_TAG);

	if [ -n "$(TAG_LATEST)" ]; then \
		docker tag \
			$(BUILD_REPO_NAME):latest \
			$(BUILD_REMOTE_REPO):latest; \
	fi

push:
	$(call tc,pushing $(BUILD_REMOTE_TAG) docker container)
	docker push $(BUILD_REMOTE_TAG);

	if [ -n "$(PUSH_LATEST)" ]; then \
		docker push $(BUILD_REMOTE_REPO):latest; \
	fi

up:
	$(call tc,bringing up compose)
	docker-compose up --abort-on-container-exit ${BUILD_DISTRIBUTION} \
			|| docker-compose stop ${BUILD_DISTRIBUTION} pg-${BUILD_DISTRIBUTION}

up-allpg:
	$(call tc,bringing up compose)
	docker-compose up --abort-on-container-exit allpg \
			|| docker-compose stop allpg pg-allpg

up-enterprise:
	$(call tc,bringing up compose)
	docker-compose up --abort-on-container-exit enterprise \
			|| docker-compose stop enterprise pg-enterprise

up-lims_starter:
	$(call tc,bringing up compose)
	docker-compose up --abort-on-container-exit lims_starter \
			|| docker-compose stop lims_starter pg-lims_starter

down:
	$(call tc,tearing down compose)
	docker-compose down -v --remove-orphans

clean:
	docker images | grep -E '$(BUILD_REPO_NAME)|<none>' \
		| awk '{print $$3}' | sort -u | $(_G)xargs -r docker image rm -f \
			&& $(_G)find mounts/logs/ -name '*.log' -type f -print0 \
				| $(_G)xargs -r -0 -t truncate -s0;

test: down
	$(call tc,running smoke tests)
	IDENT=${BUILD_DISTRIBUTION} docker-compose up --detach ${BUILD_DISTRIBUTION};
	@./smoke.bash \
		&& printf "##teamcity[progressMessage '%s']\n" 'smoke test succeeded' \
		|| printf "##teamcity[buildProblem description='%s' identity='%s']\n" \
			'smoke test failed' \
			'failure'
	IDENT=${BUILD_DISTRIBUTION} docker-compose down -v

pull: login
	docker pull $(BUILD_REMOTE_REPO):$(PULL_TAG)