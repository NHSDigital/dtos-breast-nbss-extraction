.DEFAULT_GOAL := help
.PHONY: help workflow config dependencies githooks-config githooks-run
.SILENT: help workflow
.NOTPARALLEL: # this is because make -j could cause race conditions

ifeq (,$(filter oneshell,$(.FEATURES)))
$(error .ONESHELL not supported (GNU Make 3.82+ required, found $(MAKE_VERSION)))
endif

include scripts/make/shared.mk
include scripts/make/environment.mk
include scripts/make/bootstrap.mk
include scripts/make/azure.mk
include scripts/make/terraform.mk

# ---------------------------------------------------------------------------
# Help & Meta
# ---------------------------------------------------------------------------
help: # Print help @Others
	printf "\nUsage: \033[3m\033[93m[arg1=val1] [arg2=val2] \033[0m\033[0m\033[32mmake\033[0m\033[34m <command>\033[0m\n\n"
	perl -e '$(HELP_SCRIPT)' $(MAKEFILE_LIST)

# ---------------------------------------------------------------------------
# Bootstrap & Environment
# ---------------------------------------------------------------------------
# Configure development environment (main) @Configuration
config:
	_install-tools
	_install-uv
	githooks-config
	dependencies

dependencies: # Install dependencies needed to build and test the project @Pipeline
	@if [ -f nbss/pyproject.toml ]; then \
		uv sync --no-build --directory nbss; \
	else \
		echo "Skipping uv sync: nbss/pyproject.toml not found"; \
	fi
	@if [ -f package.json ]; then \
		npm install; \
	else \
		echo "Skipping npm install: package.json not found"; \
	fi

githooks-config:
	if ! command -v pre-commit >/dev/null 2>&1; then \
		pip install pre-commit; \
	fi
	pre-commit install

githooks-run: # Run git hooks configured in this repository @Operations
	pre-commit run \
		--config scripts/config/pre-commit.yaml \
		--all-files

