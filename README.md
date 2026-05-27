# Hermes Agent Docker Installer

<p align="center">
  <pre>
   __                            __
  / /  ___  ____ _  ___  ___ ___/ /__  ____  ___ ___
 / _ \/ _ \/ __/  \/ -_)(_-</  _  / _ \/ __/  \/ -_)__
/_//_/\___/_/ /_/\_/\__//___/\_,_/\___/\__/_/\_/\__/(_)
  </pre>
  <strong>Run Hermes Agent in Docker with one command.</strong><br>
  Isolated host. Persistent state. Local API server. Support Linux, macOS, WSL, and Windows.
</p>

<p align="center">
  <a href="https://github.com/lunaticbugbear/hermes-docker-installer/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/lunaticbugbear/hermes-docker-installer/actions/workflows/ci.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg"></a>
  <img alt="Docker" src="https://img.shields.io/badge/runtime-Docker-2496ED">
  <img alt="Platforms" src="https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-blueviolet">
</p>

---

## Architecture & Data Flow

```text
               +-------------------------------------------------+
               |                   HOST SYSTEM                   |
               |                                                 |
               |  ~/.hermes-docker/                              |
               |  ├── .env  (API Keys, Port, Config)             |
               |  ├── docker-compose.yml                         |
               |  │                                              |
               |  ├── workspace/  <======= Bind Mount ========>  |
               |  |                                           |  |
               +--|-------------------------------------------|--+
                  |                                           |
                  |                  Virtual                  |
                  |                  Network                  |
                  |                                           |
+-----------------|-------------------------------------------|--+
|                 v                                           v  |
|     [ Container: hermes ]                           /workspace |
|                                                                |
|     - Runs: hermes gateway run                                 |
|     - API Server: 127.0.0.1:8642 (Host Port)                   |
|                                                                |
|     /root/.hermes  <========== Named Volume ==========>        |
|                                                     |          |
+-----------------------------------------------------|----------+
                                                      v
                                            [ Volume: hermes_home ]
                                            - config.yaml & .env
                                            - sessions/ (transcripts)
                                            - memory/ & skills/
```

---

## Why this exists

Hermes Agent is powerful, but local setup can get messy: Python versions, system packages, browser tooling, API keys, and platform differences.

This repo gives you a clean Docker-based install flow:

- **Isolated Runtime**: Keep host Python and package dependencies untouched.
- **Zero Configuration**: Automatically generates `.env`, Dockerfile, Compose file, bootstrap, healthcheck, and workspace.
- **State Persistence**: State (memory, skills, sessions) is stored in a dedicated Docker volume.
- **Local API Gateway**: Exposes the local Hermes API server on `127.0.0.1` by default for desktop clients.
- **Flexible Providers**: Support OpenRouter, Anthropic, OpenAI, Google/Gemini, DeepSeek, and custom OpenAI-compatible endpoints.

---

## Quick start

### Linux / macOS / WSL / Git Bash

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hermes-docker-installer/main/install.sh)
```

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -c "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/lunaticbugbear/hermes-docker-installer/main/install.ps1' -OutFile install.ps1; .\install.ps1"
```

The installer will ask for provider, model, port, and API key when needed.

---

## Non-interactive install

Useful for servers, CI, repeatable setup, or scripts.

```bash
HERMES_NONINTERACTIVE=1 \
OPENROUTER_API_KEY=<OPENROUTER_API_KEY> \
bash install.sh \
  --provider openrouter \
  --model deepseek/deepseek-v4-flash:free \
  --port 8642
```

Windows:

```powershell
.\install.ps1 `
  -Provider openrouter `
  -Model deepseek/deepseek-v4-flash:free `
  -OpenRouterApiKey "<OPENROUTER_API_KEY>" `
  -Port 8642
```

---

## What gets installed

Default install directory:

```text
~/.hermes-docker/
├── .env
├── Dockerfile
├── docker-compose.yml
├── bootstrap.sh
├── healthcheck.sh
├── bin/
│   └── hermes-docker
└── workspace/
```

Runtime layout:

| Host Path | Container Path | Purpose |
|---|---|---|
| `~/.hermes-docker/workspace` | `/workspace` | Files and projects Hermes works on |
| Docker volume `hermes_home` | `/root/.hermes` | Hermes config, sessions, memory |
| `127.0.0.1:8642` | Port 8642 | Local Hermes API server |

---

## Daily commands

Linux / macOS / WSL:

```bash
cd ~/.hermes-docker
./bin/hermes-docker start     # Start stack in background
./bin/hermes-docker cli       # Open interactive Hermes CLI
./bin/hermes-docker logs      # View gateway logs
./bin/hermes-docker status    # Check container status
./bin/hermes-docker shell     # Exec bash inside container
./bin/hermes-docker update    # Rebuild & restart stack
./bin/hermes-docker url       # Get API url
./bin/hermes-docker key       # Get API Server auth key
```

Windows PowerShell:

```powershell
cd $env:USERPROFILE\.hermes-docker
.\hermes-docker.ps1 start
.\hermes-docker.ps1 cli
.\hermes-docker.ps1 logs
.\hermes-docker.ps1 status
```

---

## Options

### `install.sh`

