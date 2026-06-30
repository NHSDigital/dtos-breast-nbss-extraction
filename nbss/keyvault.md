# Azure Key Vault — Create, Retrieve and Set RBAC for Secrets

All commands are written for **WSL Bash** (or Azure Cloud Shell Bash).

This guide describes how to create, retrieve, and set role-based access control for users or groups (BSO) on secrets in Azure Key Vault.

## Prerequisites

- An Azure Key Vault already exists.
- Azure CLI is installed (for example, via uv).

If Azure CLI is not installed, please install [Azure cli](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt)

---

## Step 1 — Log in to Azure CLI

Ensure you are logged in before running commands.

```bash
az login
```

You may be prompted to select a subscription. For this guide, select `Digital Screening DToS - Sandbox`.

---

## Step 2 — Set Variables

```bash
KEY_VAULT_NAME="nbsse-dev-kv"
VAULT_ID="$(az keyvault show --name "$KEY_VAULT_NAME" --query id -o tsv)"

# Resolve group IDs by name
BSO_GROUP_1_ID="$(az ad group show --group "screening_brs_databricks_bso_BSO001" --query id -o tsv)"
BSO_GROUP_2_ID="$(az ad group show --group "screening_brs_databricks_bso_BSO002" --query id -o tsv)"

# Verify
echo "Vault ID:       $VAULT_ID"
echo "BSO Group 1 ID: $BSO_GROUP_1_ID"
echo "BSO Group 2 ID: $BSO_GROUP_2_ID"
```

---

## Actions

Choose the action you want to perform:

- [Create Secrets](#create-secrets)
- [Assign Users or Groups to Secrets (RBAC)](#assign-users-or-groups-to-secrets)
- [Retrieve Secrets](#retrieve-secrets)
- [Useful Lookup Commands](#useful-lookup-commands)

---

## Create Secrets

Requires the **Key Vault Secrets Officer** or **Key Vault Administrator** role on the vault. Replace `<value>` with the actual secret value.

```bash
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "bso-user-1" --value "<value>"
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "bso-pass-1" --value "<value>"
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "bso-user-2" --value "<value>"
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "bso-pass-2" --value "<value>"
```

---

## Assign Users or Groups to Secrets

Requires the **Key Vault Secrets Officer** or **Key Vault Administrator** role on the vault. The example below shows how to assign read-only access to a user or group using `--role`.

Template:

```bash
# Role to grant: read-only access to secret values
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id "$BSO_GROUP_1_ID" \
    --scope "$VAULT_ID/secrets/bso-user-1"
```

Example assignments for the secrets created above:

```bash
# bso-user-1 → BSO Group 1
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id "$BSO_GROUP_1_ID" \
    --scope "$VAULT_ID/secrets/bso-user-1"

# bso-pass-1 → BSO Group 1
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id "$BSO_GROUP_1_ID" \
    --scope "$VAULT_ID/secrets/bso-pass-1"

# bso-user-2 → BSO Group 2
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id "$BSO_GROUP_2_ID" \
    --scope "$VAULT_ID/secrets/bso-user-2"

# bso-pass-2 → BSO Group 2
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id "$BSO_GROUP_2_ID" \
    --scope "$VAULT_ID/secrets/bso-pass-2"
```

### RBAC roles reference

| Role | Capabilities |
|---|---|
| Key Vault Secrets User | Read secret values |
| Key Vault Secrets Officer | Read, create, update, delete secrets |
| Key Vault Administrator | Full data-plane access |

---

## Retrieve Secrets

Requires **Key Vault Secrets User** role on the secret or vault.

```bash
# Get a single secret value
az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "bso-user-1" --query value -o tsv

# List all secret names in the vault
az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "[].name" -o tsv

```

---

## Useful Lookup Commands

If you need to get the ID of a user or group, use these commands:

```bash
# Get your own object ID
az ad signed-in-user show --query id -o tsv

# Look up a user by email
az ad user show --id "user@nhs.net" --query id -o tsv

# Look up a group by name
az ad group show --group "group-display-name" --query id -o tsv
```
