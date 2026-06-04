# Hades Architecture

## What it is

Hades is a packaging and orchestration layer on top of upstream Hermes Agent. It's not a fork.

It handles:

1. detecting the host environment
2. collecting provider, model, port, and credential inputs
3. generating a Docker-based runtime layout
4. starting and managing the container stack
5. keeping Hermes state alive across rebuilds

## Runtime layout

```text
 HOST                                     CONTAINER
+------------------------+      +-----------------------------+
| ~/.hades/              |      | hades                       |
|   .env                 |      |   hermes gateway run        |
|   docker-compose.yml   |      |   API: 127.0.0.1:8642       |
|   workspace/  <--------+------+-> /workspace                |
|                        |      |                             |
+------------------------+      |   /home/hermes/.hermes <-----------+-- volume
                                |   (sessions, memory,        |
                                |    skills, config)          |
                                +-----------------------------+
```

### Host side (install directory, default `~/.hades/`)

- `.env` — provider keys, model, API port, build flags
- `Dockerfile` — multi-stage build (builder + slim runtime)
- `docker-compose.yml` — volume, port, and workspace wiring
- `bootstrap.sh` — idempotent first-run setup inside the container
- `healthcheck.sh` — API health probe
- `bin/hades`, `bin/hades.ps1`, `bin/hades.cmd` — operator control scripts
- `workspace/` — bind-mounted to `/workspace` inside the container

### Container side

Persistent Hermes state lives in a Docker named volume mounted at `/home/hermes/.hermes`. Sessions, memories, skills, and config survive container rebuilds and restarts.

## Lifecycle

### Install

1. Preflight: validate shell and platform assumptions
2. Dependency check: confirm Docker and Compose are available, install them if missing and supported
3. Input resolution: interactive or non-interactive
4. File generation: write runtime files into the install directory
5. Image build: skipped if `--skip-build` / `-SkipBuild` is set
6. Stack start: skipped if `--no-start` / `-NoStart` is set

### Container startup

`bootstrap.sh` runs as the container entrypoint:

- migrates data from legacy `/root/.hermes` to `/home/hermes/.hermes` if found
- creates required directories if missing
- seeds `.env` and `config.yaml` using md5 hashing — regenerates config only when host env vars change
- enables all Hermes tools (terminal, file, web, browser, vision, skills, memory, session_search, delegation, cronjob, todo)
- hands off to `hermes gateway run`

## Security defaults

- API binds to `127.0.0.1`
- `.env` is chmod 600 on Unix
- browser automation is opt-in
- uninstall is non-destructive by default
- generated files are preserved unless `--force` is passed

## Platform notes

**Linux / macOS / WSL:**
- installer is `install.sh`
- PATH registration targets `bash`, `zsh`, `fish`
- root installs use `/usr/local/lib/hades` + `/usr/local/bin/hades`

|**Windows:**
|- installer is `install.ps1`
|- helper scripts include `.ps1` and `.cmd` (generated at install time from templates in the installers)
|- PATH registered at User or Machine scope based on elevation
|- Docker Desktop required

## Design principles

- Stable defaults over clever behavior
- Explicit operator commands over hidden state
- Reproducible file generation
- Conservative uninstall
- Error output that tells the user what to do next

## Non-goals

- Managing Hermes upstream releases
- Handling provider billing or quota
- Exposing the API publicly by default
- Being a general-purpose container platform