| Option | Default | Description |
|---|---:|---|
| `--dir PATH` | `~/.hermes-docker` | install directory |
| `--provider NAME` | `openrouter` | `openrouter`, `anthropic`, `openai`, `google`, `deepseek`, or `custom` |
| `--model MODEL` | `deepseek/deepseek-v4-flash:free` | model name passed to Hermes |
| `--port PORT` | `8642` | local API server port |
| `--name NAME` | `hermes-agent` | Docker Compose project name |
| `--browser` | off | include Playwright + Chromium |
| `--no-start` | off | build/generate but do not start |
| `--skip-build` | off | generate files only; no Docker build/start |
| `--force` | off | overwrite generated files |
| `--uninstall` | off | stop stack and optionally remove volume |

### `install.ps1`

| Option | Default | Description |
|---|---:|---|
| `-InstallDir PATH` | `%USERPROFILE%\.hermes-docker` | install directory |
| `-Provider NAME` | `openrouter` | provider name |
| `-Model MODEL` | `deepseek/deepseek-v4-flash:free` | model name |
| `-Port PORT` | `8642` | local API server port |
| `-ProjectName NAME` | `hermes-agent` | Docker Compose project name |
| `-Browser` | off | include Playwright + Chromium |
| `-NoStart` | off | build/generate but do not start |
| `-SkipBuild` | off | generate files only |
| `-Force` | off | overwrite generated files |
| `-Uninstall` | off | stop stack and optionally remove volume |

---

## Provider keys

Set one key for the provider you use:

| Provider | Environment variable |
|---|---|
| OpenRouter | `OPENROUTER_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |
| OpenAI | `OPENAI_API_KEY` |
| Google/Gemini | `GOOGLE_API_KEY` or `GEMINI_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| Custom endpoint | `CUSTOM_API_KEY` + `CUSTOM_BASE_URL` |

Extra installer env vars:

| Variable | Purpose |
|---|---|
| `API_SERVER_KEY` | use fixed API bearer key instead of generated key |
| `HERMES_VERSION` | Hermes Agent git ref/tag/branch to install |
| `HERMES_NONINTERACTIVE=1` | skip interactive prompts in shell installer |

---

## Browser automation

Browser tooling is intentionally disabled by default, because Playwright + Chromium adds size and install time.

Enable only when you need browser automation:

```bash
bash install.sh --browser
```

```powershell
.\install.ps1 -Browser
```

---

## Pin Hermes Agent version

By default, the Docker build installs Hermes Agent from `main`.

Pin a branch, tag, or commit:

```bash
HERMES_VERSION=v0.5.0 bash install.sh
```

Or:

```bash
HERMES_VERSION=main bash install.sh --force
```

---

## Update config

Edit generated `.env`:

```bash
cd ~/.hermes-docker
nano .env
./bin/hermes-docker restart
```

Common fields:

```env
MODEL_PROVIDER=openrouter
MODEL_NAME=deepseek/deepseek-v4-flash:free
API_SERVER_PORT=8642
OPENROUTER_API_KEY=...
```

---

## Uninstall

Shell:

```bash
bash uninstall.sh
bash uninstall.sh --remove-data
bash uninstall.sh --remove-files
bash uninstall.sh --remove-files --remove-data
```

PowerShell:

```powershell
.\uninstall.ps1
.\uninstall.ps1 -RemoveData
.\uninstall.ps1 -RemoveFiles
.\uninstall.ps1 -RemoveFiles -RemoveData
```

Defaults are conservative: containers stop, files and volumes stay unless removal is requested.

---

## Safety defaults

- API binds to `127.0.0.1`, not public interfaces.
- `.env` is generated with `600` permissions on Unix-like systems.
- Browser dependencies are opt-in.
- Existing `.env` is preserved unless `--force` / `-Force` is used.
- Uninstall does not delete data by default.
- `--skip-build` only generates files and does not require Docker to be running.

---

## CI checks

Every push validates:

- Bash syntax
- ShellCheck
- PowerShell parser
- generated Docker Compose config
- generated helper script syntax
- uninstall mode safety
- docs sanity
- Docker build + API health smoke test on `main`

---

## Troubleshooting

### Docker installed but not reachable

Start Docker and rerun:

```bash
sudo systemctl start docker
```

macOS:

```bash
open -a Docker
```

Windows: open Docker Desktop and wait until it says it is running.

### Port already in use

Pick another port:

```bash
bash install.sh --port 18642
```

### Model calls fail

Check `.env`:

```bash
cd ~/.hermes-docker
./bin/hermes-docker logs
nano .env
./bin/hermes-docker restart
```

Verify provider key and model name.

---

## Repository files

| File | Purpose |
|---|---|
| `install.sh` | Linux/macOS/WSL/Git Bash installer |
| `install.ps1` | Windows PowerShell installer |
| `uninstall.sh` | shell uninstaller |
| `uninstall.ps1` | PowerShell uninstaller |
| `.github/workflows/ci.yml` | CI pipeline |
| `CHANGELOG.md` | release notes |
| `SECURITY.md` | security model |
| `CONTRIBUTING.md` | contribution checks |

---

## License

MIT. See [`LICENSE`](LICENSE).
