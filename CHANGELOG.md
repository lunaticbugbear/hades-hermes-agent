# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- `APPROVAL_MODE` env var for tool execution control (manual=ask before each tool, auto=execute freely). Set via `--approval-mode` / `-ApprovalMode` or `APPROVAL_MODE` env. Default: manual.
- Prebuilt Docker image on `ghcr.io/lunaticbugbear/hades-hermes-agent` — installer attempts automatic pull before falling back to local build. Multi-arch (linux/amd64 + linux/arm64).
- Config auto-sync on restart — bootstrap now always regenerates `.env` and `config.yaml` from current host env vars using md5 hash comparison to avoid unnecessary writes.
- Cosign keyless signing of all release artifacts (install.sh, install.ps1, uninstall.sh, uninstall.ps1, SHA256SUMS, sbom.spdx.json) with Rekor transparency log timestamping.
- Cosign-signed container images pushed to ghcr.io during release.
- Trivy vulnerability scan (CRITICAL/HIGH severity) in CI on every `main` push.
- Integration tests in CI: REST API `/v1/models` endpoint check, tools list inside container, config.yaml existence, approval mode flag test.
- GPU passthrough support — `--gpus` flag (install.sh) / `-GpuDevices` parameter (install.ps1) enables NVIDIA GPU access for local model inference. Uses `deploy.resources.reservations.devices` in docker-compose.yml.
- Windows helper scripts: `bin/hades.ps1` (PowerShell) and `bin/hades.cmd` (CMD wrapper) generated alongside `bin/hades` during Windows installs.
- Documented `GATEWAY_ALLOW_ALL_USERS` setting with security guidance in `.env.template`.

### Changed
- CI smoke job now uses Docker Buildx caching (`type=gha`) for faster builds.
- docker-compose.yml now explicitly passes `GATEWAY_ALLOW_ALL_USERS` and `APPROVAL_MODE` environment variables to container.
- `.env.template` extended with `APPROVAL_MODE`, `GPU_DEVICES`, and expanded `GATEWAY_ALLOW_ALL_USERS` documentation.
- `docs/ARCHITECTURE.md` updated to include prebuilt image flow, config auto-sync lifecycle, and Windows helper script generation.

### Fixed
- `hades backup` no longer creates an empty .tar.gz on failure — writes to temp file first, removes on fallback, only finalizes on success.
- `hades restore` now checks container is running before attempting restore, with a clear error message.
- `hades restore` old-format backup (root/.hermes/...) now correctly uses `--strip-components=2` so data lands in the right path.
- bootstrap.sh now creates `.hermes_initialized` sentinel file after migration to prevent re-migration.
- install.ps1 `Resolve-Port` now validates port range (1-65535) before checking contention.
- install.ps1 `bin/hades.ps1` now includes `backup`, `restore`, and `check` commands — parity with the bash helper.
- docs/RELEASE_PROCESS.md replaced brittle line numbers for `ARG HERMES_VERSION` with a search-based instruction.
- ROADMAP.md removed stale "Keep signatures/backstops under planned work" line — cosign shipped in v1.4.0.
- docs/FAQ.md `GATEWAY_ALLOW_ALL_USERS` entry now links to Hermes Gateway docs for user mapping setup.
- `install.ps1` docker-compose.yml template now includes `environment` block for `GATEWAY_ALLOW_ALL_USERS` and `APPROVAL_MODE` (was missing, unlike install.sh).
- `README.md` architecture diagram corrected from `/root/.hermes` to `/home/hermes/.hermes`.
- `uninstall.sh` now auto-detects root install path (`/usr/local/lib/hades`) when running as root, instead of always using `$HOME/.hades`.
- `install.ps1` custom provider now correctly sets default model to `custom-model` on interactive run, matching install.sh behavior.
- `hades check` port extraction in bash helper replaced fragile grep/sed with robust `sed -n 's/^...//p'` to avoid false negatives from comments.
- `hades restore` in both helpers now errors out on failed `docker cp` or `docker exec` instead of silently continuing.
- `uninstall.ps1` now checks `docker compose version` availability before calling `docker compose down`, matching the bash uninstaller.
- `assets/generate_social_preview.py` replaced hardcoded `/home/idx-332/hdi/assets` path with `Path(__file__).parent.resolve()` so the script works for any contributor.
- `install.ps1` `$GoogleApiKey` parameter now falls back to `$env:GEMINI_API_KEY` when `$env:GOOGLE_API_KEY` is unset, matching install.sh behavior.

## [1.4.2] - 2026-06-01

