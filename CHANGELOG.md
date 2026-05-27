# Changelog

## 1.1.3 (2026-05-28)
- Upgraded installer robustness to NousResearch-grade standards.
- Added environment isolation guards (`PYTHONPATH`, `PYTHONHOME`) to prevent builder shadowing.
- Switched interactive prompts to use raw TTY descriptor probes (`/dev/tty`), supporting piping via `curl | bash` safely.
- Added FHS install layout directory logic for `root` installations (`/usr/local/lib/omnipod` + `/usr/local/bin`).
- Integrated automatic login shell detection (`bash`, `zsh`, `fish`) and PATH registration for bin helpers.
- Added path registration and `omnipod.cmd` wrapper script support for Windows environments.
- Implemented temporary log capture for Docker builds to report failures cleanly instead of silent aborts.

## 1.1.2 (2026-05-27)
- Fixed installer `--uninstall` / `-Uninstall` so it never bootstraps Docker before uninstall checks.
- Bound generated API port to `127.0.0.1` by default.
- Removed fixed Compose `container_name` to avoid multi-install conflicts.
- Kept generated Dockerfile browser layer default opt-in/off.
- Added uninstaller CLI flags: `--dir`, `--remove-data`, `--remove-files`.
- Hardened CI guard for uninstall mode.
- Made `--skip-build` / `-SkipBuild` skip port collision checks because no service starts.

## 1.1.1 (2026-05-27)
- Added auto-install/auto-start Docker support for Windows and Linux/macOS.
- Installer detects OS and uses appropriate method (get.docker.com, brew, winget).
- Added logic for starting Docker daemon if it's found but idle.
- CI: Added smoke test and browser opt-in verification.

## 1.1.0 (2026-05-27)
- Multi-stage Dockerfile (builder + runtime).
- Browser (Playwright/Chromium) moved to `--browser` opt-in flag.
- Added pinning of Hermes Agent version via `HERMES_VERSION` env/flag.
- Full parity between `install.sh` and `install.ps1`.
- Added robust cleanup scripts (`uninstall.sh`, `uninstall.ps1`).
- API server config improvements and key passing logic.
- CI validation for shell, powershell, compose files, and generated helper scripts.

## 1.0.0 (2026-05-27)
- Initial release.
- Docker-based installer for Linux/macOS/WSL/PowerShell.
- Basic provider/model wizard.
- API server port collision detection.
- Helper script generation for CLI, logs, and updates.
