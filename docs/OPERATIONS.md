# Operations Guide

For maintainers. Covers validation, triage, recovery, and day-to-day tasks.

See also: [ARCHITECTURE.md](ARCHITECTURE.md), [RELEASE_PROCESS.md](RELEASE_PROCESS.md), [../CONTRIBUTING.md](../CONTRIBUTING.md)

---

## Repository invariants

These should stay true unless there's a deliberate breaking change:

- installer entrypoints are `install.sh` and `install.ps1`
- uninstall is conservative by default
- browser tooling is opt-in
- API binds to `127.0.0.1` by default
- generated runtime files are not committed
- Hermes state survives rebuilds

## What the repo contains vs what gets generated

The repo is installer source only. Generated at install time:

- `Dockerfile`
- `docker-compose.yml`
- `bootstrap.sh`
- `healthcheck.sh`
- `bin/hades`, `bin/hades.ps1`, `bin/hades.cmd`
- `.env`
- `workspace/`

Persistent Hermes data lives in the `hermes_home` Docker volume, mounted at `/home/hermes/.hermes`.

---

## Local validation

Run before merging:

```bash
bash -n install.sh uninstall.sh
shellcheck -x install.sh uninstall.sh
python3 - <<'PY'
import yaml, pathlib
for p in pathlib.Path('.github/workflows').glob('*.yml'):
    yaml.safe_load(p.read_text())
print('workflow-yaml-ok')
PY
HERMES_NONINTERACTIVE=1 OPENROUTER_API_KEY=dummy-token-123456789 bash install.sh --skip-build --force --dir /tmp/hades-ci
cd /tmp/hades-ci && docker compose config
bash -n bootstrap.sh healthcheck.sh bin/hades

### Prebuilt image vs local build verification

```bash
# Verify the release artifact signature
cosign verify-blob \
  --bundle install.sh.bundle \
  --certificate-identity-regexp 'https://github.com/lunaticbugbear/*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  install.sh

# Verify the prebuilt container image tag matches
docker pull ghcr.io/lunaticbugbear/hades-hermes-agent:latest
cosign verify \
  --certificate-identity-regexp 'https://github.com/lunaticbugbear/*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/lunaticbugbear/hades-hermes-agent:latest
```
```

Windows parser check (optional):

```powershell
$errors = $null
[System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw .\install.ps1), [ref]$errors) | Out-Null
if ($errors) { $errors | Format-List; exit 1 }
$errors = $null
[System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw .\uninstall.ps1), [ref]$errors) | Out-Null
if ($errors) { $errors | Format-List; exit 1 }
```

---

## Common tasks

### Regenerate runtime files without building

```bash
HERMES_NONINTERACTIVE=1 OPENROUTER_API_KEY=dummy-token-123456789 bash install.sh --skip-build --force --dir /tmp/hades-ci
```

Useful for checking generated Compose config, paths, or flag handling without spinning up Docker.

### Full smoke test

```bash
HERMES_NONINTERACTIVE=1 OPENROUTER_API_KEY=dummy-token-123456789 bash install.sh --force --dir /tmp/hades-smoke
cd /tmp/hades-smoke
./bin/hades start
curl -sf http://127.0.0.1:8642/health
./bin/hades logs
./bin/hades down
```

### Check a live install

```bash
hades status     # container running?
hades check      # full health check (container + API)
hades url        # print API URL
hades logs
hades shell
```

### Backup and restore

```bash
hades backup                          # backup Hermes data to ./backups/
hades backup /path/to/dir             # backup to custom path
hades restore /path/to/backup.tar.gz  # restore data (container must be running)
```

If the wrapper isn't in PATH:

```bash
cd ~/.hades
docker compose ps
docker compose logs --tail 120 hermes
curl -sf http://127.0.0.1:8642/health
```

---

## Triage

### Installer fails

Collect:

- OS and version
- shell or PowerShell version
- Docker version
- exact command
- interactive or non-interactive run
- sanitized stderr/stdout

Common causes:

- Docker daemon not running
- PATH write permission issues
- stale generated files from a previous install without `--force`

### API health check fails

1. `hades status` — is the container up?
2. `hades logs` — any errors?
3. Check `.env` for the right bind address and port
4. `curl -sf http://127.0.0.1:8642/health`
5. If version-related: `hades update`

### Suspected regression in generated files

1. Regenerate into a clean temp dir with `--skip-build --force`
2. Diff the output against the last known good state
3. Check that README and CI match the intended behavior
4. If install/startup logic changed, test the uninstall path too

---

## Change management

When you change flags, defaults, paths, or generated file behavior:

- update README
- update CHANGELOG
- update CI if behavior assertions moved
- keep `install.sh` and `install.ps1` in sync
- don't break non-interactive automation silently

---

## GitHub baseline

- `main` protected, required CI checks enforced
- stale reviews dismissed
- conversation resolution required before merge
- force-push disabled
- squash merge preferred

---

## Recovery

If a release breaks installs:

1. Stop merging
2. Find the last good commit or tag
3. Revert or patch the breaking behavior
4. Rerun validation and CI
5. Publish a follow-up tag if users hit it from a tagged release

### Compromised release asset

1. Mark the bad asset as broken in the release notes or follow-up issue.
2. Publish a corrected release/tag.
3. Explain what changed and how users should verify the replacement.
4. Keep checksum and attestation docs aligned.

### Bad checksum or SBOM

1. Treat it as a release integrity bug.
2. Rebuild the release asset set.
3. Regenerate checksum/SBOM files.
4. Republish the release notes with the corrected verification steps.

If a user's runtime is broken but their data should survive:

```bash
hades down
hades update
hades start
```

If they're OK losing the persistent volume:

```bash
hades reset
```

Warn them first — `reset` removes Hermes sessions, memory, and config from the named volume.
