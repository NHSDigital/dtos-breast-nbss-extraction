# NBSS Backup-Restore process - Proof of Concept

This documentation and code details the steps required to back up and restore an
NBSS instance. The pipeline is split into two processes that run on different
machines and at different times:

## Processes

| Process | Steps | Runs on | Purpose |
|---------|-------|---------|---------|
| [BSO process](bso_process/README.md) | 2, 3 | Source BSO machine | Create a backup zip and upload it to Azure Storage |
| [NBSSE process](nbsse_process/README.md) | 4–8 | Clean restore-target machine | Download and verify the zip, restore it onto a clean Caché install, verify integrity, and scrape the tables into Databricks |

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
