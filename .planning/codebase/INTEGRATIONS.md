# External Integrations

**Analysis Date:** 2026-06-20

## APIs & External Services

**Claude Code CLI:**
- Claude Code statusline command - The installer writes `settings.statusLine` so Claude Code invokes the generated Bash statusline command.
  - SDK/Client: Local `settings.json` update through Node `fs` in `bin/install.js`
  - Auth: Not applicable for the statusline command itself
  - Files: `bin/install.js`, `README.md`
- Claude Code statusline input JSON - The generated script reads statusline input from stdin and extracts model, context window, current usage, cwd, and session start fields.
  - SDK/Client: Bash plus `jq` in generated shell code inside `bin/install.js`
  - Auth: Not applicable
  - Files: `bin/install.js`

**Provider Usage APIs:**
- Anthropic usage API - Fetches current five-hour, seven-day, and extra usage information.
  - Endpoint: `https://api.anthropic.com/api/oauth/usage`
  - SDK/Client: `curl` in `bin/providers/anthropic.sh`
  - Auth: Bearer token from `CLAUDE_CODE_OAUTH_TOKEN`, macOS Keychain service, `${SCRIPT_DIR}/.credentials.json`, or Linux `secret-tool`
  - Files: `bin/providers/anthropic.sh`, `README.md`
- Z.AI quota API - Fetches token limit and tool time usage information.
  - Endpoint: `https://api.z.ai/api/monitor/usage/quota/limit`
  - SDK/Client: `curl` in `bin/providers/zai.sh`
  - Auth: Bearer token from `${SCRIPT_DIR}/settings.json` key `.env.ANTHROPIC_AUTH_TOKEN` or `~/.chelper/config.yaml` key `api_key`
  - Files: `bin/providers/zai.sh`, `README.md`

**Package Distribution:**
- npm registry - Users install the CLI with `npx @thlinh/cc-statusline`.
  - SDK/Client: npm/npx as documented in `README.md`
  - Auth: Not detected for consumers; no `.npmrc` is present
  - Files: `package.json`, `README.md`, `.npmignore`
- GitHub repository metadata - Package metadata points to `https://github.com/thlinhit/cc-statusline.git`.
  - SDK/Client: Package metadata only
  - Auth: Not applicable
  - Files: `package.json`

**Project-Local GSD Tooling:**
- GSD update checks - Project hooks invoke local GSD Node scripts; update logic resolves package coordinates for `@opengsd/gsd-core`.
  - SDK/Client: Node scripts in `.codex/hooks/gsd-check-update.js` and `.codex/gsd-core/bin/check-latest-version.cjs`
  - Auth: Not detected
  - Files: `.codex/hooks.json`, `.codex/hooks/gsd-check-update.js`, `.codex/gsd-core/bin/check-latest-version.cjs`, `.codex/gsd-core/bin/lib/package-identity.cjs`
- Package legitimacy checks - GSD tooling can query npm, PyPI, and crates.io package APIs.
  - SDK/Client: Node HTTPS logic in `.codex/gsd-core/bin/lib/package-legitimacy.cjs`
  - Auth: Not detected
  - Files: `.codex/gsd-core/bin/lib/package-legitimacy.cjs`

## Data Storage

**Databases:**
- Not detected
  - Connection: Not applicable
  - Client: Not applicable
  - Files: `package.json`, `bin/install.js`

**File Storage:**
- Local filesystem only - The installer copies and generates files inside the target Claude config directory.
  - Paths: `statusline.sh`, `statusline-helpers.sh`, `statusline-provider.sh`, `settings.json`, `statusline.sh.bak`, `statusline-cache.json`
  - Client: Node `fs` in `bin/install.js`
  - Files: `bin/install.js`
- User token/config file reads - Provider scripts read existing user-local credentials without storing values in the repo.
  - Paths: `${SCRIPT_DIR}/.credentials.json`, `${SCRIPT_DIR}/settings.json`, `~/.chelper/config.yaml`
  - Client: `jq`, `grep`, `sed`, and shell reads in `bin/providers/anthropic.sh` and `bin/providers/zai.sh`
  - Files: `bin/providers/anthropic.sh`, `bin/providers/zai.sh`

**Caching:**
- Provider usage cache - Generated statusline script caches provider usage JSON for 60 seconds in `${SCRIPT_DIR}/statusline-cache.json`.
  - Client: Bash, `stat`, `date`, and `jq` in generated shell code inside `bin/install.js`
  - Files: `bin/install.js`
