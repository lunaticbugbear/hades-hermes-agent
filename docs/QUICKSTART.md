# Quickstart

Get HADES running in three steps. No deep knowledge required.

## 1. Make sure Docker is running

| OS | What to check |
|---|---|
| Linux | `docker info` returns without error |
| macOS | Docker Desktop icon shows "Docker Desktop is running" |
| Windows | Docker Desktop is open and shows "Engine running" |
| WSL | Docker Desktop's WSL integration is enabled for your distro |

If Docker isn't installed yet, install Docker Engine (Linux) or Docker Desktop (macOS, Windows, WSL) from `https://docs.docker.com/get-docker/`.

## 2. Run the installer

**Linux, macOS, or WSL**

```bash
curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh | bash
```

**Windows (PowerShell)**

```powershell
powershell -ExecutionPolicy Bypass -c "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.ps1' -OutFile install.ps1; .\install.ps1"
```

The installer asks three questions:
- which provider you want to use (OpenRouter, Anthropic, OpenAI, Google Gemini, DeepSeek, or a custom endpoint)
- your API key for that provider
- which model to default to

That's all. The installer downloads the runtime image, generates `~/.hades/`, and adds the `hades` command to your shell.

## 3. Use it

```bash
hades start          # spin up the runtime
hades cli            # open the Hermes chat
hades logs           # watch what the agent is doing
hades check          # verify container health
hades stop           # pause everything
```

That is the full daily loop.

## Verify before installing (optional but recommended)

If you want to inspect the installer before running it:

```bash
curl -fsSLO https://raw.githubusercontent.com/lunaticbugbear/hades-hermes-agent/main/install.sh
sha256sum install.sh
less install.sh
bash install.sh --help
```

For a published release, you can also verify checksums and the GitHub provenance attestation:

```bash
gh release download v1.4.2 -R lunaticbugbear/hades-hermes-agent
sha256sum -c SHA256SUMS
gh attestation verify install.sh -R lunaticbugbear/hades-hermes-agent
```

## Where to go next

- Common questions → [`docs/FAQ.md`](FAQ.md)
- Term you don't recognize → [`docs/GLOSSARY.md`](GLOSSARY.md)
- Something broke → [`docs/OPERATIONS.md`](OPERATIONS.md)
- You want to contribute → [`CONTRIBUTING.md`](../CONTRIBUTING.md)
