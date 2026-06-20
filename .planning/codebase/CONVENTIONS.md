# Coding Conventions

**Analysis Date:** 2026-06-20

## Naming Patterns

**Files:**
- Use an executable CommonJS CLI entry point for the NPM binary: `bin/install.js`.
- Use lowercase hyphenated Bash filenames for installed runtime helpers: `bin/shared-helpers.sh`, `bin/providers/anthropic.sh`, `bin/providers/zai.sh`.
- Keep provider implementations under `bin/providers/` and name each provider file after the provider flag value used by `bin/install.js` (`anthropic` or `zai`).
- Project-local workflow skills live under `.codex/skills/*/SKILL.md`; they are GSD workflow assets, not runtime application source.

**Functions:**
- JavaScript functions in `bin/install.js` use lower camelCase declarations: `parseArgs`, `checkDeps`, `promptProvider`, `getProvider`, `generateStatuslineScript`, `run`.
- Bash functions use lower snake_case names: `format_tokens`, `color_for_pct`, `build_bar`, `iso_to_epoch`, `format_reset_time`.
- Bash internal helpers use a leading underscore: `_format_epoch_time` in `bin/shared-helpers.sh`, `_keychain_service_name` in `bin/providers/anthropic.sh`.
- Provider scripts must expose the same three-function contract consumed by the generated statusline script in `bin/install.js`: `get_provider_token`, `fetch_usage_data`, `format_usage_lines`.

**Variables:**
- JavaScript local variables use lower camelCase: `targetDir`, `providerName`, `statuslineContent`, `statusLineConfig`.
- JavaScript path constants local to install/uninstall flows use uppercase snake case: `STATUSLINE_DEST`, `HELPERS_DEST`, `PROVIDER_DEST`, `SETTINGS_FILE`, `BACKUP_DEST`.
- Bash variables use lower snake case for mutable values: `usage_data`, `cache_file`, `five_hour_pct`, `tokens_reset_ms`.
- Bash color variables are lowercase globals sourced into runtime scripts: `blue`, `green`, `cyan`, `red`, `yellow`, `white`, `magenta`, `dim`, `reset`.
- Environment variable names remain uppercase snake case and should be referenced by name only in docs: `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_AUTH_TOKEN`.

**Types:**
- Not applicable for static typing: the repository contains JavaScript and Bash only, with no TypeScript types or JSDoc type annotations.
- Structured data is plain JSON parsed with `JSON.parse` in `bin/install.js` and with `jq` in `bin/install.js`, `bin/providers/anthropic.sh`, and `bin/providers/zai.sh`.

## Code Style

**Formatting:**
- No formatter config is present. Not detected: `.prettierrc*`, `prettier.config.*`, `biome.json`, or equivalent repo config.
- Match existing JavaScript style in `bin/install.js`: 2-space indentation, semicolons, double-quoted string literals, CommonJS `require`, and braces on the same line as control statements.
- Match existing Bash style in `bin/shared-helpers.sh` and `bin/providers/*.sh`: 4-space indentation inside functions/control blocks, quoted parameter expansion, `local` declarations inside functions, and command substitution with `$(...)`.
- Preserve executable shebangs for CLI/runtime files: `#!/usr/bin/env node` in `bin/install.js` and `#!/bin/bash` in `bin/shared-helpers.sh` and `bin/providers/*.sh`.

**Linting:**
- No lint config is present. Not detected: `eslint.config.*`, `.eslintrc*`, `biome.json`, or `package.json` lint scripts.
- The effective style contract is the existing source in `bin/install.js`, `bin/shared-helpers.sh`, `bin/providers/anthropic.sh`, and `bin/providers/zai.sh`.
- Do not introduce a new formatter or linter style in isolated edits without adding the corresponding repo config and scripts in `package.json`.

## Import Organization

**Order:**
1. Node built-in modules at the top of `bin/install.js`: `fs`, `path`, `os`, `readline`.
2. Lazy Node built-in imports inside the function that needs them: `child_process` is required inside `checkDeps` in `bin/install.js`.
3. No third-party imports are used; runtime external tools are invoked through shell commands (`jq`, `curl`, `git`, `security`, `secret-tool`).

