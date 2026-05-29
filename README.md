<div align="center">

# HADES

**One command. A full AI coding agent on your machine.**

No Python setup. No dependency hell. No 45-minute install guides.

```bash
curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh | bash
```

<a href="https://github.com/lunaticbugbear/hades-hermes-agent/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/lunaticbugbear/hades-hermes-agent?style=social"></a>
<a href="https://github.com/lunaticbugbear/hades-hermes-agent/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/lunaticbugbear/hades-hermes-agent/actions/workflows/ci.yml/badge.svg"></a>
<a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg"></a>
<img alt="Platforms" src="https://img.shields.io/badge/Platforms-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-blueviolet">

**Tested across 4 platforms. Security-first defaults. Persistent memory.**

</div>

---

## The problem

You found an open-source AI coding agent that actually works. You go to install it. The README says:

> Install Python 3.12. Build Chromium from source. Set up Playwright. Configure venv. Wire your API key. Fix the path. Fix the permissions. Fix it again after an OS update.

45 minutes later, you are debugging pip conflicts instead of writing code.

## The solution

HADES wraps [Hermes Agent](https://github.com/NousResearch/hermes-agent) (by NousResearch) in a single Docker container. One command installs everything. Your host machine stays clean. Sessions, memory, and config survive restarts.

**Before vs After:**

| Before HADES | After HADES |
|---|---|
| 30-45 min install, per OS | 60 seconds, any OS |
| Python + Chromium + Playwright + venv manually | Docker handles it |
| Config breaks on OS update | Isolated container, nothing to break |
| API keys in shell history | `~/.hades/.env`, chmod 600, never logged |
| Sessions lost on restart | Persistent volume survives rebuilds |

---

## Demo

<!-- Replace with your own GIF/terminal recording -->
```
$ curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh | bash

  ██╗  ██╗ █████╗ ██████╗ ███████╗███████╗
  ██║  ██║██╔══██╗██╔══██╗██╔════╝██╔════╝
  ███████║███████║██║  ██║█████╗  ███████╗
  ██╔══██║██╔══██║██║  ██║██╔══╝  ╚════██║
  ██║  ██║██║  ██║██████╔╝███████╗███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝

  Hermes Agent Docker Environment Script v1.3.0

  [✓] Docker detected
  [✓] Image pulled
  [✓] Container running
  [✓] API healthy on 127.0.0.1:8642

  Run `hades cli` to start coding with AI.
```

```bash
$ hades cli
You: refactor this function to handle edge cases
Hermes: I'll read the file, identify the edge cases, and refactor...
```

> **Tip:** Record your own install GIF with [asciinema](https://asciinema.org/) or [vhs](https://github.com/charmbracelet/vhs) and drop it here.

---

## Quick start

**Linux / macOS / WSL**

```bash
curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh | bash
```

**Windows (PowerShell)**

```powershell
powershell -ExecutionPolicy Bypass -c "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.ps1' -OutFile install.ps1; .\install.ps1"
```

The installer walks you through provider selection, API key input, and model choice. First build takes 1-3 minutes. After that, `hades start` launches in seconds.

---

## Commands

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

---

<details>
<summary><strong>Supported providers</strong></summary>

| Provider | Env var |
|---|---|
| OpenRouter | `OPENROUTER_API_KEY` |
| Anthropic | `ANTHROPIC_API_KEY` |
| OpenAI | `OPENAI_API_KEY` |
| Google Gemini | `GOOGLE_API_KEY` |
| DeepSeek | `DEEPSEEK_API_KEY` |
| Custom | `CUSTOM_API_KEY` + `CUSTOM_BASE_URL` |

</details>

<details>
<summary><strong>Configuration</strong></summary>

Edit `~/.hades/.env`, then `hades restart`. For build-time changes (browser support, version pin): `hades update`.

| Variable | Default | Description |
|---|---|---|
| `MODEL_PROVIDER` | `openrouter` | Provider to use |
| `MODEL_NAME` | `deepseek/deepseek-v4-flash:free` | Model identifier |
| `HERMES_VERSION` | `v2026.5.29` | Pinned Hermes release tag |
| `PYTHON_VERSION` | `3.12-slim-bookworm` | Docker base image variant |
| `GATEWAY_ALLOW_ALL_USERS` | `true` | Allow any API key to act as any user |
| `API_SERVER_KEY` | *(generated)* | Bearer token for the API server |

</details>

<details>
<summary><strong>Non-interactive install</strong></summary>

For CI, servers, or scripted deployments:

```bash
HERMES_NONINTERACTIVE=1 \
OPENROUTER_API_KEY="sk-or-your-key-here" \
bash install.sh --provider openrouter --model deepseek/deepseek-v4-flash:free --port 8642
```

```powershell
.\install.ps1 -Provider openrouter -Model deepseek/deepseek-v4-flash:free -OpenRouterApiKey "sk-or-..." -Port 8642
```

</details>

<details>
<summary><strong>Uninstalling</strong></summary>

```bash
bash uninstall.sh                              # stop stack, keep data
bash uninstall.sh --remove-data                # also drop the volume
bash uninstall.sh --remove-files               # also delete ~/.hades
bash uninstall.sh --remove-files --remove-data # gone
```

</details>

<details>
<summary><strong>Troubleshooting</strong></summary>

| Problem | Fix |
|---|---|
| Docker not found | Linux: `sudo systemctl start docker`. macOS: open Docker.app. Windows: open Docker Desktop. |
| Port 8642 in use | `hades stop` or install with `--port 18642` |
| Config changes not applied | `hades restart` (or `hades update` for build-time changes) |
| Browser tools missing | `bash install.sh --browser --force` browser is opt-in (~450 MB) |

</details>

---

## How it works

```text
 HOST                                     CONTAINER
+------------------------+      +-----------------------------+
| ~/.hades/              |      | hades                       |
|   .env                 |      |   hermes gateway run        |
|   docker-compose.yml   |      |   API: 127.0.0.1:8642       |
|   workspace/  <--------+------+-> /workspace                |
|                        |      |                             |
+------------------------+      |   /root/.hermes <-----------+-- volume
                                |   (sessions, memory,        |
                                |    skills, config)          |
                                +-----------------------------+
```

- **Workspace** is bind-mounted for direct file access
- **Hermes state** (sessions, memory, skills, config) lives in a named Docker volume — survives container rebuilds
- **API** binds to localhost only — never exposed to network

---

## CI pipeline

Every push validates: bash syntax, ShellCheck, PowerShell parser, Compose config, generated helper scripts, uninstall safety, docs sanity, and repo hygiene. Docker build + API health probe runs on `main`.

A daily workflow checks for new [Hermes Agent](https://github.com/NousResearch/hermes-agent) releases and opens a PR to bump the version pin automatically.

## Docs

- [Architecture](docs/ARCHITECTURE.md) — runtime layout, lifecycle, security model
- [Operations](docs/OPERATIONS.md) — triage playbook, maintainer tasks, recovery
- [Release Process](docs/RELEASE_PROCESS.md) — tagging and publishing
- [Contributing](CONTRIBUTING.md) — validation and review expectations
- [Security](SECURITY.md) — reporting and hardening

## License

[MIT](LICENSE)

---

<div align="center">

**Built by [@lunaticbugbear](https://github.com/lunaticbugbear)**

*Because setting up AI agents should not require a CS degree.*

</div>
