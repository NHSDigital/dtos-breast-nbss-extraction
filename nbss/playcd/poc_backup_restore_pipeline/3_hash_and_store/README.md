## 3. Hash the zip and store the hash in Azure Key Vault

### Overview

The `transfer_hash_zip.ps1` PowerShell script computes a SHA-256 hash of the backup zip file and stores it as a secret in Azure Key Vault. This allows the integrity of the backup to be verified at any point — if the hash stored in Key Vault matches the hash of the file you download, the file has not been tampered with or corrupted.

1. **Resolves the zip file** — Uses the path supplied via `-ZipPath`, or auto-selects the most recently modified `*.zip` in the `poc_backup_restore_pipeline` directory
2. **Computes a SHA-256 hash** — Produces a unique fingerprint of the file contents
3. **Checks Azure CLI login** — Automatically launches `az login` if not already authenticated
4. **Stores the hash in Key Vault** — Creates a secret named `{YYYYMMDD}-{BsoCode}-hash` e.g. `20260715-A0001344-hash`

Each zip file produces a different hash because the zip embeds the timestamp of when files were compressed, ensuring the value stored in Key Vault always reflects that specific backup.

### Why Run Through the .bat File?

The `.bat` wrapper (`transfer_hash_zip.bat`) bypasses PowerShell execution policy restrictions — the same reason as `create_nbss_back_up.bat`. See [Why Run Through the .bat File?](../2_zip_backup_files/README.md#why-run-through-the-bat-file) in step 2.

### Requirements

- **Azure CLI** — Install from <https://aka.ms/installazurecliwindows>
- **Azure Key Vault access** — The authenticated identity must have the **Key Vault Secrets Officer** role on the target vault
- **A zip file** — Produced by `create_nbss_back_up.bat` in the previous step

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BsoCode` | *(mandatory)* | BSO code embedded in the secret name e.g. `A0001344` |
| `-KeyVaultName` | `nbsse-dev-kv` | Name of the Azure Key Vault |
| `-ZipPath` | *(newest `*.zip` in `poc_backup_restore_pipeline`)* | Full path to the zip file to hash |

### Usage

From `nbss/playcd/poc_backup_restore_pipeline/3_hash_and_store`:

#### Simple (auto-detects newest zip)

```PowerShell
.\transfer_hash_zip.bat A0001344
```

#### With explicit zip path

```PowerShell
.\transfer_hash_zip.bat A0001344 "C:\path\to\20260715-A0001344.zip"
```

#### With a different Key Vault

```PowerShell
.\transfer_hash_zip.ps1 -BsoCode "A0001344" -KeyVaultName "my-other-kv" -ZipPath "C:\path\to\backup.zip"
```

### Output

```output
Zip file   : C:\...\20260715-A0001344.zip
SHA-256    : ....
Secret name: 20260715-A0001344-hash
Azure CLI  : logged in as user@nhs.net
Storing secret in Key Vault 'nbsse-dev-kv' ...
Secret stored successfully.
Secret ID  : https://nbsse-dev-kv.vault.azure.net/secrets/20260715-A0001344-hash/...
```

### Files

- `transfer_hash_zip.ps1` — The main PowerShell script (hashing and Key Vault logic)
- `transfer_hash_zip.bat` — Wrapper batch file (enables running without execution policy issues)

### Notes

- Key Vault secret names only allow **letters, numbers, and hyphens** — underscores are not permitted
- Running the script on the same day with the same BSO code will **overwrite** the existing secret for that day. Use `-ZipPath` explicitly if running multiple times per day to ensure the correct file is hashed
- The script will prompt for `az login` automatically if you are not already authenticated
