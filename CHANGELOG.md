# Changelog

All notable changes to this project will be documented in this file.

## [1.3.0] - 2026-05-29

### Security
- Replaced `change-me` API_SERVER_KEY fallback with hard failure — container will not start without a key
- Made `GATEWAY_ALLOW_ALL_USERS` configurable via env var (defaults to true for backward compat)
- Replaced `source .env` in `hades url`/`hades key` commands with grep to prevent code execution

### Changed
- Pinned `HERMES_VERSION` to `v2026.5.29` instead of tracking `main` — prevents surprise breakage from upstream changes
- Added `PYTHON_VERSION` build arg to Dockerfile for reproducible image builds (default: `3.12-slim-bookworm`)
- Improved macOS Docker Desktop install: added download timeout (300s) and empty-file validation
- Replaced misleading `/dev/tcp` healthcheck fallback with explicit error message
- Fixed variable scoping: replaced `declare` with `printf -v` for API key assignment in interactive mode
- Aligned VERSION constant to match changelog
- PS1 `Safe-Write` now backs up existing files before overwrite (matches bash behavior)
- Added daily upstream Hermes release checker workflow (auto-PR when new tags appear)

## [1.2.0] - 2026-05-28

- Renamed project from Omnipod to **HADES** (Hermes Agent Docker Environment Script). Install directory is now `~/.hades/`, control command is now `hades`.
- Modernized release pipeline to use native GitHub CLI (`gh release`) instead of deprecated Node actions.
- Introduced repository social preview assets.
- Refactored all documentation to be concise and direct.
- Restructured README to prioritize installation and usage, moving deep-dives to `docs/`.

## [1.1.0] - 2026-05-28

- Added isolation guards (`PYTHONPATH` / `PYTHONHOME`) to prevent host environment bleed during builds.
- Added path registration for login shells (bash, zsh, fish).
- Built Windows integration with `hades.cmd` wrapper and PowerShell profile path registration.
- Switched interactive prompts to raw TTY `/dev/tty` so piping (`curl | bash`) works reliably.
- Hardened default API bind to `127.0.0.1` instead of `0.0.0.0`.
- Added uninstaller flags (`--dir`, `--remove-data`, `--remove-files`).
- Implemented `HERMES_VERSION` support for pinning specific upstream commits.

## [1.0.0] - 2026-05-27

- Initial release.
- Added cross-platform Docker scaffolding (Linux, macOS, Windows, WSL).
- Implemented multi-stage Dockerfile separating build and runtime.
- Built interactive setup flow for providers, models, and port allocation.
- Created `hades` command wrapper for container lifecycle management.
- Implemented automatic host dependency checks (Docker Daemon availability).
