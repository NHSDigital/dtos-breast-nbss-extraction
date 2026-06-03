# Breast Screening Reporting

Welcome to the Breast Screening Reporting team's repository. This repo contains data pipelines and reports for the NHS Breast Screening programme. We use [Delta Live Tables (DLT)](https://docs.databricks.com/en/delta-live-tables/index.html) on Azure Databricks to ingest, clean and aggregate screening data through a **bronze → silver → gold** medallion architecture, deployed via [Databricks Asset Bundles (DABs)](https://docs.databricks.com/en/dev-tools/bundles/index.html).

## Table of Contents

- [Breast Screening Reporting](#breast-screening-reporting)
  - [Table of Contents](#table-of-contents)
  - [Setup](#setup)
  - [Prerequisites](#prerequisites)
  - [Quick start](#quick-start)
  - [Repository layout](#repository-layout)
  - [Development workflow](#development-workflow)
  - [Package and Project management](#package-and-project-management)
  - [Testing](#testing)
    - [Locally](#locally)
    - [On Databricks (dev)](#on-databricks-dev)
  - [Contributing](#contributing)
  - [Contacts](#contacts)
  - [Licence](#licence)

## Setup

This should be a frictionless installation process that works on various operating systems (macOS, Linux, Windows WSL) and handles all the dependencies.

## Prerequisites

| Tool | Notes |
|------|-------|
| [Databricks CLI](https://docs.databricks.com/en/dev-tools/cli/install.html) | `brew install databricks` on macOS |
| [Python 3](https://www.python.org/) | For DLT code, tests and Git hooks |
| [GNU make](https://www.gnu.org/software/make/) ≥ 3.82 | macOS default is older — `brew install make` |
| [asdf](https://asdf-vm.com/) | Version manager |
| [uv](https://docs.astral.sh/uv/) | package and project manager |

> [!NOTE]
> On macOS the default GNU make is too old. After `brew install make`, follow the Homebrew output to update your `$PATH`.

VS Code users: install the workspace-recommended extensions via the Command Palette → `@recommended` → **Install Workspace Recommended Extensions**.

## Quick start

```shell
# 1. Clone
git clone git@github.com:NHSDigital/dtos-breast-screening-reporting.git
cd dtos-breast-screening-reporting

# 2. Install toolchain & Python deps
make config

# 3. Configure Databricks CLI auth (one-time)
databricks auth login --profile dev

# enter workspace URL when prompted (see asset_bundles/databricks.yml)

# 4. Deploy your personal dev pipeline
cd asset_bundles
databricks bundle deploy -t dev

# 5. Run it
databricks bundle run -t dev sales_pipeline
```

Each developer gets isolated schemas (e.g. `bronze_<your_short_name>`) so you can deploy freely without affecting others.

## Repository layout

```text
asset_bundles/              ← Databricks Asset Bundles project
  databricks.yml            ← bundle config & target definitions
  resources/                ← DLT pipeline + job YAML definitions
  src/pipelines/            ← DLT pipeline Python code
  tests/unit/               ← local PySpark unit tests
infrastructure/             ← Terraform (workspace, storage, Unity Catalog)
scripts/                    ← CI tooling, Git hooks, linters
docs/                       ← contributing guide & user guides
```

## Development workflow

The day-to-day loop is:

1. Create a branch — see [Contributing](docs/CONTRIBUTING.md)
2. Write or update DLT pipeline code in `asset_bundles/src/pipelines/`
3. Add resource definitions in `asset_bundles/resources/` if needed
4. Add unit tests to `asset_bundles/tests/unit`
5. Run test suite locally: `make test`
6. Deploy to your personal dev schemas: `databricks bundle deploy -t dev`
7. Run on Databricks: `databricks bundle run -t dev <pipeline_name>`
8. Open a PR — see [Contributing](docs/CONTRIBUTING.md)

## Package and Project management

This repo uses [uv](https://docs.astral.sh/uv/) for Python and project management.

### Setting up a new project or folder

If you are adding a new sub-project or workspace member (e.g. a new folder under `nbss/`), initialise it with:

```shell
cd path/to/new-folder
uv init
```

This creates a `pyproject.toml` for that folder. Then add it as a workspace member in the root `pyproject.toml`:

```toml
[tool.uv.workspace]
members = [
    "nbss/new-folder",
]
```

> [!NOTE]
> Do not run `uv init` from the repo root — the root project already exists. Running it again will overwrite the root `pyproject.toml`.

### Adding packages

To add a dependency to a workspace member, run from the member's folder:

```shell
cd path/to/member
uv add <package-name>
```

To add a dependency to the root project:

```shell
uv add <package-name>
```

### Keeping packages up to date

To install or sync all dependencies across the entire workspace (root + all members):

```shell
uv sync
```

To sync only a specific workspace member without leaving the repo root:

```shell
uv sync --package <member-name>
```

If you see packages being unexpectedly uninstalled, regenerate the lockfile first:

```shell
uv lock
uv sync
```

### Running scripts and tools

Use `uv run` to execute a script or tool inside the project's virtual environment without needing to activate it manually:

```shell
# Run a Python script
uv run python path/to/script.py

# Run a script in a specific workspace member
uv run --package playcd python nbss/playcd/export_app_tables.py

```

> [!TIP]
> `uv run` automatically syncs the environment before running, so you don't need to call `uv sync` separately beforehand.

## Testing

### Locally

```shell
# Local tests
make test

# Pre-commit hooks (secrets scan, linting, formatting)
make githooks-run
```

### On Databricks (dev)

```shell
cd asset_bundles
databricks bundle deploy -t dev
databricks bundle run -t dev <pipeline_name>
```

Review the pipeline run in the Databricks UI to verify data flows through bronze → silver → gold correctly.

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for branch naming, commit message conventions, PR workflow and coding standards.

## Contacts

Slack: **screening-breast-reporting**

## Licence

Unless stated otherwise, the codebase is released under the MIT License. This covers both the codebase and any sample code in the documentation.

Any HTML or Markdown documentation is [© Crown Copyright](https://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/uk-government-licensing-framework/crown-copyright/) and available under the terms of the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
