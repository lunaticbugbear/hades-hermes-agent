<div align="center">

# HADES

**One command. A reproducible local AI coding agent runtime.**

HADES is a cross-platform Docker installer and runtime wrapper for [Hermes Agent](https://github.com/NousResearch/hermes-agent). It turns fragile local AI-agent setup into a reproducible one-command workflow with persistent state, localhost-only API access, and unified CLI operations.

**New in this release:** approval mode for tool execution control, config auto-sync on restart, prebuilt Docker images on ghcr.io with auto-pull and fallback to local build, Cosign-signed multi-arch builds (amd64 + arm64), GPU passthrough support, Windows helper scripts, vulnerability scanning in CI, and integration tests.

```bash
curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh | bash
```

<a href="https://github.com/lunaticbugbear/hades-hermes-agent/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/lunaticbugbear/hades-hermes-agent?style=social"></a>
<a href="https://github.com/lunaticbugbear/hades-hermes-agent/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/lunaticbugbear/hades-hermes-agent/actions/workflows/ci.yml/badge.svg"></a>
<a href="https://github.com/lunaticbugbear/hades-hermes-agent/actions/workflows/scorecard.yml"><img alt="OpenSSF Scorecard" src="https://github.com/lunaticbugbear/hades-hermes-agent/actions/workflows/scorecard.yml/badge.svg"></a>
<a href="https://github.com/lunaticbugbear/hades-hermes-agent/releases"><img alt="Release" src="https://img.shields.io/github/v/release/lunaticbugbear/hades-hermes-agent"></a>
<a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg"></a>
<a href="SECURITY.md"><img alt="Security policy" src="https://img.shields.io/badge/security-policy-blue"></a>
<img alt="Platforms" src="https://img.shields.io/badge/Platforms-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-blueviolet">

**Exact defaults: localhost-only API, opt-in browser tooling, conservative uninstall, persistent Docker volume.**

**Verified by CI: bash, PowerShell, docs sanity, Docker smoke.**

</div>

---

## Contents

- [Why HADES](#why-hades)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Commands](#commands)
- [Configuration and options](#configuration-and-options)
- [Architecture](#architecture)
- [Security and trust](#security-and-trust)
- [CI pipeline](#ci-pipeline)
- [Docs](#docs)
- [Contributing](#contributing)
- [License](#license)

---

## Why HADES

Open-source coding agents are powerful, but the local setup is the hard part: Python versions, Chromium, Playwright, virtualenvs, API keys, OS-specific paths, and configs that break after an OS update. You spend 45 minutes fighting environment drift instead of writing code.

HADES wraps [Hermes Agent](https://github.com/NousResearch/hermes-agent) in Docker so one command installs everything. Your host stays clean. Sessions, memory, and config survive restarts.

| Without HADES | With HADES |
|---|---|
| 30-45 min install, different on every OS | One command, same workflow on Linux/macOS/Windows/WSL |
| Install Python, Chromium, Playwright, venv by hand | Docker handles every runtime dependency |
| Config breaks on OS update | Isolated container runtime |
| API keys leak into shell history | `~/.hades/.env`, `chmod 600`, never logged on purpose |
| Sessions lost on restart | Persistent Docker volume survives rebuilds |

New to the project? Jump to [Quickstart](docs/QUICKSTART.md), then the [FAQ](docs/FAQ.md). Unsure about a term? See the [Glossary](docs/GLOSSARY.md).

## Requirements

- **Docker** — Docker Engine (Linux) or Docker Desktop (macOS, Windows, WSL). [Install guide](https://docs.docker.com/get-docker/).
- **A shell** — bash on Linux/macOS/WSL, or PowerShell on Windows.
- **A model provider API key** — OpenRouter, Anthropic, OpenAI, Google Gemini, DeepSeek, or any OpenAI-compatible endpoint.
- **Disk** — roughly 1.5 GB for the base image; about 2 GB if you enable browser tooling.

You do **not** need Python, Chromium, or Playwright on the host. The container owns those.

---

## Quick start

**Recommended: verify, then install**

```bash
curl -fsSLO https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh
less install.sh
bash install.sh
```

After a published release, verify the asset against checksums and the build provenance attestation:

```bash
gh release download v1.4.2 -R lunaticbugbear/hades-hermes-agent
sha256sum -c SHA256SUMS
gh attestation verify install.sh -R lunaticbugbear/hades-hermes-agent

# Cosign verification (container image)
cosign verify ghcr.io/lunaticbugbear/hades-hermes-agent:v1.4.2 \
  --certificate-identity-regexp "https://github.com/lunaticbugbear/hades-hermes-agent/.github/workflows/release.yml@refs/tags/" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

**Fast path (Linux / macOS / WSL)**

```bash
curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh | bash
```

**Windows (PowerShell)**

```powershell
powershell -ExecutionPolicy Bypass -c "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.ps1' -OutFile install.ps1; .\install.ps1"
```

The installer walks you through provider selection, API key input, and model choice. On first run, it attempts to pull a prebuilt image from `ghcr.io/lunaticbugbear/hades-hermes-agent` (tagged with the pinned Hermes version). If no prebuilt image is available, it falls back to local Docker build. First build takes 1-3 minutes; a prebuilt pull takes seconds. After that, `hades start` launches in seconds.

---

## Commands

```bash
hades start          # spin up
hades cli            # open Hermes chat
hades logs           # follow agent output
hades shell          # bash into the container
hades restart        # reload after config changes
hades update         # rebuild/pull image
hades stop           # pause
hades down           # stop + remove networks
hades reset          # destructive: wipe persistent Hermes data
```

Install with `--gpus all` (bash) or `-Gpus all` (PowerShell) for GPU passthrough to local model inference (requires nvidia-container-toolkit).

---

## Configuration and options

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

Edit `~/.hades/.env`, then `hades restart`. For build-time changes such as browser support or version pins, run `hades update`.

| Variable | Default | Description |
||---|---|---|
| `MODEL_PROVIDER` | `openrouter` | Provider to use |
| `MODEL_NAME` | `deepseek/deepseek-v4-flash:free` | Model identifier |
| `HERMES_VERSION` | `v2026.5.29.2` | Pinned Hermes release tag |
| `PYTHON_VERSION` | `3.12-slim-bookworm` | Docker base image variant |
| `GATEWAY_ALLOW_ALL_USERS` | `true` | Allow any API key to act as any user |
| `APPROVAL_MODE` | `manual` | Tool execution mode: `manual` (ask before each tool) or `auto` (execute freely) |
| `GPU_DEVICES` | (empty) | GPU devices to pass to container: `all`, `device=0`, etc. Requires nvidia-container-toolkit |
| `API_SERVER_KEY` | generated | Bearer token for the API server |

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
| Config changes not applied | `hades restart` or `hades update` for build-time changes |
| Browser tools missing | `bash install.sh --browser --force`; browser support is opt-in and adds roughly 450 MB |

</details>

---

## Architecture

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

- **Workspace** is bind-mounted for direct file access.
- **Hermes state** lives in a named Docker volume and survives container rebuilds.
- **API** binds to localhost only by default.

---

## Security and trust

HADES is installer software, so the defaults lean safe and every release is verifiable.

- **Local-only API.** The gateway binds to `127.0.0.1` by default and is not exposed to your network.
- **Secrets stay on disk, not in history.** Provider keys live in `~/.hades/.env` (`chmod 600` on Unix) and are never logged on purpose.
- **Opt-in browser tooling.** Chromium/Playwright is off unless you pass `--browser`, keeping the attack surface small.
- **Conservative uninstall.** `uninstall.sh` keeps your data unless you explicitly pass `--remove-data` / `--remove-files`.
- **Verifiable releases.** Every release ships `SHA256SUMS`, an SPDX SBOM, and a GitHub build provenance attestation. Release artifacts and container images are cosign-signed with Rekor transparency log timestamps. Verify with the commands in [Quick start](#quick-start) or the full checklist in [`docs/RELEASE_VERIFICATION.md`](docs/RELEASE_VERIFICATION.md).
- **Hardened supply chain.** All GitHub Actions are pinned to commit SHAs, secret scanning and push protection are enabled, and an OpenSSF Scorecard workflow runs on `main`.

Found a vulnerability? Follow [`SECURITY.md`](SECURITY.md) — do not open a public issue.

---

## CI pipeline

Every push validates bash syntax, ShellCheck, PowerShell parsing, Compose config, generated helper scripts, uninstall safety, docs sanity, and repo hygiene. Docker build + API health probe runs on `main` with Buildx caching. Integration tests verify the `/v1/models` endpoint, tools list, config.yaml presence, and approval mode flag inside the container. A Trivy vulnerability scan (CRITICAL and HIGH severity) runs on every `main` push.

A daily workflow checks for new Hermes Agent releases and opens or updates a tracking issue when the pinned version is behind upstream.

## Docs

**New here?** Start with [Quickstart](docs/QUICKSTART.md), then [FAQ](docs/FAQ.md). Hit a term you don't know? [Glossary](docs/GLOSSARY.md).

- [Quickstart](docs/QUICKSTART.md) — three steps to a running install
- [FAQ](docs/FAQ.md) — common questions, plain answers
- [Glossary](docs/GLOSSARY.md) — what HADES jargon means
- [Architecture](docs/ARCHITECTURE.md) — runtime layout, lifecycle, security model
- [Operations](docs/OPERATIONS.md) — triage playbook, maintainer tasks, recovery
- [Release Process](docs/RELEASE_PROCESS.md) — tagging, publishing, verification
- [Release Verification](docs/RELEASE_VERIFICATION.md) — asset verification checklist
- [Roadmap](ROADMAP.md) — public backlog and maintainer priorities
- [Governance](GOVERNANCE.md) — how decisions get made
- [Maintainers](MAINTAINERS.md) — ownership, review scope, platform expectations
- [Contributing](CONTRIBUTING.md) — validation and review expectations
- [Support](SUPPORT.md) — support path and issue requirements
- [Security](SECURITY.md) — reporting, hardening, supported versions
- [Changelog](CHANGELOG.md) — release history

## Contributing

Issues and pull requests are welcome. Before opening a PR, read [`CONTRIBUTING.md`](CONTRIBUTING.md) for the local validation steps and review expectations, and [`GOVERNANCE.md`](GOVERNANCE.md) for how changes are decided. Good first issues are listed in the [Roadmap](ROADMAP.md).

## License

[MIT](LICENSE)

---

<div align="center">

**Built by [@lunaticbugbear](https://github.com/lunaticbugbear)**

*Because setting up AI agents should not require a CS degree.*

</div>
