# NBSS Backup-Restore process - Proof of Concept

This documentation and code details the steps required to back up and restore an
NBSS instance. The pipeline is split into two processes that run on different
machines and at different times:

## Processes

| Process | Steps | Runs on | Purpose |
|---------|-------|---------|---------|
| [BSO process](bso_process/README.md) | 2–4 | Source BSO machine | Create a backup zip, hash it into Key Vault, and upload it to Azure Storage |
| [NBSSE process](nbsse_process/README.md) | 5–9 | Clean restore-target machine | Download and verify the zip, restore it onto a clean Caché install, verify integrity, and scrape the tables into Databricks |

The two processes are joined through Azure Storage: the BSO process uploads the
backup zip, and the NBSSE process downloads it. Each process has its own README
with its own prerequisites, variables and quickstart.

## Optional pre-step

- [1. Backup NBSS manually](1_manual_nbss_backup/README.md) — only needed if a
  scheduled overnight backup is not available. Run this before the BSO process.

## Shared reference docs

- [Azure Key Vault — create, retrieve and set RBAC for secrets](docs/azure_key_vault.md)
- [Create a storage container in an existing storage account](docs/generate_storage_container.md)
- [Creating a Caché user](docs/create_admin_user.md)

## A note on naming convention

A consistent naming pattern links the hash stored in Key Vault to the correct
blob in storage:

| Artifact | Format | Example |
|----------|--------|---------|
| Zip filename (uploaded to storage) | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |
| Key Vault secret name | `{YYYYMMDD}-{BsoCode}-hash` | `20260715-A0001344-hash` |
| Blob name in storage container | `{YYYYMMDD}-{BsoCode}.zip` | `20260715-A0001344.zip` |

The NBSSE download script (step 5) derives the secret name by stripping the
`.zip` extension from the blob name and appending `-hash`.
