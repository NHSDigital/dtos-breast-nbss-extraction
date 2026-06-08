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
  - [Testing](#testing)
    - [Locally](#locally)
    - [On Databricks (dev)](#on-databricks-dev)
  - [Dependency management with uv](#dependency-management-with-uv)
    - [Workspaces](#workspaces)
    - [Adding a new workspace](#adding-a-new-workspace)
    - [Running commands within a workspace](#running-commands-within-a-workspace)
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

## Dependency management with uv

This repo uses [uv](https://docs.astral.sh/uv/) for Python dependency management. Each sub-project is a **standalone uv workspace** with its own virtual environment and lockfile, keeping dependencies fully isolated from one another.

### Workspaces

| Directory | Package | Purpose |
|-----------|---------|----------|
| `.` (root) | `dtos-breast-nbss-extraction` | Repo-level tooling |
| `asset_bundles/` | `asset-bundles` | DLT pipeline code & unit tests |
| `nbss/playcd/` | `playcd` | NBSS extraction scripts |

Each workspace contains its own `pyproject.toml` and `uv.lock`, so dependency changes in one workspace have no effect on the others.

### Adding a new workspace

To create a new isolated sub-workspace that is **not** linked to the root or any other workspace, use the `--no-workspace` flag:

```shell
# Create a new standalone workspace at <directory>
uv init --no-workspace <directory>
```

This generates a `pyproject.toml` and a scoped `uv.lock` inside `<directory>` only. Omitting this flag would allow uv to auto-discover and attach the new project to a parent workspace if one exists.

> [!NOTE]
> Older versions of uv used `--no-link` instead of `--no-workspace`. If your uv version predates `0.4`, substitute `--no-link`.

To add a dependency to the new workspace:

```shell
cd <directory>
uv add <package>
```

### Running commands within a workspace

All `uv` commands are scoped to the directory they are run from. Change into the relevant workspace first:

```shell
# Install / sync dependencies
cd nbss/playc
uv sync

# Run a script
uv run python unpack_scripts.py
```

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for branch naming, commit message conventions, PR workflow and coding standards.

## Contacts

Slack: **screening-breast-reporting**

## Licence

Unless stated otherwise, the codebase is released under the MIT License. This covers both the codebase and any sample code in the documentation.

Any HTML or Markdown documentation is [© Crown Copyright](https://www.nationalarchives.gov.uk/information-management/re-using-public-sector-information/uk-government-licensing-framework/crown-copyright/) and available under the terms of the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
