# Contributing to dev-orchestrator

This is a Claude Code plugin: a `/dev` skill, host hooks, and shell scripts.
There's no compile step — contributions are shell, Markdown, and JSON.

## Setup

```bash
git clone https://github.com/zelinewang/dev-orchestrator.git
cd dev-orchestrator
```

The plugin manifest is `.claude-plugin/plugin.json`. To try the plugin in your
own setup, follow the Installation section of `README.md`.

## Checks

The verification gate is the heart of the project; run it against the committed
fixture:

```bash
bash scripts/verify-dev.sh examples/verify-clean-go   # expects: VERIFIED ✓
```

Shell scripts should pass `shellcheck` cleanly. If you change a hook, describe in
the PR how you exercised it — hooks run on the host, so behavior is
environment-specific.

## Pull requests

- Branch off `main`; open one focused PR per change.
- Conventional-ish commit subjects (`fix:`, `feat:`, `docs:`…). PRs are
  squash-merged.
- Keep the skill, hooks, and rules in sync with the tables in `README.md` — if
  you add a hook or rule, update the corresponding row.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
