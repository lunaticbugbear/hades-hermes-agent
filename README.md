# Omnipod

Run Hermes Agent in Docker. Keep your host machine clean.
Works on Linux, macOS, WSL, and Windows.

## Quick start

**Linux / macOS / WSL**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lunaticbugbear/hermes-docker-installer/main/install.sh)
```

**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -c "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/lunaticbugbear/hermes-docker-installer/main/install.ps1' -OutFile install.ps1; .\install.ps1"
```

## Usage

Run `omnipod` from any directory.

| Command | Action |
|---|---|
| `omnipod start` | Start container in background |
| `omnipod stop` | Stop container |
| `omnipod cli` | Open Hermes chat |
| `omnipod shell` | Open bash inside container |
| `omnipod logs` | View logs |
| `omnipod update` | Pull latest and rebuild |

## Config & Data

- **Config:** `~/.omnipod/.env` (Edit, then run `omnipod restart`)
- **Data:** Stored in a Docker volume. Survives container rebuilds.
- **Files:** `/workspace` inside the container mirrors your current host directory.

## Advanced options

- Need browser automation? Run `bash install.sh --browser` (adds ~450MB).
- Non-interactive mode (for scripts/CI): set `HERMES_NONINTERACTIVE=1` and pass flags like `--port 8642` and `--provider openrouter`.

## Docs

- [Architecture & Platform notes](docs/ARCHITECTURE.md)
- [Uninstall, Troubleshooting & Recovery](docs/OPERATIONS.md)
- [Security](SECURITY.md)
- [Contributing](CONTRIBUTING.md)
