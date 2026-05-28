# Omnipod

<p align="center">
  <pre>
  ___  __  __ _  _ ____ ___  ___  ___  
 / _ \|  \/  |  \| |  _ \ _ \|   \|   \ 
| (_) | |\/| | |   | |_) |_) | | | | | |
 \___/|_|  |_|_|\__|  __/___/|___/|___/ 
                   |_|                  
  </pre>
  <strong>Zero-Dependency Hermes Agent Docker Environment.</strong><br>
  Isolated workspace. Persistent configuration. Local API gateway. Works on Linux, macOS, WSL, and Windows.
</p>

<p align="center">
  <a href="https://github.com/lunaticbugbear/hermes-docker-installer/actions/workflows/ci.yml"><img alt="CI Status" src="https://github.com/lunaticbugbear/hermes-docker-installer/actions/workflows/ci.yml/badge.svg"></a>
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
               |  ~/.omnipod/                                    |
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
|     [ Container: omnipod ]                          /workspace |
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

## Key Features

- 📦 **Isolated Workspace**: Keeps your host machine clean. No Python versions, node packages, or Playwright/Chromium installs clashing with your environment.
- ⚡ **Instant Path Registration**: Registers the `omnipod` command automatically to your shell PATH (`zsh`, `bash`, `fish`) on Linux/macOS, and registers User/Machine environment variables on Windows with `omnipod.cmd`.
- 🔐 **Hardened Security**: The API server binds strictly to `127.0.0.1` by default to prevent exposure. Config files (`.env`) are locked down to `chmod 600`.
- 🔄 **Idempotent Setup**: Container boot script (`bootstrap.sh`) checks for existing configuration files, preventing accidental data overrides.
- 🛠️ **Seamless Command Wrapper**: Control container lifecycles (`start`, `stop`, `restart`, `cli`, `logs`, `shell`) through a simple CLI command.

---

## Why Omnipod exists

Hermes Agent is powerful, but local setup can sprawl quickly: Python toolchains, browser dependencies, shell PATH quirks, Docker availability, and provider credential handling.

Omnipod compresses that into one predictable path:

- keep the host machine clean
- generate a reproducible runtime layout
- preserve persistent Hermes state across rebuilds and restarts
- default to safer networking behavior
- give operators one control surface: `omnipod`

---

## Quick Start

### Linux / macOS / WSL

Execute the installer directly via script pipe:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hermes-docker-installer/main/install.sh)
```

### Windows (PowerShell)

Execute in an elevated or standard PowerShell window:
```powershell
powershell -ExecutionPolicy Bypass -c "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/lunaticbugbear/hermes-docker-installer/main/install.ps1' -OutFile install.ps1; .\install.ps1"
```

*The installer checks dependencies, detects your platform, asks for your provider, API key, and model, and registers the global `omnipod` helper command.*

### Interactive setup flow

During interactive setup, Omnipod asks in this order:

1. which provider / model family you want to use
2. the API key for that provider
3. the exact model name (with a smart default)
4. the local API port

---

## Non-Interactive Automation

Perfect for servers, scripts, CI/CD, or automated virtual machines.

### Unix Shell

```bash
HERMES_NONINTERACTIVE=1 \
OPENROUTER_API_KEY=<OPENROUTER_API_KEY> \
bash install.sh \
  --provider openrouter \
  --model deepseek/deepseek-v4-flash:free \
  --port 8642
```

### Windows PowerShell

```powershell
.\install.ps1 `
  -Provider openrouter `
  -Model deepseek/deepseek-v4-flash:free `
  -OpenRouterApiKey "<OPENROUTER_API_KEY>" `
  -Port 8642
