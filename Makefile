TEMPDIR = ./.tmp
ARTIFACTROY = scribe-generic-public-local
REGISTRY = scribesecuriy.jfrog.io/scribe-docker-public-local
BUNDLE_PREFIX = bundle
LINE = DESTINATION_PATHS=".tmp/ /usr/local/bin /usr/bin /opt/bin;PATH=.tmp;$$PATH"

BOLD := $(shell tput -T linux bold)
PURPLE := $(shell tput -T linux setaf 5)
GREEN := $(shell tput -T linux setaf 2)
CYAN := $(shell tput -T linux setaf 6)
RED := $(shell tput -T linux setaf 1)
RESET := $(shell tput -T linux sgr0)
TITLE := $(BOLD)$(PURPLE)
SUCCESS := $(BOLD)$(GREEN)

## Build variables
DISTDIR=./dist
SNAPSHOTDIR=./snapshot
LICENSESDIR=licenses

define title
    @printf '$(TITLE)$(1)$(RESET)\n'
endef

GITTREESTATE=$(if $(shell git status --porcelain),dirty,clean)
OS := $(shell uname)
PKG_VERSION:=$(shell git describe --tags --always | tr -d v)
BUNDLE=$(DISTDIR)/bundle_$(PKG_VERSION).tar.gz
PROJECT_NAME:=$(shell basename `git rev-parse --show-toplevel | tr A-Z a-z`  )

## Tasks
.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(BOLD)$(CYAN)%-25s$(RESET)%s\n", $$1, $$2}'

$(TEMPDIR):
	mkdir -p $(TEMPDIR)

$(DISTDIR):
	mkdir -p $(DISTDIR)

# ./build/install.sh -T opa -d
# @curl -L -o $(TEMPDIR)/opa https://github.com/open-policy-agent/opa/releases/download/v0.11.0/opa_linux_amd64

.PHONY: bootstrap-tools
bootstrap-tools: $(TEMPDIR)
	$(call title,Bootstrapping tools)
	@cat ./build/install_opa.sh | sh
	@cat ./build/install_jfrog.sh | sh

.PHONY: bootstrap
bootstrap: $(RESULTSDIR) bootstrap-tools ## Download and install all build dependencies (+ prep tooling in the ./tmp dir)
	$(call title,Bootstrapping dependencies)

.PHONY: build_bundle
build_bundle: $(DISTDIR)
	$(call title,Building bundle artifact)
	$(TEMPDIR)/opa build ./modules --debug -o $(DISTDIR)/bundle_$(PKG_VERSION).tar.gz
	set -x
	env
	if [ -n "${GITHUB_OUTPUT}" ]; then echo "BUNDLE=${BUNDLE}" >> "${GITHUB_OUTPUT}"; fi

bundle_path:
	@echo ${BUNDLE}

.PHONY: build_image
build_image: $(DISTDIR)
	$(call title,Building image artifact)
	docker build . --no-cache -t $(REGISTRY)/$(PROJECT_NAME):$(PKG_VERSION) -t $(REGISTRY)/$(PROJECT_NAME):latest

.PHONY: build
build: $(DISTDIR) build_image build_bundle ## Build policy bundle,image
	$(call title,Building successful)

.PHONY: run
test_run: build_bundle ## Build policy bundle,image
	$(call title,Running successful)
	bash test/run.sh

.PHONY: test
test: ## Test policy
	$(call title,Testing Policies)
	$(TEMPDIR)/opa test ./modules -v

release_images:
	$(call title,Release image $(REGISTRY))
	@docker push $(REGISTRY)/$(PROJECT_NAME):$(PKG_VERSION)
	@docker push $(REGISTRY)/$(PROJECT_NAME):latest

# release_artifactory: 
# 	$(call title,Release bundle to $(ARTIFACTROY))
# 	$(TEMPDIR)/jf rt upload --exclusions "dist/$(BUNDLE_PREFIX)_*.*.*-*.tar.gz" --flat "dist/$(BUNDLE_PREFIX)_*.*.*.tar.gz"  $(ARTIFACTROY)/$(PROJECT_NAME)/$(BUNDLE_PREFIX)/

.PHONY: release
release: $(DISTDIR) build release_images ## Release policy bundle,image
	$(call title,Release successful)

.PHONY: clean
clean: ## Remove previous builds
	rm -rf $(DISTDIR)

.PHONY: clean-bootstrap
clean-bootstrap:
	rm -rf $(TEMPDIR)