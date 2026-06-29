SHELL := /bin/bash

PYTHON ?= python3.11
VENV ?= .venv
PIP := $(VENV)/bin/pip
PY := $(VENV)/bin/python
TOOLS_DIR ?= .tools
NODE_VERSION ?= 24.13.0
NODE_OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
NODE_CPU := $(shell uname -m | sed -e 's/^aarch64$$/arm64/' -e 's/^x86_64$$/x64/' -e 's/^amd64$$/x64/')
NODE_DIST := node-v$(NODE_VERSION)-$(NODE_OS)-$(NODE_CPU)
NODE_URL := https://nodejs.org/dist/v$(NODE_VERSION)/$(NODE_DIST).tar.xz
NODE_HOME := $(TOOLS_DIR)/node
NODE_BIN := $(NODE_HOME)/bin
NODE := $(NODE_BIN)/node
NPM := $(NODE_BIN)/npm
LOCAL_CDK := ./node_modules/.bin/cdk
CDK ?= $(LOCAL_CDK)
JSII_CACHE_ROOT ?= $(CURDIR)/.jsii-cache
PYTHON_CACHE_ROOT ?= $(CURDIR)/.pycache
PIP_CACHE_ROOT ?= $(CURDIR)/.pip-cache
PIP_INSTALL_FLAGS ?= --no-build-isolation
PATH_ENV := PATH=$(CURDIR)/$(NODE_BIN):$$PATH

AWS_PROFILE ?=
AWS_REGION ?=
AWS_DEFAULT_REGION ?= $(AWS_REGION)
AWS_SDK_LOAD_CONFIG ?= 1
CONTEXT ?=
STACK ?=

-include .env

AWS_DEFAULT_REGION ?= $(AWS_REGION)
AWS_SDK_LOAD_CONFIG ?= 1

AWS_ENV :=
ifneq ($(AWS_SDK_LOAD_CONFIG),)
AWS_ENV += AWS_SDK_LOAD_CONFIG=$(AWS_SDK_LOAD_CONFIG)
endif
ifneq ($(AWS_PROFILE),)
AWS_ENV += AWS_PROFILE=$(AWS_PROFILE)
endif
ifneq ($(AWS_REGION),)
AWS_ENV += AWS_REGION=$(AWS_REGION)
endif
ifneq ($(AWS_DEFAULT_REGION),)
AWS_ENV += AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION)
endif
LOCAL_ENV := JSII_RUNTIME_PACKAGE_CACHE_ROOT=$(JSII_CACHE_ROOT) PYTHONPYCACHEPREFIX=$(PYTHON_CACHE_ROOT)
PIP_ENV := PIP_CACHE_DIR=$(PIP_CACHE_ROOT) PIP_DISABLE_PIP_VERSION_CHECK=1

CDK_CONTEXT := $(CONTEXT)
ifneq ($(AWS_PROFILE),)
CDK_CONTEXT += --profile $(AWS_PROFILE)
endif
ifneq ($(AWS_REGION),)
CDK_CONTEXT += --region $(AWS_REGION)
endif

.PHONY: help setup check-python check-venv-python ensure-node tools install-python install-node lint test synth diff deploy bootstrap destroy clean

help:
	@printf "Targets:\n"
	@printf "  setup       Create the virtualenv and install Python/CDK CLI dependencies\n"
	@printf "  tools       Print required tool versions\n"
	@printf "  lint        Run ruff checks\n"
	@printf "  test        Run pytest\n"
	@printf "  synth       Synthesize the CDK app\n"
	@printf "  diff        Show a CDK diff against the configured AWS account\n"
	@printf "  deploy      Deploy the stack to the configured AWS account\n"
	@printf "  bootstrap   Bootstrap the configured AWS account/region for CDK\n"
	@printf "  destroy     Destroy the deployed stack\n"
	@printf "\nVariables:\n"
	@printf "  AWS_PROFILE=my-profile AWS_REGION=us-east-1 CONTEXT='-c environment=dev'\n"

setup: install-python install-node tools

check-python:
	@$(PYTHON) -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else "Python 3.11+ is required. Set PYTHON=/path/to/python3.11")'

$(VENV): check-python
	$(PYTHON) -m venv $(VENV)

