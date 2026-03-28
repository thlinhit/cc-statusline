# cc-statusline

Multi-provider status line for Claude Code CLI supporting Anthropic and Z.AI APIs.

![demo](./.github/demo.png)

## Features

- **Multi-provider support**: Anthropic and Z.AI APIs
- **Usage tracking**: Current, weekly, and extra usage (varies by provider)
- **Context display**: Model name, context percentage, directory, git branch
- **Session info**: Duration, effort level indicator
- **Cross-platform**: Works on macOS and Linux

## Install

### Anthropic (default directory)

```bash
npx @thlinh/cc-statusline
```

Or with explicit provider:

```bash
npx @thlinh/cc-statusline --provider=anthropic
```

### Z.AI (custom directory)

```bash
npx @thlinh/cc-statusline --dir ~/.claude-z --provider=zai
```

### Non-interactive install

For dotfiles or automated scripts:

```bash
npx @thlinh/cc-statusline --provider=zai --dir ~/.claude-z
```

## Requirements

- [jq](https://jqlang.github.io/jq/) — for parsing JSON
- curl — for fetching rate limit data
- git — for branch info (optional)

On macOS:

```bash
brew install jq
```

## Providers

### Anthropic

- **Token source**: OAuth token from keychain or environment
- **API endpoint**: `https://api.anthropic.com/api/oauth/usage`
- **Display**: current (5-hour), weekly (7-day), extra (monthly credits)

### Z.AI

- **Token source**: `~/.chelper/config.yaml`
- **API endpoint**: `https://api.z.ai/api/monitor/usage/quota/limit`
- **Display**: current (tokens), tools (MCP usage)

## Uninstall

```bash
npx @thlinh/cc-statusline --uninstall --dir ~/.claude-z
```

If you had a previous statusline, it restores it from the backup. Otherwise it removes the script and cleans up your settings.

## Architecture

The installed statusline consists of three modular files:

- `statusline.sh` — Main entry point (generated at install time)
- `statusline-helpers.sh` — Shared utilities
- `statusline-provider.sh` — Provider-specific implementation

## License

MIT
