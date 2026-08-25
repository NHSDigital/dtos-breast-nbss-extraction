.SILENT: set-az-account get-subscription-ids
.PHONY: set-az-account get-subscription-ids

set-az-account: # Set the Azure account for the environment - make set-az-account @Azure
	$(eval AZURE_SUBSCRIPTION_NAME=$(subst ",,$(AZURE_SUBSCRIPTION)))
	if [ "${SKIP_AZURE_LOGIN}" = "true" ]; then
		echo "Skipping Azure account selection (SKIP_AZURE_LOGIN=true)"
		exit 0
	fi
	echo "Setting Azure account to subscription: ${AZURE_SUBSCRIPTION_NAME}"
	az account show >/dev/null
	az account set --subscription "${AZURE_SUBSCRIPTION_NAME}"


get-subscription-ids: # Retrieve the hub subscription ID based on the subscription name in ${HUB_SUBSCRIPTION} - make get-subscription-ids @Azure
	$(eval HUB_SUBSCRIPTION_NAME=$(subst ",,$(HUB_SUBSCRIPTION)))
	$(eval HUB_SUBSCRIPTION_ID=$(shell az account show --query id --output tsv --subscription "${HUB_SUBSCRIPTION_NAME}"))
	$(if ${ARM_SUBSCRIPTION_ID},,$(eval export ARM_SUBSCRIPTION_ID=$(shell az account show --query id --output tsv)))
	if [ -z "$(HUB_SUBSCRIPTION_ID)" ]; then
		echo "Unable to resolve hub subscription: $(HUB_SUBSCRIPTION_NAME)"
		exit 1
	fi
	if [ -z "$(ARM_SUBSCRIPTION_ID)" ]; then
		echo "Unable to resolve application subscription"
		exit 1
	fi
	echo
	echo "Working with subscription IDs"
	echo "==============================="
	echo HUB_SUBSCRIPTION_ID=${HUB_SUBSCRIPTION_ID}
	echo ARM_SUBSCRIPTION_ID=${ARM_SUBSCRIPTION_ID}
	echo

