# Omnipod Architecture

## Goal

Omnipod exists to make Hermes Agent installation operationally predictable across Linux, macOS, WSL, and Windows while keeping the host machine clean.

## High-level model

Omnipod is not a fork of Hermes Agent.
It is a runtime packaging and orchestration layer around upstream Hermes Agent.

Core responsibilities:

1. detect the host environment
2. gather provider / model / port / credential inputs
3. generate a reproducible Docker-based runtime layout
4. start and manage the Hermes container stack
5. preserve persistent Hermes state across rebuilds and restarts

## Runtime layout

### Host-managed files

These are generated into the install directory (default `~/.omnipod/` for non-root installs):

- `.env` — provider keys, model, API port, install flags
- `Dockerfile` — multi-stage runtime image build
- `docker-compose.yml` — container, volume, port, and workspace wiring
- `bootstrap.sh` — idempotent first-run config seeding inside container
- `healthcheck.sh` — API health probe
- `bin/omnipod` / `bin/omnipod.ps1` / `bin/omnipod.cmd` — operator wrappers
- `workspace/` — bind-mounted host working directory

### Container-managed state

Persistent Hermes state lives in a Docker named volume mounted at `/root/.hermes`.
This keeps sessions, memories, skills, and config durable across container rebuilds.

## Lifecycle

### Install time

1. preflight checks validate shell / platform assumptions
2. Docker and Compose availability are confirmed or bootstrapped where supported
3. interactive or non-interactive inputs are resolved
4. runtime files are generated into the install directory
5. Docker image is built unless `--skip-build` / `-SkipBuild` is used
6. stack is started unless `--no-start` / `-NoStart` is used

### Runtime

The container entrypoint runs `bootstrap.sh`, which:

- ensures required directories exist
- seeds `.env` and `config.yaml` only when missing
- preserves existing state rather than overwriting it
- delegates final process execution to Hermes (`hermes gateway run`)

## Security boundaries

Omnipod deliberately applies conservative defaults:

- API binds to `127.0.0.1` by default
- `.env` permissions are restricted on Unix-like systems
- browser automation is opt-in
- uninstall is non-destructive by default
- generated config is preserved unless force-overwrite is requested

## Cross-platform notes

### Linux / macOS / WSL

- shell installer is `install.sh`
- PATH integration targets common login shells (`bash`, `zsh`, `fish`)
- root installs prefer `/usr/local/lib/omnipod` with `/usr/local/bin/omnipod`

### Windows

- PowerShell installer is `install.ps1`
- helper wrappers include `.ps1` and `.cmd`
- PATH is registered at User or Machine scope depending on elevation
- Docker Desktop is the expected runtime backend

## Design principles

- stable defaults over clever behavior
- explicit operator commands over hidden state
- reproducible generated files
- conservative teardown behavior
- actionable error output for non-expert users

## Non-goals

Omnipod does not try to:

- replace Hermes Agent upstream release management
- manage provider billing or quota issues
- expose the Hermes API publicly by default
- be a general-purpose container platform
