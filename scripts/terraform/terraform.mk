.SILENT: terraform-init terraform-plan terraform-apply terraform-destroy terraform-fmt terraform-validate
.PHONY: terraform-init terraform-plan terraform-apply terraform-destroy terraform-fmt terraform-validate

ENV ?= dev
ENV_CONFIG ?= $(ENV)
TF_DIR ?= $(or ${dir},infrastructure/terraform)
TF_OPTS ?= $(or ${terraform_opts},${opts})
APP_SHORT_NAME=nbsse
STORAGE_ACCOUNT_RG=rg-dtos-state-files

ci: # Skip manual approvals when running in CI - make ci <env> <action>
	$(eval AUTO_APPROVE=-auto-approve)
	$(eval SKIP_AZURE_LOGIN=true)
	$(eval SKIP_DEVOPS_TEMPLATE=true)

terraform-init-no-backend: # Initialise terraform modules only and update terraform lock file - make <env> terraform-init-no-backend
	rm -rf infrastructure/modules/dtos-devops-templates
	git -c advice.detachedHead=false clone --depth=1 --single-branch --branch ${TERRAFORM_MODULES_REF} \
		https://github.com/NHSDigital/dtos-devops-templates.git infrastructure/modules/dtos-devops-templates
	terraform -chdir=$(TF_DIR) init -upgrade -backend=false $(TF_OPTS)

terraform-init: set-azure-account get-subscription-ids # Initialise Terraform - make <env> terraform-init
	$(eval STORAGE_ACCOUNT_NAME=sa${APP_SHORT_NAME}${ENV_CONFIG}tfstate)
	$(eval export ARM_USE_AZUREAD=true)

	if [ "${SKIP_DEVOPS_TEMPLATE}" = "true" ]; then \
		echo "Skipping dtos-devops-templates clone (SKIP_DEVOPS_TEMPLATE=true)"; \
	else \
		rm -rf infrastructure/modules/dtos-devops-templates; \
		git -c advice.detachedHead=false clone --depth=1 --single-branch --branch ${TERRAFORM_MODULES_REF} \
			https://github.com/NHSDigital/dtos-devops-templates.git infrastructure/modules/dtos-devops-templates; \
	fi

	terraform -chdir=$(TF_DIR) init -upgrade -reconfigure \
		-backend-config=subscription_id=${HUB_SUBSCRIPTION_ID} \
		-backend-config=resource_group_name=${STORAGE_ACCOUNT_RG} \
		-backend-config=storage_account_name=${STORAGE_ACCOUNT_NAME} \
		-backend-config=key=${ENVIRONMENT}.tfstate

	$(eval export TF_VAR_app_short_name=${APP_SHORT_NAME})
	$(eval export TF_VAR_environment=${ENVIRONMENT})
	$(eval export TF_VAR_env_config=${ENV_CONFIG})
	$(eval export TF_VAR_hub=${HUB})
	$(eval export TF_VAR_hub_subscription_id=${HUB_SUBSCRIPTION_ID})
	$(eval export TF_VAR_arm_subscription_id=${ARM_SUBSCRIPTION_ID})

terraform-plan: terraform-init # Plan Terraform changes - make <env> terraform-plan DOCKER_IMAGE_TAG=abcd123
	terraform -chdir=infrastructure/terraform plan -var-file ../environments/${ENV_CONFIG}/variables.tfvars

terraform-apply: terraform-init # Apply Terraform changes - make <env> terraform-apply DOCKER_IMAGE_TAG=abcd123
	terraform -chdir=infrastructure/terraform apply -var-file ../environments/${ENV_CONFIG}/variables.tfvars ${AUTO_APPROVE}

terraform-destroy: terraform-init # Destroy Terraform resources - make <env> terraform-destroy
	terraform -chdir=infrastructure/terraform destroy -var-file ../environments/${ENV_CONFIG}/variables.tfvars ${AUTO_APPROVE}

terraform-validate: # Validate Terraform changes - make <env> terraform-validate
	terraform -chdir=$(TF_DIR) validate
