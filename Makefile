# Note, init.mk includes Terraform make file
include scripts/init.mk
include scripts/make/environment.mk
include scripts/make/bootstrap.mk
include scripts/make/azure.mk

# ---------------------------------------------------------------------------
# Bootstrap & Environment
# ---------------------------------------------------------------------------
# Configure development environment (main) @Configuration
# This original config differs from init.mk
# config:
# 	_install-tools
# 	_install-uv
# 	githooks-config
# 	dependencies
