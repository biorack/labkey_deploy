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

IDENT ?= labkey
PULL_TAG ?= latest

LABKEY_VERSION ?= 
LABKEY_BUILD_DATE ?= 
LABKEY_DISTRIBUTION ?= community
LABKEY_EK ?= 123abc456

# Exit if LABKEY_VERSION is empty
ifeq ($(strip $(LABKEY_VERSION)),)
$(error LABKEY_VERSION is not set. Exiting.)
endif

# repo/image:tags must be lowercase
BUILD_VERSION ?= $(shell echo '$(LABKEY_VERSION)' | tr A-Z a-z)
BUILD_DISTRIBUTION := $(shell echo '$(LABKEY_DISTRIBUTION)' | tr A-Z a-z)

BUILD_REPO_URI ?= registry.nersc.gov
BUILD_REPO_NAME := m2650/lims/labkey/$(BUILD_DISTRIBUTION)
BUILD_REMOTE_REPO := $(BUILD_REPO_URI)/$(BUILD_REPO_NAME)

BUILD_LOCAL_TAG ?= $(BUILD_REPO_NAME):labkey$(BUILD_VERSION)_$(LABKEY_BUILD_DATE)
BUILD_REMOTE_TAG ?= $(BUILD_REMOTE_REPO):labkey$(BUILD_VERSION)_$(LABKEY_BUILD_DATE)

define tc
$(shell printf "%steamcity[progressMessage '%s%n']" '##' '$1' ; )
endef

ifeq (1,$(NEW_DOWNLOAD))
$(info Downloading LabKey distribution tar.gz file...)
$(shell ./scripts/download_lims_distribution.sh $(LABKEY_VERSION) .)
endif

.PHONY: all build tag login push

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

push:
	$(call tc,pushing $(BUILD_REMOTE_TAG) docker container)
	docker push $(BUILD_REMOTE_TAG);
