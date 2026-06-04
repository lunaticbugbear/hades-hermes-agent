# Release Verification

Use this guide to verify every artifact published in a HADES release.
A release is trustworthy only after **all** of these checks pass.

## Prerequisites

- `sha256sum` (Linux/macOS) or `Get-FileHash` (Windows)
- `cosign` — install via `brew install cosign` or `go install github.com/sigstore/cosign/v2/cmd/cosign@latest`
- `docker` — to pull and verify the container image
- `gh` (GitHub CLI) — for attestation verification (optional)
- `syft` — for SBOM inspection (optional)

## 1. SHA256 verification

Download the release assets and the `SHA256SUMS` file from the
[GitHub Releases page](https://github.com/lunaticbugbear/hades-hermes-agent/releases).

### Linux / macOS

```bash
cd /path/to/downloaded/release
sha256sum -c SHA256SUMS
```

Expected output (all files):
```
install.sh: OK
install.ps1: OK
uninstall.sh: OK
uninstall.ps1: OK
README.md: OK
LICENSE: OK
CHANGELOG.md: OK
SECURITY.md: OK
SUPPORT.md: OK
```

Any line that says **FAILED** means the file has been tampered with or is corrupt.
Do **not** use it.

### Windows (PowerShell)

```powershell
Get-FileHash .\install.ps1 -Algorithm SHA256
Get-FileHash .\install.sh -Algorithm SHA256
```

Compare the output hashes against the values in `SHA256SUMS`.

## 2. Cosign signature verification (container image)

Verify the container image was signed by the release workflow. The signature is
**keyless** — it uses OIDC identity from GitHub Actions rather than a long-lived
key pair.

```bash
cosign verify ghcr.io/lunaticbugbear/hades-hermes-agent:v1.4.2 \
  --certificate-identity-regexp "https://github.com/lunaticbugbear/hades-hermes-agent/.github/workflows/release.yml@refs/tags/" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

Replace `v1.4.2` with the version you are verifying.

Expected output includes:
- `Verified OK` at the bottom
- A `Certificate` section showing the signing identity
- A JSON payload with the image digest and issuance time

If verification fails, the image may have been tampered with or may not be
from an official release.

### Verify multi-arch support

```bash
docker manifest inspect ghcr.io/lunaticbugbear/hades-hermes-agent:v1.4.2
```

Expected output shows two manifests in the `manifests` array:
```json
{
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {
      "platform": { "architecture": "amd64", "os": "linux" },
      ...
    },
    {
      "platform": { "architecture": "arm64", "os": "linux" },
      ...
    }
  ]
}
```

## 3. Cosign signature verification (installer scripts)

Each release asset has a corresponding `.sig` file (e.g. `install.sh.sig`).
Verify the signatures against the release workflow identity:

```bash
# Verify install.sh (repeat for install.ps1, uninstall.sh, uninstall.ps1)
cosign verify-blob \
  --certificate-identity-regexp "https://github.com/lunaticbugbear/hades-hermes-agent/.github/workflows/release.yml@refs/tags/" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --signature install.sh.sig \
  install.sh
```

Expected output: `Verified OK`

Repeat for all four installer files.

### Verify SHA256SUMS signature

```bash
cosign verify-blob \
  --certificate-identity-regexp "https://github.com/lunaticbugbear/hades-hermes-agent/.github/workflows/release.yml@refs/tags/" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --signature SHA256SUMS.sig \
  SHA256SUMS
```

This proves the checksum file itself — and transitively every file it lists —
was produced by the official release workflow.

## 4. Running the installer and verifying health

After downloading and verifying the installer:

### Linux / macOS

```bash
chmod +x install.sh
HERMES_NONINTERACTIVE=1 OPENROUTER_API_KEY=sk-or-dummy123 ./install.sh
```

### Windows (PowerShell, admin)

```powershell
.\install.ps1 -Provider openrouter -OpenRouterApiKey sk-or-dummy123 -NoStart
```

### Verify the container is healthy

```bash
# Check container status
docker ps --filter name=hades

# Expected: STATUS shows "Up" and "(healthy)" after the start period

# Check the healthcheck endpoint
curl -fsS http://127.0.0.1:8642/health

# Expected: HTTP 200 with a JSON response
```

### Verify Hermes API responds

```bash
# List available models
curl -s http://127.0.0.1:8642/v1/models | head -5

# Expected: JSON array with model objects (may be empty depending on provider config,
# but the endpoint must respond)
```

### Verify the hades CLI works

```bash
hades status
hades logs --tail 20
```

## 5. SBOM verification

The Software Bill of Materials (`sbom.spdx.json`) lists every component shipped
in the release.

### Verify the SBOM is valid SPDX

```bash
# Using syft (install via curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin)
syft convert sbom.spdx.json -o table

# Or validate with a Python script
python3 -c "
import json
with open('sbom.spdx.json') as f:
    sbom = json.load(f)
print('SPDX version:', sbom.get('spdxVersion'))
print('Packages:', len(sbom.get('packages', [])))
print('Creation info:', sbom.get('creationInfo', {}).get('creators'))
"
```

Expected: `spdxVersion` should be a valid SPDX version, and the package count
should be non-zero.

### Verify the SBOM cosign signature

```bash
cosign verify-blob \
  --certificate-identity-regexp "https://github.com/lunaticbugbear/hades-hermes-agent/.github/workflows/release.yml@refs/tags/" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  --signature sbom.spdx.json.sig \
  sbom.spdx.json
```

### (Optional) GitHub provenance attestation

```bash
gh attestation verify ./install.sh -R lunaticbugbear/hades-hermes-agent
```

This confirms the file was built by the `release.yml` workflow in the
`lunaticbugbear/hades-hermes-agent` repository, using OIDC-based attestation.

## Complete verification checklist

- [ ] `sha256sum -c SHA256SUMS` — all files OK
- [ ] `cosign verify ghcr.io/.../hades-hermes-agent:vX.Y.Z` — container image verified
- [ ] `docker manifest inspect` shows amd64 + arm64
- [ ] `cosign verify-blob` passes for each `.sig` file (installers + SHA256SUMS + sbom)
- [ ] Installer runs without errors
- [ ] Container shows `(healthy)` in `docker ps`
- [ ] HTTP healthcheck endpoint responds 200
- [ ] `hades status` reports container running
- [ ] SBOM is valid SPDX with non-zero package count
- [ ] `cosign verify-blob` passes for `sbom.spdx.json.sig`

## Troubleshooting

| Problem | Likely cause | Fix |
|---------|-------------|-----|
| `sha256sum -c` fails | Corrupt download or tampered file | Re-download from GitHub Releases |
| `cosign verify` fails | Wrong tag, expired certificate, or tampered image | Check the tag matches the release; certificates are valid for ~10 minutes from signing |
| Container not healthy | Hermes Agent startup still in progress | Wait up to 60s (the `start-period`); run `docker logs hades` |
| `cosign` not found | Missing dependency | Install from https://docs.sigstore.dev/cosign/installation/ |
| `docker manifest inspect` fails | Image not pulled | Run `docker pull ghcr.io/lunaticbugbear/hades-hermes-agent:vX.Y.Z` first |
