# FAQ

## What is HADES?

HADES is a one-command installer and runtime wrapper for [Hermes Agent](https://github.com/NousResearch/hermes-agent). It runs Hermes inside Docker so you do not have to manage Python, Chromium, Playwright, or virtualenvs on your own machine.

## What is Hermes Agent?

Hermes Agent is an open-source coding agent. HADES is independent of Hermes; it just packages it into a reproducible local install.

## Do I need to know Docker?

No. You only need Docker installed and running. HADES handles the rest.

## What does the installer touch on my machine?

- creates `~/.hades/` (config, generated runtime files, workspace)
- creates a Docker volume named `hermes_home` for persistent agent state
- pulls a Docker image
- adds a `hades` wrapper command to your shell PATH

It does not modify global system files, install Python on the host, or change Docker daemon settings.

## How do I uninstall HADES?

```bash
bash uninstall.sh                              # stop the stack, keep data
bash uninstall.sh --remove-data                # also drop the persistent volume
bash uninstall.sh --remove-files               # also delete ~/.hades
bash uninstall.sh --remove-files --remove-data # remove everything
```

Uninstall is conservative by default. It will not delete data unless you pass `--remove-data` or `--remove-files`.

## Where do my API keys live?

In `~/.hades/.env`. On Linux and macOS the file is `chmod 600`. Don't commit that file, and don't paste it into bug reports.

## How do I change provider or model?

Edit `~/.hades/.env`, then run:

```bash
hades restart
```

For build-time changes such as enabling browser tooling or pinning a different Hermes version:

```bash
hades update
```

## Can the API be reached from another machine?

Not by default. The API binds to `127.0.0.1`. You can change that yourself if you understand the security implications, but the default is intentional.

## Does HADES collect telemetry?

No.

## What does `hades reset` do?

It removes the persistent Hermes data volume. Sessions, memory, skills, and config inside the volume are gone after this. It is irreversible. Always read the prompt before running it.

## I get "port 8642 in use" — what now?

Either stop whatever is using the port, or install on a different port:

```bash
bash install.sh --port 18642
```

## Does this work without internet?

Internet is required for the first install (Docker image pull, dependency download) and to talk to your model provider. Once installed and running, HADES itself does not need internet to start the container.

## How do I get help?

- Read [`OPERATIONS.md`](OPERATIONS.md) and the [`README`](../README.md) troubleshooting section.
- Search existing issues in `https://github.com/lunaticbugbear/hades-hermes-agent/issues`.
- Open a new issue with the bug report or question template if nothing matches.
- For security issues, follow [`SECURITY.md`](../SECURITY.md). Don't open a public issue.

## How do I verify a release is authentic?

```bash
gh release download v1.4.2 -R lunaticbugbear/hades-hermes-agent
sha256sum -c SHA256SUMS
gh attestation verify install.sh -R lunaticbugbear/hades-hermes-agent
```

Details in [`docs/RELEASE_VERIFICATION.md`](RELEASE_VERIFICATION.md).

## Is HADES affiliated with OpenAI, Anthropic, Google, or Nous Research?

No. HADES is an independent OSS installer wrapper. It supports those provider APIs through configuration. It is not endorsed by any of them.

## How do I change the approval mode?

Edit `~/.hades/.env` and set `APPROVAL_MODE` to either `manual` or `auto`:

- **manual** (default): Hermes asks before every tool call (terminal, file write, web, etc.)
- **auto**: Hermes executes tools without confirmation — use only if you trust the agent

Then run `hades restart` to apply.

## Can I use local models with GPU?

Yes. Pass the `--gpus` flag during install:

```bash
bash install.sh --gpus all
```

Or set `GPU_DEVICES=all` in `~/.hades/.env` and run `hades update`. Requires `nvidia-container-toolkit` on the host.

## How do I verify a release with cosign?

```bash
cosign verify-blob \
  --certificate-identity-regexp 'https://github.com/lunaticbugbear/hades-hermes-agent/.github/workflows/release.yml@refs/tags/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --signature install.sh.sig \
  install.sh
```

Container image verification:

```bash
cosign verify \
  --certificate-identity-regexp 'https://github.com/lunaticbugbear/*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/lunaticbugbear/hades-hermes-agent:latest
```

## What is GATEWAY_ALLOW_ALL_USERS?

It controls whether any API key can act as any user in the Hermes gateway. For single-user local installs, `true` is fine. If you expose the API to a network, set it to `false` and configure user mapping in the Hermes gateway config. See [Hermes Gateway docs](https://hermes-agent.nousresearch.com/docs/gateway/configuration) for user mapping setup.