```

---

## Deployment Layout

By default, Omnipod deploys to:
- **Non-root user**: `~/.omnipod/`
- **Root user**: `/usr/local/lib/omnipod/` (with binary linked to `/usr/local/bin/omnipod`)

### File Tree

```text
~/.omnipod/
├── .env                 # API settings, Port variables
├── Dockerfile           # Multi-stage container instruction
├── docker-compose.yml   # Volume mapping and networking definitions
├── bootstrap.sh         # Idempotent runtime setup config helper
├── healthcheck.sh       # Container health monitoring tool
├── bin/
│   ├── omnipod          # Unix control helper
│   ├── omnipod.ps1      # PowerShell control script
│   └── omnipod.cmd      # Windows command CMD wrapper
└── workspace/           # Persistent folder shared with the container
```

---

## Command Reference

Once installed, you can control Omnipod from **any directory** on your host machine:

| Command | Action | Description |
|---|---|---|
| `omnipod start` | Up Stack | Spin up the gateway/API server in the background |
| `omnipod stop` | Stop Stack | Pause container execution |
| `omnipod restart` | Restart Stack | Reload configurations and restart the gateway |
| `omnipod status` | Show Status | View running containers and ports |
| `omnipod cli` | Chat CLI | Open interactive chat console directly inside the container |
| `omnipod logs` | View Logs | Follow tail output logs of the Hermes Agent |
| `omnipod shell` | Shell Exec | Open a bash terminal inside the running container |
| `omnipod update` | Upgrade Stack | Pull the latest changes, rebuild, and update |
| `omnipod url` | Get Host URL | Output the current API Server listening URL |
| `omnipod key` | Get API Key | Output the generated bearer API authorization token |
| `omnipod down` | Shutdown Stack| Stop stack and remove container networks |
| `omnipod reset` | Hard Reset | Wipe containers, networks, and persistent data volumes |

---

## Command Configuration Options

### Linux/macOS CLI options (`install.sh`)

| Option | Default | Description |
|---|---:|---|
| `--dir PATH` | `~/.omnipod` | Target directory for the deployment |
| `--provider NAME` | `openrouter` | AI provider (`openrouter`, `anthropic`, `openai`, `google`, `deepseek`, or `custom`) |
| `--model MODEL` | `deepseek/deepseek-v4-flash:free` | Model target name |
| `--port PORT` | `8642` | Port to bind for the API server |
| `--name NAME` | `omnipod` | Compose stack project name |
| `--browser` | off | Opt-in to install Playwright + Chromium browser environment |
| `--no-start` | off | Build image and files but do not launch stack |
| `--skip-build` | off | Generate config files only; do not start Docker services |
| `--force` | off | Overwrite generated runtime files (keeps `.env` backed up to `.env.bak`) |
| `--uninstall` | off | Bring down stack and run uninstaller routine |

### Windows PowerShell options (`install.ps1`)

| Parameter | Default | Description |
|---|---:|---|
| `-InstallDir PATH` | `$env:USERPROFILE\.omnipod` | Target directory (switches to `%ProgramFiles%\omnipod` for Admin) |
| `-Provider NAME` | `openrouter` | Chosen AI provider |
| `-Model MODEL` | `deepseek/deepseek-v4-flash:free` | Chosen AI model name |
| `-Port PORT` | `8642` | Port to bind |
| `-ProjectName NAME` | `omnipod` | Compose stack project name |
| `-Browser` | off | Include Playwright browser stack |
| `-NoStart` | off | Build files and image but do not start container |
| `-SkipBuild` | off | Generate config files only |
| `-Force` | off | Overwrite files (automatically backs up `.env`) |
| `-Uninstall` | off | Run PowerShell uninstall procedure |

---

## Environment & Secrets

### Provider Credentials

Provide the environment variable for your target model provider:

| Provider | Environment Variable |
|---|---|
| OpenRouter | `OPENROUTER_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |
| OpenAI | `OPENAI_API_KEY` |
| Google Gemini | `GOOGLE_API_KEY` or `GEMINI_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| Custom Endpoint | `CUSTOM_API_KEY` + `CUSTOM_BASE_URL` |

### System Modifiers

| Variable | Default | Purpose |
|---|---:|---|
| `API_SERVER_KEY` | (Random Hex) | Define a static bearer key for API authentication |
| `HERMES_VERSION` | `main` | Pin a specific Hermes Agent branch, tag, or commit hash |
| `HERMES_NONINTERACTIVE=1` | `0` | Prevent installer from prompting inputs on headless systems |

---

## Browser Tooling (Opt-in)

The browser environment (Playwright + Chromium) adds around ~450 MB to the build size and increases installation time. If you need browser automation tools:

Unix:
```bash
bash install.sh --browser
```

PowerShell:
```powershell
.\install.ps1 -Browser
```

---

## Pinning Versions

Omnipod allows pinning specific builds of Hermes Agent to ensure environment stability:

```bash
HERMES_VERSION=v0.5.0 bash install.sh
```

To update an existing pin back to main:
```bash
HERMES_VERSION=main bash install.sh --force
```

---

## Customizing Configurations

If you need to change your keys or model post-installation:
1. Open `~/.omnipod/.env` (or your chosen directory).
2. Edit parameters (`MODEL_NAME`, `OPENROUTER_API_KEY`, etc.).
3. Restart using the omnipod wrapper:
   ```bash
   omnipod restart
   ```

---

## Graceful Uninstallation

Clean up containers, files, and networks securely.

### Shell Uninstaller

```bash
bash uninstall.sh
bash uninstall.sh --remove-data     # Stops stack and removes named volumes
bash uninstall.sh --remove-files    # Stops stack and deletes installation directory
bash uninstall.sh --remove-files --remove-data # Complete system clean
```

### PowerShell Uninstaller

```powershell
.\uninstall.ps1
.\uninstall.ps1 -RemoveData
.\uninstall.ps1 -RemoveFiles
.\uninstall.ps1 -RemoveFiles -RemoveData
```

Defaults are conservative:

- stack shutdown is attempted only when Docker is available
- volumes stay unless data removal is explicitly requested
- files stay unless file removal is explicitly requested

---

## Troubleshooting

### Docker Daemon Not Reachable

Ensure Docker is running on your machine:
- **Linux**: `sudo systemctl start docker` (add user to group via `sudo usermod -aG docker $USER`)
- **macOS**: Launch `Docker.app` from Applications folder.
- **Windows**: Launch `Docker Desktop` from Start Menu.

### Port Conflicts

If the default port `8642` is bound by another service, the installer will suggest free alternative ports. If running non-interactively, pass a free port:
```bash
bash install.sh --port 18642
```

### Rebuild after config changes

Most `.env` changes only need a restart:

```bash
omnipod restart
```

If you changed build-time settings such as browser support or the Hermes version pin:

```bash
omnipod update
```

### Browser tools are missing

Browser automation is opt-in. Re-run with browser support enabled:

```bash
bash install.sh --browser --force
```

---

## Quality gates

Every push validates:

- Bash syntax
- ShellCheck
- PowerShell parser correctness
- generated Compose config validity
- generated helper script syntax
- uninstall safety behavior
- docs sanity
- Docker build + API health smoke test on `main`
- repository hygiene checks for secrets-like patterns and generated artifacts

---

## Repository standards

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contribution and validation expectations
- [`SECURITY.md`](SECURITY.md) — reporting guidance and hardening notes
- [`SUPPORT.md`](SUPPORT.md) — user support expectations and intake checklist
- [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) — community behavior baseline
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — maintainer-facing system design notes
- [`docs/RELEASE_PROCESS.md`](docs/RELEASE_PROCESS.md) — tagging and release publication flow
- [`.editorconfig`](.editorconfig) — formatting baseline across editors
- [`.github/CODEOWNERS`](.github/CODEOWNERS) — ownership defaults
- [`.github/dependabot.yml`](.github/dependabot.yml) — dependency update automation

## Releases

Tagged releases (`v*`) automatically publish installer scripts plus `SHA256SUMS` through GitHub Releases.

Example verification:

```bash
sha256sum -c SHA256SUMS
```

---

## License

Omnipod is open-source software licensed under the [MIT License](LICENSE).
