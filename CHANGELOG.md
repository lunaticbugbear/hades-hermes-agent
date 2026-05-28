# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - Unreleased

- Modernized release pipeline to use native GitHub CLI (`gh release`) instead of deprecated Node actions.
- Introduced repository social preview assets.
- Refactored all documentation to be concise and direct.
- Restructured README to prioritize installation and usage, moving deep-dives to `docs/`.

## [1.1.0] - 2026-05-28

- Added isolation guards (`PYTHONPATH` / `PYTHONHOME`) to prevent host environment bleed during builds.
- Added path registration for login shells (bash, zsh, fish).
- Built Windows integration with `omnipod.cmd` wrapper and PowerShell profile path registration.
- Switched interactive prompts to raw TTY `/dev/tty` so piping (`curl | bash`) works reliably.
- Hardened default API bind to `127.0.0.1` instead of `0.0.0.0`.
- Added uninstaller flags (`--dir`, `--remove-data`, `--remove-files`).
- Implemented `HERMES_VERSION` support for pinning specific upstream commits.

## [1.0.0] - 2026-05-27

- Initial release.
- Added cross-platform Docker scaffolding (Linux, macOS, Windows, WSL).
- Implemented multi-stage Dockerfile separating build and runtime.
- Built interactive setup flow for providers, models, and port allocation.
- Created `omnipod` command wrapper for container lifecycle management.
- Implemented automatic host dependency checks (Docker Daemon availability).
