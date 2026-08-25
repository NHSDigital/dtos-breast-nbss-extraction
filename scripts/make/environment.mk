# specifying environments like this avoids order-dependent commands like 'make dev terraform-plan'

.SILENT: dev prod
.PHONY: dev prod

REGION ?= UK South
APP_SHORT_NAME ?= nbsse
STORAGE_ACCOUNT_RG ?= rg-dtos-state-files

dev: # Provide a shortcut for dev environment - make dev <action> @Environment
	$(eval export ENV_CONFIG=dev)
	$(eval include infrastructure/environments/$(ENV_CONFIG)/variables.sh)

prod: # Provide a shortcut for production environment - make prod <action> @Environment
	$(eval export ENV_CONFIG=prod)
	$(eval include infrastructure/environments/$(ENV_CONFIG)/variables.sh)