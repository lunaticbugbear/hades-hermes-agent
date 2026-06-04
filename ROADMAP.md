# Roadmap

HADES is already usable as a local Docker wrapper for Hermes Agent. The roadmap focuses on making it more reliable, easier to audit, and safer to maintain as an OSS installer project.

## Current priorities

### Cross-platform installer reliability

- Keep `install.sh` and `install.ps1` behavior aligned.
- Preserve non-interactive install for CI and scripted use.
- Improve Windows, WSL, macOS, and Linux edge-case coverage.
- Make installer failure messages actionable for non-expert users.

### Release integrity and verification

- Keep release assets easy to verify.
- Document how users can validate downloaded installers.

Already shipped in `v1.4.0`:
- **Cosign keyless signing** — container images and installer artifacts are signed, verification documented in `docs/RELEASE_VERIFICATION.md`.
- Published checksums and a documented GitHub artifact provenance attestation path.
See `CHANGELOG.md` and `docs/RELEASE_VERIFICATION.md`.

### Smoke tests and health checks

- Expand generated-runtime validation.
- Keep Docker Compose config validation in CI.
- Add stronger health-check guidance for local installs.
- Track regressions around port binding, generated wrappers, and API keys.

### Backup, rollback, and reset safety

- Document safe recovery paths before destructive reset.
- Keep uninstall conservative by default.
- Make data-loss commands explicit and hard to trigger accidentally.
- Improve operator docs for broken installs and bad releases.

### Documentation and troubleshooting

- Keep README focused on first-use success.
- Keep deep operational docs in `docs/`.
- Add examples for provider configuration and scripted installs.
- Keep support/security paths clear and separate.

## Maintainer backlog

These are good candidates for contributor or maintainer work because they are concrete, testable, and useful to all users:

1. **Expand Windows/WSL validation**
   - Add scripted PowerShell parser checks and generated-wrapper validation.
   - Document the exact Docker Desktop / WSL assumptions.
   - Add regression cases for path registration and profile updates.

2. **Improve installer idempotency tests**
   - Test reinstall with existing `~/.hades` files.
   - Test `--force` regeneration behavior.
   - Test uninstall paths that keep data vs remove data.

3. **Add backup and rollback docs**
   - Document how to preserve the Hermes Docker volume before reset.
   - Document recovery from a bad release.
   - Add commands that avoid leaking secrets.

4. **Improve provider configuration examples**
   - Add safe examples for OpenRouter, Anthropic, OpenAI, Gemini, DeepSeek, and custom endpoints.
   - Keep examples secret-free.
   - Clarify which settings require `hades restart` vs `hades update`.

## Good first issues

Suggested public issue titles:

- `docs: add provider configuration examples`
- `docs: add Docker volume backup and restore guide`
- `docs: record a real terminal capture of the install/runtime flow`
- `ci: validate generated Windows wrapper metadata`
- `release: document cosign-based asset verification`
- `tests: cover reinstall with existing ~/.hades config`

## Non-goals

- Hosting a public Hermes service.
- Collecting user telemetry by default.
- Replacing Hermes Agent internals.
- Exposing the local API to the network by default.
