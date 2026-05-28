# HADES
<strong>Hermes Agent Docker Environment Script</strong><br>
Isolated workspace. Persistent state. One command. Linux, macOS, WSL, Windows.

<br>

<a href="https://github.com/lunaticbugbear/hades-hermes-agent/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/lunaticbugbear/hades-hermes-agent/actions/workflows/ci.yml/badge.svg"></a>
<a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg"></a>
<img alt="Docker" src="https://img.shields.io/badge/runtime-Docker-2496ED">
<img alt="Platforms" src="https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-blueviolet">

<br><br>

<img src="assets/demo.svg" alt="HADES Terminal Demo" width="700">

</div>

---

Hermes Agent is powerful. Getting it running locally is not — Python version conflicts, Chromium dependency chains, shell PATH juggling, provider credential plumbing.

HADES wraps all of that into one installer command. The host stays clean. State survives rebuilds. You get a single control surface: `hades`.

## Environment notes

The installer checks for Docker automatically and will try to install or start it when possible:

- **Linux**: attempts Docker Engine install/start
- **macOS**: attempts Docker Desktop install/start
- **Windows PowerShell**: attempts Docker Desktop install/start
- **WSL2 (running `install.sh` inside your distro)**: attempts Docker Engine install inside WSL
- **Git Bash / MSYS / Cygwin on Windows**: use `install.ps1` instead

You do not need to preinstall Docker manually unless automatic setup fails or your environment blocks it.

Notes:
- The one-line Unix install command still needs `bash` and `curl` to be present before the script can start.
- If you prefer Docker Desktop on WSL instead of a direct Docker Engine install inside the distro, use the native Windows PowerShell installer path.
- You still need network access plus an API key for your chosen model provider.

## Install

**Linux / macOS / WSL**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh)

# Or download and inspect first:
# curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh -o install.sh
# bash install.sh
```

**Windows (PowerShell)**

```powershell
powershell -ExecutionPolicy Bypass -c "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.ps1' -OutFile install.ps1; .\install.ps1"

# Or download and inspect first:
# Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.ps1' -OutFile install.ps1
# .\install.ps1
```

The interactive setup flow usually takes about a minute. First-time image builds may take longer depending on Docker, network speed, and whether browser tooling is enabled.

## Quick reference

```bash
hades start          # spin up
hades cli            # open Hermes chat
hades logs           # follow agent output
hades shell          # bash into the container
hades restart        # reload after config changes
hades update         # rebuild image
hades stop           # pause
hades down           # stop + remove networks
hades reset          # nuclear: wipe everything
```

More details:
- helper commands are available via `hades help`
- installer flags: `bash install.sh --help` or `Get-Help .\install.ps1`
- maintainer runbook: [docs/OPERATIONS.md](docs/OPERATIONS.md)

## Providers

| Provider | Env var |
|---|---|
| OpenRouter | `OPENROUTER_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |
| OpenAI | `OPENAI_API_KEY` |
| Google Gemini | `GOOGLE_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| Custom | `CUSTOM_API_KEY` + `CUSTOM_BASE_URL` |

## Config

Edit `~/.hades/.env`, then `hades restart`. If you changed build-time settings (browser support, Hermes version pin): `hades update`.

## Uninstalling

```bash
bash uninstall.sh                       # stop stack, keep data
bash uninstall.sh --remove-data         # also drop the volume
bash uninstall.sh --remove-files        # also delete ~/.hades
bash uninstall.sh --remove-files --remove-data  # gone
```

```powershell
.\uninstall.ps1 -RemoveFiles -RemoveData
```

## Non-interactive install

For CI, servers, or scripted setups:

```bash
HERMES_NONINTERACTIVE=1 \
OPENROUTER_API_KEY="sk-or-your-key-here" \
bash install.sh --provider openrouter --model deepseek/deepseek-v4-flash:free --port 8642
```

```powershell
.\install.ps1 -Provider openrouter -Model deepseek/deepseek-v4-flash:free -OpenRouterApiKey "sk-or-..." -Port 8642
```

## Architecture

```text
 HOST                                     CONTAINER
┌────────────────────────┐      ┌─────────────────────────────┐
│ ~/.hades/              │      │ hades                       │
│   .env                 │      │   hermes gateway run        │
│   docker-compose.yml   │      │   API: 127.0.0.1:8642       │
│   workspace/  ◄────────┼──────┼─► /workspace                │
│                        │      │                             │
└────────────────────────┘      │   /root/.hermes ◄───────────┼── volume
                                │   (sessions, memory,        │
                                │    skills, config)          │
                                └─────────────────────────────┘
```

Workspace is bind-mounted. Hermes state lives in a named Docker volume — it survives rebuilds and restarts.

## Troubleshooting

| Problem | Fix |
|---|---|
| Docker not found | Linux: `sudo systemctl start docker`. macOS: open Docker.app. Windows: open Docker Desktop. |
| Port 8642 in use | `hades stop` or install with `--port 18642` |
| Config changes not applied | `hades restart` (or `hades update` for build-time changes) |
| Browser tools missing | `bash install.sh --browser --force` — browser is opt-in (~450 MB) |

## CI

Every push validates: bash syntax, ShellCheck, PowerShell parser, Compose config, generated helper scripts, uninstall safety, docs sanity, repo hygiene. Docker build + API health probe runs on `main`.

## Docs

- [Architecture](docs/ARCHITECTURE.md) — runtime layout, lifecycle, security model
- [Operations](docs/OPERATIONS.md) — triage playbook, maintainer tasks, recovery
- [Release Process](docs/RELEASE_PROCESS.md) — tagging and publishing
- [Contributing](CONTRIBUTING.md) — validation and review expectations
- [Security](SECURITY.md) — reporting and hardening
- [Support](SUPPORT.md) — filing useful bug reports

## License

[MIT](LICENSE)
