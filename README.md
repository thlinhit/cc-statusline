# cc-statusline

Status line for Claude Code CLI. Works with Anthropic or Z.AI.

![demo](./.github/demo.png)

Shows your current model, context percentage, git branch, how long you've been working, and API usage depending on your provider.

## Install

```bash
npx @thlinh/cc-statusline
```

This uses Anthropic by default and installs to `~/.claude`.

For Z.AI:

```bash
npx @thlinh/cc-statusline --provider=zai --dir ~/.claude-z
```

For scripts or dotfiles (skip the prompts):

```bash
npx @thlinh/cc-statusline --provider=zai --dir ~/.claude-z
```

## Requirements

- [jq](https://jqlang.github.io/jq/) — parses JSON
- curl — fetches usage
- git — branch info (optional)

macOS: `brew install jq`

## Providers

**Anthropic** — pulls OAuth token from keychain, calls Anthropic's usage API, shows current/weekly/extra.

**Z.AI** — reads token from `~/.chelper/config.yaml`, calls Z.AI's quota API, shows token and tool usage.

## Uninstall

```bash
npx @thlinh/cc-statusline --uninstall --dir ~/.claude-z
```

Restores your backup if you had one, otherwise removes the files.

## What gets installed

Three files end up in your claude config directory:

- `statusline.sh` — main script (generated when you run the installer)
- `statusline-helpers.sh` — shared utilities
- `statusline-provider.sh` — whichever provider you picked

## License

MIT
