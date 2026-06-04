# Release Process

This document describes the end-to-end workflow for cutting a HADES release.
The release is triggered automatically by pushing a `v*` tag, or manually via
GitHub Actions `workflow_dispatch`.

## Versioning

Two version numbers are always in play — keep them straight:

| Version | What it tracks | Example | Where defined |
|---------|---------------|---------|---------------|
| **HADES release version** | The HADES project itself | `v1.4.2` | `VERSION` in `install.sh` line 37, `$Version` in `install.ps1` line 8 |
| **Hermes Agent version** | The upstream Nous Research agent bundled inside | `v2026.5.29.2` | `HERMES_VERSION` in `install.sh` line 55, `$HermesVersion` in `install.ps1` line 24 |

They are independent — a HADES patch release (e.g. `v1.4.3`) can bundle the same
Hermes Agent version as the previous release, or a newer one.

## Step-by-step release workflow

### 1. Update the HADES version constant

Bump `VERSION` in both installer scripts:

**install.sh** (line 37):
```bash
VERSION="1.4.2"  # change to your new version
```

**install.ps1** (line 8):
```powershell
[string]$Version = '1.4.2',  # change to your new version
```

If you are also bumping the bundled Hermes Agent version:

**install.sh** (line 55):
```bash
HERMES_VERSION="${HERMES_VERSION:-v2026.5.29.2}"  # update tag
```

**install.ps1** (line 24):
```powershell
[string]$HermesVersion = $(if ($env:HERMES_VERSION) { $env:HERMES_VERSION } else { 'v2026.5.29.2' }),
```

Also update `ARG HERMES_VERSION` in the inline Dockerfile inside both installers
(search for `ARG HERMES_VERSION` in each file).

### 2. Update CHANGELOG.md

Add a new version entry under `## [Unreleased]`. Follow the existing format:

```markdown
## [x.y.z] - YYYY-MM-DD

### Added
- ...

### Changed
- ...

### Fixed
- ...
```

Then add a compare link at the bottom of the file (the oldest entry already has one
you can copy the pattern from).

### 3. Commit and push

```bash
git add -A
git commit -m "chore: bump version to v1.4.2"
git push origin main
```

Wait for CI (`ci.yml`) to go green on `main`.

### 4. Tag the release

```bash
# Create a signed or annotated tag
git tag v1.4.2

# Push the tag — this triggers release.yml
git push origin v1.4.2
```

The `release.yml` workflow is triggered by `push` on any `v*` tag. It will:

1. Accept the tag as `TAG_NAME` and default `HERMES_VERSION` to `v2026.5.29.2`.
2. Run `install.sh` with `--skip-build --force` to generate the Docker build context.
3. Build a **multi-arch Docker image** (`linux/amd64` + `linux/arm64`) and push to
   `ghcr.io/lunaticbugbear/hades-hermes-agent` with tags:
   - `vX.Y.Z` (full semver)
   - `X.Y` (major.minor)
   - `latest`
   - `hermes-$HERMES_VERSION`
4. Sign the container image with **cosign** (keyless, Rekor transparency log).
5. Generate an **SBOM** (`syft dir:dist -o spdx-json`).
6. Sign all installer artifacts (`install.sh`, `install.ps1`, `uninstall.sh`,
   `uninstall.ps1`, `SHA256SUMS`, `sbom.spdx.json`) with **cosign sign-blob**.
7. Publish a **GitHub Release** with all artifacts attached.

### 5. (Alternative) Manual trigger via workflow_dispatch

If you need to re-publish an existing tag or specify a different Hermes version:

1. Go to **Actions > release > Run workflow**.
2. Set `tag` to the existing `v*` tag (required).
3. Optionally override `hermes_version` (default: `v2026.5.29.2`).
4. Click **Run workflow**.

This is useful for:
- Re-releasing a tag after a CI fix
- Cutting a release with a newer Hermes Agent without modifying installer defaults
- Testing the release pipeline before tagging

### 6. Verify the release artifacts

1. Navigate to https://github.com/lunaticbugbear/hades-hermes-agent/releases
2. Confirm the new release appears with the expected tag name.
3. Verify the release includes all expected assets:
   - `install.sh`, `install.ps1`, `uninstall.sh`, `uninstall.ps1`
   - `SHA256SUMS` and `SHA256SUMS.sig`
   - `sbom.spdx.json` and `sbom.spdx.json.sig`
   - `.sig` files for each installer
   - `README.md`, `LICENSE`, `CHANGELOG.md`, `SECURITY.md`, `SUPPORT.md`
4. Run the verification commands from `docs/RELEASE_VERIFICATION.md`.

### 7. Verify the container image

```bash
# Pull the image
docker pull ghcr.io/lunaticbugbear/hades-hermes-agent:v1.4.2

# Verify cosign signature
cosign verify ghcr.io/lunaticbugbear/hades-hermes-agent:v1.4.2 \
  --certificate-identity-regexp "https://github.com/lunaticbugbear/hades-hermes-agent/.github/workflows/release.yml@refs/tags/" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"

# Confirm multi-arch
docker manifest inspect ghcr.io/lunaticbugbear/hades-hermes-agent:v1.4.2
```

## What gets published

| Asset | Description |
|-------|-------------|
| `install.sh` | Linux/macOS installer |
| `install.ps1` | Windows PowerShell installer |
| `uninstall.sh` | Linux/macOS uninstaller |
| `uninstall.ps1` | Windows PowerShell uninstaller |
| `SHA256SUMS` | SHA-256 hashes of all release assets |
| `sbom.spdx.json` | SPDX software bill of materials |
| `*.sig` | Cosign keyless signatures (one per asset) |
| Container image | `ghcr.io/lunaticbugbear/hades-hermes-agent` (multi-arch) |

## Maintainer release checklist

- [ ] `VERSION` bumped in `install.sh` and `install.ps1`
- [ ] `HERMES_VERSION` updated if bundling a new upstream release
- [ ] `ARG HERMES_VERSION` in inline Dockerfiles updated (both installers)
- [ ] `CHANGELOG.md` updated with new version entry
- [ ] `main` CI is green
- [ ] Git tag created (`v*`) and pushed
- [ ] Release workflow completed successfully on GitHub Actions
- [ ] Release page shows all expected assets
- [ ] Container image pushed with expected tags
- [ ] Cosign signature verification passes
- [ ] SBOM present and valid
- [ ] Release notes cosign verify commands match the published tag

## Recovery

If a bad asset or tag goes out:

1. Stop any promotion or announcement of the broken release.
2. Fix the root cause (source code, workflow, or both).
3. Cut a follow-up tag (`v1.4.3`).
4. Explain the correction in the release notes.
5. Leave the broken release visible only if needed for audit traceability.
   GitHub Releases are immutable for audit; do not delete releases that have
   been announced.

For re-publishing the same tag (e.g. after a workflow fix), use `workflow_dispatch`
with the existing tag name — `gh release edit` + `gh release upload --clobber`
replaces assets in-place.