check-venv-python: $(VENV)
	@$(PY) -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else ".venv must use Python 3.11+. Delete .venv or set VENV=/path/to/venv")'

install-python: check-python $(VENV) check-venv-python
	$(PY) -m ensurepip --upgrade
	$(PIP_ENV) $(PIP) install $(PIP_INSTALL_FLAGS) -e ".[dev]"

$(NODE):
	@if [ "$(NODE_OS)" != "darwin" ] && [ "$(NODE_OS)" != "linux" ]; then \
		printf "Unsupported OS for local Node bootstrap: %s\n" "$$(uname -s)"; \
		exit 1; \
	fi
	@if [ "$(NODE_CPU)" != "arm64" ] && [ "$(NODE_CPU)" != "x64" ]; then \
		printf "Unsupported platform for local Node bootstrap: %s/%s\n" "$$(uname -s)" "$$(uname -m)"; \
		exit 1; \
	fi
	@if ! command -v curl >/dev/null 2>&1; then \
		printf "curl is required to download Node.js. Install curl, then rerun make setup.\n"; \
		exit 1; \
	fi
	@set -e; \
	tmp_dir="$$(mktemp -d)"; \
	printf "Downloading Node.js %s for %s-%s...\n" "$(NODE_VERSION)" "$(NODE_OS)" "$(NODE_CPU)"; \
	curl -fsSL "$(NODE_URL)" -o "$$tmp_dir/node.tar.xz"; \
	tar -xJf "$$tmp_dir/node.tar.xz" -C "$$tmp_dir"; \
	rm -rf "$(NODE_HOME)"; \
	mkdir -p "$(TOOLS_DIR)"; \
	mv "$$tmp_dir/$(NODE_DIST)" "$(NODE_HOME)"; \
	rm -rf "$$tmp_dir"

ensure-node: $(NODE)

install-node: ensure-node
	@if [ -f package-lock.json ]; then \
		$(PATH_ENV) $(NPM) ci; \
	else \
		$(PATH_ENV) $(NPM) install; \
	fi

tools:
	$(PYTHON) --version
	$(PY) --version
	$(NODE) --version
	$(PATH_ENV) $(NPM) --version
	$(PATH_ENV) $(CDK) --version
	@command -v aws >/dev/null 2>&1 && aws --version || printf "aws: not found; install/configure AWS CLI or credentials before diff/deploy\n"
	@printf "AWS_PROFILE=%s\n" "$(if $(AWS_PROFILE),$(AWS_PROFILE),<default>)"
	@printf "AWS_REGION=%s\n" "$(if $(AWS_REGION),$(AWS_REGION),<unset>)"
	@printf "AWS_SDK_LOAD_CONFIG=%s\n" "$(AWS_SDK_LOAD_CONFIG)"
	@if command -v aws >/dev/null 2>&1; then \
		$(AWS_ENV) aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table 2>/dev/null || \
		printf "aws: not logged in for this profile. Run: aws sso login --profile %s\n" "$(if $(AWS_PROFILE),$(AWS_PROFILE),default)"; \
	fi

lint:
	$(LOCAL_ENV) $(PY) -m ruff check .

test:
	$(LOCAL_ENV) $(PY) -m pytest

synth:
	$(PATH_ENV) $(LOCAL_ENV) $(CDK) synth $(STACK) $(CDK_CONTEXT)

diff:
	$(PATH_ENV) $(LOCAL_ENV) $(AWS_ENV) $(CDK) diff $(STACK) $(CDK_CONTEXT)

deploy:
	$(PATH_ENV) $(LOCAL_ENV) $(AWS_ENV) $(CDK) deploy $(STACK) $(CDK_CONTEXT) --require-approval never

bootstrap:
	$(PATH_ENV) $(LOCAL_ENV) $(AWS_ENV) $(CDK) bootstrap $(CDK_CONTEXT)

destroy:
	$(PATH_ENV) $(LOCAL_ENV) $(AWS_ENV) $(CDK) destroy $(STACK) $(CDK_CONTEXT)

clean:
	rm -rf cdk.out .pytest_cache .ruff_cache .jsii-cache .pycache .pip-cache .tools *.egg-info
