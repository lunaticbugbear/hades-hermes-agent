# Release Process

## Release model

Omnipod uses two channels:

- `main` — continuously validated primary branch
- `v*` tags — immutable release points published via GitHub Releases

## Before tagging

Validate locally where possible:

```bash
bash -n install.sh uninstall.sh
shellcheck -x install.sh uninstall.sh
python3 - <<'PY'
import yaml, pathlib
for p in pathlib.Path('.github/workflows').glob('*.yml'):
    yaml.safe_load(p.read_text())
print('workflow-yaml-ok')
PY
```

Then ensure the latest `main` CI is green.

## Tagging a release

Example:

```bash
git tag v1.1.6
git push origin v1.1.6
```

## What the release workflow publishes

The `release.yml` workflow packages:

- `install.sh`
- `install.ps1`
- `uninstall.sh`
- `uninstall.ps1`
- `README.md`
- `LICENSE`
- `CHANGELOG.md`
- `SECURITY.md`
- `SUPPORT.md`
- `SHA256SUMS`

## Verifying release assets

```bash
sha256sum -c SHA256SUMS
```

## Changelog discipline

Every user-visible change should update `CHANGELOG.md`, especially:

- install flags or defaults
- generated file behavior
- CI / governance changes
- security posture changes
- release tooling changes

## Release checklist

- [ ] `main` is green
- [ ] docs reflect current flags, defaults, and helper commands
- [ ] generated paths and names are consistent (`omnipod`, `~/.omnipod`)
- [ ] `CHANGELOG.md` has an entry for the release
- [ ] tag follows `v*` format
- [ ] published assets include `SHA256SUMS`
