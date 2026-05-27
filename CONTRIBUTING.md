# Contributing

## Quality bar

Changes to this installer should preserve the goal: a non-technical user can install Hermes Agent on Linux, macOS, Windows, or WSL with minimal instructions.

Before submitting a change:

```bash
bash -n install.sh uninstall.sh
shellcheck -x install.sh uninstall.sh
HERMES_NONINTERACTIVE=1 OPENROUTER_API_KEY=dummy-test-key-123456789 bash install.sh --skip-build --force --port 18642 --dir /tmp/hermes-docker-ci
cd /tmp/hermes-docker-ci && docker compose config
```

On Windows:

```powershell
$errors = $null
[System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw .\install.ps1), [ref]$errors) | Out-Null
if ($errors) { $errors | Format-List; exit 1 }
```

## Principles

- Keep interactive UX clear and forgiving.
- Keep non-interactive install stable for automation.
- Never commit `.env` or generated runtime files.
- Do not make destructive uninstall the default.
- Prefer explicit helper commands over hidden magic.
- Add troubleshooting docs for every common failure mode discovered.