**Path Aliases:**
- Not detected. There is no TypeScript config, bundler config, or module alias setup.
- Use relative filesystem paths via `path.resolve(__dirname, ...)` for package files copied by `bin/install.js`.

## Error Handling

**Patterns:**
- JavaScript user-facing failures flow through the `fail(msg)` logger in `bin/install.js`, followed by `process.exit(1)` for fatal install errors.
- Dependency checks in `bin/install.js` use `try`/`catch` around `execSync("which ...")` and collect missing required tools before exiting.
- JSON reads in `bin/install.js` are wrapped in `try`/`catch`; malformed `settings.json` is reported with a user-facing failure message.
- Uninstall behavior in `bin/install.js` is conservative: existing backups are restored, cache files are removed when present, and helper/provider files are preserved when they might belong to a restored backup.
- Bash provider functions return non-zero for missing token or invalid API response and emit an empty string when token lookup fails: `bin/providers/anthropic.sh`, `bin/providers/zai.sh`.
- Bash scripts suppress noisy external command errors with `2>/dev/null` around optional or environment-dependent calls in `bin/shared-helpers.sh` and `bin/providers/*.sh`.

## Logging

**Framework:** `console` in Node, `printf`/`echo` in Bash

**Patterns:**
- Use the wrapper functions in `bin/install.js` for CLI output: `log`, `success`, `warn`, `fail`.
- Keep install/uninstall messages indented and colorized through the existing ANSI constants in `bin/install.js`.
- Generated runtime output in `bin/install.js` and provider scripts is formatted with shell color variables from `bin/shared-helpers.sh`.
- Do not print token values, credential file contents, or raw secret-bearing config. Provider code may mention config keys and paths such as `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_AUTH_TOKEN`, `settings.json`, and `~/.chelper/config.yaml`.

## Comments

**When to Comment:**
- Use short section comments for major CLI/runtime blocks, as in `bin/install.js`, `bin/shared-helpers.sh`, and `bin/providers/*.sh`.
- Comment provider lookup priority and cross-platform fallbacks where behavior depends on OS tools, as in `bin/providers/anthropic.sh`, `bin/providers/zai.sh`, and `bin/shared-helpers.sh`.
- Keep comments operational and close to the code they explain; avoid duplicating simple assignments.

**JSDoc/TSDoc:**
- Not used. The repository has no JSDoc, TSDoc, or generated API docs.

## Function Design

**Size:** Small helpers handle formatting, logging, argument parsing, provider lookup, and API calls. Larger orchestration functions are limited to CLI workflows: `uninstall`, `generateStatuslineScript`, and `run` in `bin/install.js`.

**Parameters:** Functions take simple primitive values or a plain argument object. Examples: `getProvider(args)` in `bin/install.js`, `format_tokens()`, `color_for_pct()`, and `fetch_usage_data()` in Bash.

**Return Values:** 
- JavaScript helpers return plain objects/strings/promises: `parseArgs()` returns an object, `checkDeps()` returns `{ missing, hasGit }`, `getProvider()` returns a provider id.
- Bash helpers print computed values to stdout and use return codes for success/failure: `format_tokens`, `iso_to_epoch`, `get_provider_token`, `fetch_usage_data`.
- Provider scripts should keep stdout machine-readable for callers and send no secret material to logs.

## Module Design

**Exports:** No module exports are used. `bin/install.js` is an executable script that invokes `run().catch(...)` at the bottom of the file.

**Barrel Files:** Not applicable. There are no barrel files or package-level re-export modules.

**Runtime Contracts:**
- `package.json` maps the `cc-statusline` binary directly to `bin/install.js`.
- `bin/install.js` copies `bin/shared-helpers.sh` and exactly one provider from `bin/providers/` into the target Claude config directory.
- The generated `statusline.sh` in `bin/install.js` sources `statusline-helpers.sh` and `statusline-provider.sh`; provider files must remain source-compatible with that generated script.
- `.npmignore` excludes local/generated directories such as `.claude`, `.github`, `.worktrees`, `docs`, and `node_modules` from published packages.

---

*Convention analysis: 2026-06-20*