### Changed
- Bumped pinned upstream Hermes Agent version from `v2026.5.29` to `v2026.5.29.2` in `install.sh`, `install.ps1`, and `.env.template`.
- Bumped `github/codeql-action` from `v3` to `v4` in the OpenSSF Scorecard workflow.
- Restructured `README.md` for enterprise clarity and newbie onboarding: table of contents, Requirements section, consolidated value proposition, Security and trust section, and Contributing pointer.

### Removed
- Deleted stale branches (`openai-oss-application-readiness`, `lunaticbugbear-patch-1`, `chore/bump-hermes-v2026.5.29.2`) now subsumed by `main`.

## [1.4.1] - 2026-06-01

### Added
- Added `docs/QUICKSTART.md`, `docs/FAQ.md`, and `docs/GLOSSARY.md` for newcomer onboarding.
- Added `GOVERNANCE.md` documenting roles, decision classes, and release authority.
- Added `CITATION.cff` for citable project metadata.
- Added a question issue template for usage questions.
- Added an OpenSSF Scorecard workflow for supply-chain posture reporting.
- Added `.env.template` documenting every installer environment variable.
- Added CI jobs for workflow linting (actionlint), markdown link checking, and changelog enforcement on sensitive changes.
- Extended Dependabot to cover Docker base images alongside GitHub Actions.

### Changed
- Pinned all GitHub Actions to commit SHAs with version comments for supply-chain integrity.
- Reordered the README quick start so verify-before-install is the primary path and `curl | bash` is the fast path.

### Removed
- Removed synthetic SVG "visual proof" art and its generators in favor of an honest demo-pending note and the CI smoke test.

### Fixed
- Markdown link-check CI job no longer fails on docs that contain no links (rewrote the bash to avoid `pipefail` + `grep` no-match exit collapsing the whole pipeline).
- README and CHANGELOG now correctly state that the daily upstream check files a tracking issue (matches the current workflow behavior).
- Bumped `install.sh` `VERSION` constant to `1.4.0` and added a parallel `$Version` parameter to `install.ps1` so installer self-identification matches the published release.
- `random_hex()` in `install.sh` now falls back through `/dev/urandom` and refuses to generate an `API_SERVER_KEY` if no CSPRNG is available, instead of seeding from an epoch second.
- `.gitignore` now ignores the real generated wrapper paths (`bin/hades`, `bin/hades.ps1`, `bin/hades.cmd`) instead of the historical `omnipod` names.
- `docs/GLOSSARY.md` provider list, workspace path, API-key path, and non-interactive install entries now describe the installer's actual values.
- `docs/QUICKSTART.md` provider example renamed to "Google Gemini" so it matches the installer's `google` value.
- `docs/RELEASE_PROCESS.md` "What gets published" list now includes `sbom.spdx.json`.
- `.env.template` documents `COMPOSE_PROJECT_NAME` and clarifies that `PYTHON_VERSION` and `GATEWAY_ALLOW_ALL_USERS` are honored at build/runtime, not by the installer's host `.env` writer.
- `ROADMAP.md` moves shipped release-integrity items out of "Current priorities" and adds a backlog entry for the demo terminal capture referenced in README and `assets/README.md`.
- Pinned `CITATION.cff` to `version: 1.4.0` with `date-released: 2026-06-01`.

## [1.4.0] - 2026-06-01

### Added
- Added `MAINTAINERS.md` to make ownership, review scope, platform support, and release authority explicit.
- Added `ROADMAP.md` with public priorities, maintainer backlog, and suggested starter issues.
- Added `.gitattributes` to keep shell, docs, workflow, and PowerShell line endings predictable across platforms.
- Added `docs/RELEASE_VERIFICATION.md` with a release verification checklist.
- Added release provenance attestation and an SPDX SBOM to the release workflow.

### Changed
- Reframed `README.md` around reproducible local runtime value, trust signals, visual proof, and evidence links.
- Added a verify-before-install path to the README quick start.
- Expanded issue templates and PR template to collect better reproduction detail, scope, and risk notes.
- Strengthened `SECURITY.md` with disclosure timeline, supported-versions matrix, layered integrity guidance, and scope boundaries.
- Strengthened `SUPPORT.md` with clearer issue routing, triage contract, and support expectations.
- Extended docs sanity checks in CI to require new maintainer docs, README links, and release-trust wording guards.
- Expanded `docs/ARCHITECTURE.md`, `docs/OPERATIONS.md`, and `docs/RELEASE_PROCESS.md` to surface architecture, incident playbooks, and release verification more clearly.

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
- Added daily upstream Hermes release checker workflow (files a tracking issue when new tags appear)

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
