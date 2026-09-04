.PHONY: bootstrap
.SILENT: bootstrap

bootstrap: set-azure-account get-subscription-ids # Initialise Terraform resources - make bootstrap @Bootstrap
	@echo STORAGE_ACCOUNT_NAME=sa${APP_SHORT_NAME}${ENV_CONFIG}tfstate
	$(eval STORAGE_ACCOUNT_NAME=sa${APP_SHORT_NAME}${ENV_CONFIG}tfstate)
	@bash scripts/bootstrap/run_bootstrap.sh "${REGION}" "${HUB_SUBSCRIPTION_ID}" "${ENABLE_SOFT_DELETE}" "${ENV_CONFIG}" "${STORAGE_ACCOUNT_RG}" "${STORAGE_ACCOUNT_NAME}" "${APP_SHORT_NAME}"