- GSD update cache - GSD hook writes update-check state under `~/.cache/gsd`.
  - Client: Node `fs` in `.codex/hooks/gsd-check-update.js`
  - Files: `.codex/hooks/gsd-check-update.js`

## Authentication & Identity

**Auth Provider:**
- No application-owned auth provider - The package reads existing provider credentials from the user's local Claude/Z.AI setup.
  - Implementation: Token discovery in `bin/providers/anthropic.sh` and `bin/providers/zai.sh`
- Anthropic OAuth token - Used as a Bearer token for `https://api.anthropic.com/api/oauth/usage`.
  - Implementation: `CLAUDE_CODE_OAUTH_TOKEN`, macOS Keychain service names, `${SCRIPT_DIR}/.credentials.json`, and Linux `secret-tool` in `bin/providers/anthropic.sh`
- Z.AI API token - Used as a Bearer token for `https://api.z.ai/api/monitor/usage/quota/limit`.
  - Implementation: `${SCRIPT_DIR}/settings.json` key `.env.ANTHROPIC_AUTH_TOKEN` or `~/.chelper/config.yaml` key `api_key` in `bin/providers/zai.sh`

## Monitoring & Observability

**Error Tracking:**
- None detected for the package - There is no Sentry, OpenTelemetry, analytics, or remote error tracking dependency in `package.json`.
- GSD context monitoring is local only - `.codex/hooks/gsd-context-monitor.js` reads temp files and emits hook context warnings, not remote telemetry.

**Logs:**
- Installer logs to stdout/stderr with ANSI-colored status messages in `bin/install.js`.
- Runtime provider failures are quiet by design; provider scripts redirect failed `curl`, `jq`, and credential lookups to `/dev/null` in `bin/providers/anthropic.sh` and `bin/providers/zai.sh`.
- GSD hooks are designed to fail silently for local automation in `.codex/hooks/gsd-context-monitor.js`.

## CI/CD & Deployment

**Hosting:**
- Not applicable for the package - Runtime is local CLI/statusline execution through files generated by `bin/install.js`.
- Source repository is declared as GitHub in `package.json`.

**CI Pipeline:**
- None detected - `.github/` contains `demo.png` only and no workflow YAML files.
- npm package publishing workflow is not present in the repository; `package.json` and `.npmignore` define the package shape.

## Environment Configuration

**Required env vars:**
- None strictly required for install - `bin/install.js` can install with provider choice and local target directory.
- `CLAUDE_CODE_OAUTH_TOKEN` - Optional Anthropic token source in `bin/providers/anthropic.sh`.
- `ANTHROPIC_AUTH_TOKEN` - Expected as the `settings.json` key `.env.ANTHROPIC_AUTH_TOKEN` for Z.AI mode in `bin/providers/zai.sh`.
- `CLAUDE_CONFIG_DIR` - Optional project-local GSD hook config override in `.codex/hooks/gsd-check-update.js`; not required by the package runtime.
- `GSD_CACHE_FILE`, `GSD_PROJECT_VERSION_FILE`, and `GSD_GLOBAL_VERSION_FILE` - Set internally for the GSD update worker from `.codex/hooks/gsd-check-update.js`; not package runtime config.

**Secrets location:**
- Repo secrets: Not detected - No `.env`, `.npmrc`, credential, certificate, or private key files are present in the repository scan.
- Anthropic secrets live in user-local locations read by `bin/providers/anthropic.sh`: environment variable, macOS Keychain, `${SCRIPT_DIR}/.credentials.json`, or Linux keyring.
- Z.AI secrets live in user-local locations read by `bin/providers/zai.sh`: `${SCRIPT_DIR}/settings.json` or `~/.chelper/config.yaml`.

## Webhooks & Callbacks

**Incoming:**
- None detected - There is no server, HTTP route, webhook receiver, or callback endpoint in `bin/` or `package.json`.

**Outgoing:**
- Anthropic usage request to `https://api.anthropic.com/api/oauth/usage` from `bin/providers/anthropic.sh`.
- Z.AI quota request to `https://api.z.ai/api/monitor/usage/quota/limit` from `bin/providers/zai.sh`.
- GSD development tooling can query npm, PyPI, crates.io, and GitHub-related package metadata from `.codex/gsd-core/bin/lib/package-legitimacy.cjs` and `.codex/gsd-core/bin/lib/package-identity.cjs`.

---

*Integration audit: 2026-06-20*
