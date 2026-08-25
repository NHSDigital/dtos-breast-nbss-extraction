.PHONY: terraform-init terraform-validate terraform-plan terraform-apply terraform-destroy terraform-fetch-modules _check-paths terraform-fmt
.SILENT: terraform-validate terraform-init terraform-fetch-modules terraform-plan terraform-apply terraform-destroy _check-paths terraform-fmt

TF_DIR ?= infrastructure/terraform
TF_VARS ?= infrastructure/environments/${ENV_CONFIG}/variables.tfvars
TF_MODULES_DIR := infrastructure/modules/dtos-devops-templates

_check-paths:
	@echo "TF_DIR: $(TF_DIR)"
	@echo "TF_VARS: $(TF_VARS)"
	@echo "TF_MODULES_DIR: $(TF_MODULES_DIR)"

	@if [ ! -d "$(TF_DIR)" ]; then \
		echo "ERROR: TF_DIR does not exist: $(TF_DIR)"; \
		exit 1; \
	fi
	@if ! find "$(TF_DIR)" -maxdepth 1 -type f -name "*.tf" | grep -q .; then \
		echo "ERROR: TF_DIR contains no Terraform *.tf files: $(TF_DIR)"; \
		exit 1; \
	fi
	@if [ ! -f "$(TF_VARS)" ]; then \
		echo "ERROR: TF_VARS does not exist: $(TF_VARS)"; \
		exit 1; \
	fi

	@echo "✅ Terraform paths are valid"

terraform-init: _check-paths terraform-fetch-modules set-az-account get-subscription-ids # Initialise Terraform and backend storage - make terraform-init @Terraform
	$(eval STORAGE_ACCOUNT_NAME=sa${APP_SHORT_NAME}${ENV_CONFIG}tfstate)
	$(eval export ARM_USE_AZUREAD=true)

	# Don't specify '-upgrade' because plan/apply must honour the lock file. \
	terraform -chdir="$(TF_DIR)" init \
		-reconfigure \
		-backend-config="subscription_id=${HUB_SUBSCRIPTION_ID}" \
		-backend-config="resource_group_name=${STORAGE_ACCOUNT_RG}" \
		-backend-config="storage_account_name=${STORAGE_ACCOUNT_NAME}" \
		-backend-config="key=${ENVIRONMENT}.tfstate"; \

	$(eval export TF_VAR_app_short_name=${APP_SHORT_NAME})
	$(eval export TF_VAR_environment=${ENVIRONMENT})
	$(eval export TF_VAR_env_config=${ENV_CONFIG})
	$(eval export TF_VAR_hub=${HUB})
	$(eval export TF_VAR_hub_subscription_id=${HUB_SUBSCRIPTION_ID})

terraform-plan: terraform-init # Plan Terraform changes - make terraform-plan @Terraform
	terraform -chdir="$(TF_DIR)" plan -var-file "$(TF_VARS)"

terraform-apply: terraform-init # Apply Terraform plan changes - make terraform-apply @Terraform
	terraform -chdir="$(TF_DIR)" apply -var-file "$(TF_VARS)" ${AUTO_APPROVE}

terraform-destroy: terraform-init # Destroy Terraform resources - make terraform-destroy @Terraform
	terraform -chdir="$(TF_DIR)" destroy -var-file "$(TF_VARS)" ${AUTO_APPROVE}

terraform-validate: terraform-init # Validate Terraform changes - make terraform-validate @Terraform
	terraform -chdir="$(TF_DIR)" validate
	@echo "✅ Terraform validation successful"

terraform-fetch-modules: # Git clone the DevOps Templates repo if it doesn't exist on disk. @Terraform
	@if [ ! -d "$(TF_MODULES_DIR)/.git" ]; then \
		git -c advice.detachedHead=false clone --depth=1 --single-branch --branch ${TERRAFORM_MODULES_REF} \
			https://github.com/NHSDigital/dtos-devops-templates.git "$(TF_MODULES_DIR)"; \
	fi

terraform-fmt: # Format Terraform files - optional: terraform_dir|dir=[path to a directory where the command will be executed, relative to the project's top-level directory, default is one of the module variables or the example directory, if not set], terraform_opts|opts=[options to pass to the Terraform fmt command, default is '-recursive'] @Terraform
	terraform -chdir="$(TF_DIR)" fmt -recursive
	@echo "✅ Terraform files formatted successfully"
