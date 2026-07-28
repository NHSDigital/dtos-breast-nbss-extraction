# Creating a Storage Container in an Existing Storage Account

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- An existing storage account

## Create a Storage Container

Use `az storage container create` to create a new container with default private access inside a pre-existing storage account. The command will fail if the container already exist.

```bash
az storage container create \
    --name <container-name> \
    --account-name <storage-account-name> \
    --fail-on-exist
```

### Options

| Parameter | Description |
|-----------|-------------|
| `--name` / `-n` | **Required.** The container name. |
| `--account-name` | Storage account name. |
| `--account-key` | Storage account key (alternative to login auth). |
| `--auth-mode` | `login` (use Azure AD credentials) or `key` (use account key). |
| `--public-access` | `off` (default), `blob`, or `container`. |
| `--fail-on-exist` | Return an error if the container already exists. |
| `--metadata` | Space-separated key=value pairs for container metadata. |

## View Container Configuration

These commands allow you to see the configuration of a storage container.

### View Current Container Properties

```bash
az storage container show \
    --name <container-name> \
    --account-name <storage-account-name>
```

### View Current Permissions

```bash
az storage container show-permission \
    --name <container-name> \
    --account-name <storage-account-name>
```

## Reference

- [az storage container — Azure CLI docs](https://learn.microsoft.com/en-us/cli/azure/storage/container?view=azure-cli-latest)
