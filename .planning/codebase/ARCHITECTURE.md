<!-- refreshed: 2026-06-20 -->
# Architecture

**Analysis Date:** 2026-06-20

## System Overview

```text
+-------------------------------------------------------------+
|                   Published CLI Package                      |
|                    `package.json`                            |
+-------------------+-------------------+---------------------+
| Installer/CLI     | Generated runtime | Provider modules    |
| `bin/install.js`  | `statusline.sh`   | `bin/providers/`   |
+---------+---------+---------+---------+----------+----------+
          |                   |                    |
          v                   v                    v
+-------------------------------------------------------------+
|                  Shared shell helpers                        |
|                  `bin/shared-helpers.sh`                     |
+-------------------------------------------------------------+
          |
          v
+-------------------------------------------------------------+
|       User Claude config directory and provider APIs          |
|       `~/.claude/settings.json`, `statusline-cache.json`     |
+-------------------------------------------------------------+

+-------------------------------------------------------------+
|               Local GSD workflow tooling layer                |
|               `.codex/config.toml`, `.codex/skills/`          |
+-------------------+-------------------+---------------------+
| Agent prompts     | Workflows         | CJS tooling         |
| `.codex/agents/`  | `.codex/gsd-core/workflows/` | `.codex/gsd-core/bin/` |
+-------------------------------------------------------------+
          |
          v
+-------------------------------------------------------------+
|                  Planning artifacts                           |
|                  `.planning/`                                 |
+-------------------------------------------------------------+
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Package manifest | Declares the package name, version, metadata, and `cc-statusline` executable mapping. | `package.json` |
| Installer entrypoint | Parses CLI flags, checks host dependencies, prompts or validates provider selection, installs/uninstalls files, and updates Claude settings. | `bin/install.js` |
| Generated statusline script | Reads Claude Code statusline JSON from stdin, extracts model/context/session/git data, fetches provider usage through the provider contract, caches usage data, and prints the statusline. | `bin/install.js` |
| Shared shell helpers | Provides colors, token formatting, percentage coloring, visual bar building, ISO timestamp parsing, and reset-time formatting for generated and provider scripts. | `bin/shared-helpers.sh` |
| Anthropic provider | Supplies Anthropic token lookup, usage API fetching, and formatting for current, weekly, and extra usage lines. | `bin/providers/anthropic.sh` |
| Z.AI provider | Supplies Z.AI token lookup, usage quota fetching, and formatting for token and tool usage lines. | `bin/providers/zai.sh` |
| User documentation | Describes installation commands, dependencies, providers, uninstall behavior, and installed files. | `README.md` |
| NPM publish filters | Excludes local, docs, demo, and dependency directories from the npm package payload. | `.npmignore` |
| Local GSD agent registry | Registers GSD agents and maps each agent name to a `.toml` file. | `.codex/config.toml` |
| GSD hooks | Runs update and context-monitoring hooks for Codex/GSD sessions. | `.codex/hooks.json` |
| GSD command dispatcher | Central CLI utility for GSD workflow operations, command routing, state, phase, roadmap, validation, and codebase mapping commands. | `.codex/gsd-core/bin/gsd-tools.cjs` |
| GSD skill surface | Exposes local GSD command skills; mapper-specific instructions live in `gsd-map-codebase`. | `.codex/skills/gsd-map-codebase/SKILL.md` |
| Codebase map output | Stores generated architecture and structure maps consumed by GSD planning/execution workflows. | `.planning/codebase/` |

## Pattern Overview

**Overall:** Small Node installer that emits a shell-based statusline runtime, plus a local GSD workflow bundle.

**Key Characteristics:**
- The published app has a single Node executable entrypoint: `package.json` maps `cc-statusline` to `bin/install.js`.
- The runtime statusline is generated as shell text by `generateStatuslineScript()` in `bin/install.js`, then installed into a user-selected Claude config directory.
- Provider-specific API behavior is isolated behind a shell function contract: `get_provider_token`, `fetch_usage_data`, and `format_usage_lines`.
- Shared formatting and time helpers are sourced by the generated script from `statusline-helpers.sh`.
- Runtime state is file-based: Claude settings live in the target config directory, usage cache lives in `statusline-cache.json`, and GSD planning state lives in `.planning/`.
- `.codex/` is a local GSD tooling layer with skills, workflows, agents, hooks, and CJS command utilities; it is separate from the tracked package payload.

## Layers

**Package Declaration:**
- Purpose: Define how npm exposes the CLI and identify package metadata.
- Location: `package.json`
- Contains: Package name, version, repository metadata, and `bin.cc-statusline`.
- Depends on: Not applicable.
- Used by: `npx @thlinh/cc-statusline` and package consumers.

**Installer Layer:**
- Purpose: Own installation and uninstallation workflows.
- Location: `bin/install.js`
- Contains: Argument parsing, dependency checks, provider selection, file copying, chmod, backup/restore, generated script creation, and `settings.json` mutation.
- Depends on: Node built-ins `fs`, `path`, `os`, `readline`, and `child_process`.
- Used by: The npm `cc-statusline` command declared in `package.json`.

**Generated Runtime Layer:**
- Purpose: Produce the actual Claude Code statusline on each statusline invocation.
- Location: Generated from `bin/install.js` into `<targetDir>/statusline.sh`.
- Contains: Stdin JSON parsing, model/context/session/git extraction, provider usage cache management, provider function calls, and terminal output formatting.
- Depends on: `jq`, `curl`, optional `git`, `statusline-helpers.sh`, and `statusline-provider.sh`.
- Used by: Claude Code through the `statusLine.command` entry written to `<targetDir>/settings.json`.

**Shared Shell Utility Layer:**
- Purpose: Keep provider scripts and generated statusline output consistent.
- Location: `bin/shared-helpers.sh`
- Contains: Color constants, token formatter, percentage color selector, progress bar builder, cross-platform ISO time parsing, and reset-time formatting.
- Depends on: Shell built-ins plus `awk`, `date`, `sed`, and `tr`.
- Used by: The generated `statusline.sh` and provider scripts copied into the target directory.

**Provider Layer:**
- Purpose: Encapsulate external API token discovery, request, validation, and provider-specific usage display.
- Location: `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Contains: The `get_provider_token`, `fetch_usage_data`, and `format_usage_lines` shell functions.
- Depends on: `curl`, `jq`, provider-specific local credential stores, and shared helper functions.
- Used by: The generated `statusline.sh` after it sources `statusline-provider.sh`.

**Local GSD Workflow Layer:**
- Purpose: Provide project-local GSD skills, agents, workflows, templates, hooks, and CLI utilities for planning and codebase mapping.
- Location: `.codex/`
- Contains: `.codex/skills/*/SKILL.md`, `.codex/agents/*`, `.codex/gsd-core/workflows/*.md`, `.codex/gsd-core/bin/*.cjs`, `.codex/hooks/*.js`, and `.codex/config.toml`.
- Depends on: Node, Codex/GSD runtime conventions, and `.planning/` project state when present.
- Used by: GSD commands such as `gsd-map-codebase`, `gsd-plan-phase`, and `gsd-execute-phase`.

## Data Flow

### Primary Install Path

1. NPM invokes the package executable declared at `package.json:5` and `package.json:6`.
2. `run()` starts in `bin/install.js:361` and calls `parseArgs()` from `bin/install.js:33`.
3. `checkDeps()` verifies required host tools `jq` and `curl` and optional `git` in `bin/install.js:53`.
4. `getProvider()` validates `--provider` or prompts through `promptProvider()` in `bin/install.js:82` and `bin/install.js:108`.
5. The target directory defaults to `~/.claude` unless `--dir` is supplied in `bin/install.js:365`.
6. Existing `statusline.sh` is backed up to `statusline.sh.bak` in `bin/install.js:427`.
7. `bin/shared-helpers.sh` is copied to `statusline-helpers.sh` in `bin/install.js:433`.
8. The selected provider script from `bin/providers/` is copied to `statusline-provider.sh` in `bin/install.js:438`.
9. `generateStatuslineScript()` creates `statusline.sh` in `bin/install.js:207`, and `run()` writes it in `bin/install.js:445`.
10. `settings.statusLine` is set to `bash "<targetDir>/statusline.sh"` in `bin/install.js:462`.

### Runtime Statusline Path

1. Claude Code invokes the installed `statusline.sh` command written by `bin/install.js:462`.
2. The generated script reads the statusline JSON payload from stdin in `bin/install.js:217`.
3. The generated script resolves `SCRIPT_DIR`, then sources `statusline-helpers.sh` and `statusline-provider.sh` in `bin/install.js:224`, `bin/install.js:227`, and `bin/install.js:230`.
4. Model, context window, token usage, and effort level are extracted with `jq` in `bin/install.js:233`.
5. Git branch and dirty state are detected with `git -C "$cwd"` in `bin/install.js:266`.
6. Session duration is calculated from `.session.start_time` in `bin/install.js:275`.
7. Provider usage data is read from or written to `statusline-cache.json` with a 60-second cache window in `bin/install.js:312`.
8. The generated script calls `get_provider_token`, `fetch_usage_data`, and `format_usage_lines` in `bin/install.js:333`, `bin/install.js:335`, and `bin/install.js:349`.
9. Formatted output is printed in `bin/install.js:352`.

### Provider Usage Path

1. Anthropic token lookup checks `CLAUDE_CODE_OAUTH_TOKEN`, macOS Keychain, `${SCRIPT_DIR}/.credentials.json`, and Linux `secret-tool` in `bin/providers/anthropic.sh:23`.
2. Anthropic usage data is fetched from the Anthropic OAuth usage endpoint in `bin/providers/anthropic.sh:75`.
3. Anthropic usage lines are formatted from `five_hour`, `seven_day`, and optional `extra_usage` fields in `bin/providers/anthropic.sh:97`.
4. Z.AI token lookup checks `${SCRIPT_DIR}/settings.json` for `env.ANTHROPIC_AUTH_TOKEN`, then `~/.chelper/config.yaml` for `api_key` in `bin/providers/zai.sh:7`.
5. Z.AI quota data is fetched from the Z.AI quota endpoint in `bin/providers/zai.sh:38`.
6. Z.AI usage lines are formatted from `TOKENS_LIMIT` and `TIME_LIMIT` entries in `bin/providers/zai.sh:58`.

### Uninstall Path

1. `run()` detects `--uninstall` and calls `uninstall(targetDir)` in `bin/install.js:367`.
2. `uninstall()` restores `statusline.sh.bak` when present or removes installed files in `bin/install.js:121`.
3. `statusLine` is removed from `<targetDir>/settings.json` only when it matches the expected generated command in `bin/install.js:178`.
4. Runtime cache `statusline-cache.json` is removed when present in `bin/install.js:125`.

### GSD Mapping Path

1. `gsd-map-codebase` is exposed as a project skill at `.codex/skills/gsd-map-codebase/SKILL.md`.
2. The mapper agent is registered in `.codex/config.toml` as `agents.gsd-codebase-mapper`.
3. The mapper agent contract lives in `.codex/agents/gsd-codebase-mapper.md` and `.codex/agents/gsd-codebase-mapper.toml`.
4. The map-codebase workflow lives in `.codex/gsd-core/workflows/map-codebase.md`.
5. Shared GSD command routing runs through `.codex/gsd-core/bin/gsd-tools.cjs`.
6. Generated codebase map artifacts are written to `.planning/codebase/`.

**State Management:**
- Installer state is local to one Node process in `bin/install.js`.
- Runtime statusline cache is file-based at `<targetDir>/statusline-cache.json`.
- Claude integration state is file-based at `<targetDir>/settings.json`.
- Provider credentials are read from environment variables or external credential stores; do not persist provider token values in this repo.
- GSD workflow state is file-based under `.planning/`, with local runtime configuration under `.codex/`.

## Key Abstractions

**Provider Contract:**
- Purpose: Allow the generated statusline script to call provider-specific code without branching on provider internals.
- Examples: `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Pattern: Shell plugin contract with required functions `get_provider_token`, `fetch_usage_data`, and `format_usage_lines`.

**Generated Script Template:**
- Purpose: Keep installation-time provider selection embedded in the installed `statusline.sh`.
- Examples: `generateStatuslineScript(provider)` in `bin/install.js`
- Pattern: Template string emitted to a user config directory, then executed independently by Claude Code.

**Shared Helper Library:**
- Purpose: Centralize shell display and timestamp primitives used by generated and provider scripts.
- Examples: `format_tokens`, `color_for_pct`, `build_bar`, `iso_to_epoch`, `format_reset_time` in `bin/shared-helpers.sh`
- Pattern: Sourced shell library.

**Target Directory:**
- Purpose: Group the installed script, helper, provider, cache, settings, and optional credential file.
- Examples: Default `~/.claude`, custom `--dir ~/.claude-z`, generated paths in `bin/install.js`
- Pattern: File-based runtime root.

**GSD Skill:**
- Purpose: Map a command-style workflow to instructions consumed by Codex/GSD.
- Examples: `.codex/skills/gsd-map-codebase/SKILL.md`, `.codex/skills/gsd-plan-phase/SKILL.md`
- Pattern: One `SKILL.md` per `gsd-*` command directory.

**GSD Agent Pair:**
- Purpose: Register model/runtime metadata and long-form agent instructions.
- Examples: `.codex/agents/gsd-codebase-mapper.toml`, `.codex/agents/gsd-codebase-mapper.md`
- Pattern: Paired `.toml` config and `.md` prompt files.

**GSD CJS Router:**
- Purpose: Centralize workflow CLI operations and dispatch command families.
- Examples: `.codex/gsd-core/bin/gsd-tools.cjs`, `.codex/gsd-core/bin/lib/command-routing-hub.cjs`
- Pattern: Node CommonJS command router with many `bin/lib/*.cjs` domain modules.

## Entry Points

**NPM CLI Entry:**
- Location: `package.json`
- Triggers: `npx @thlinh/cc-statusline` or installed `cc-statusline`.
- Responsibilities: Map `cc-statusline` to `bin/install.js`.

**Installer Runtime:**
- Location: `bin/install.js`
- Triggers: Direct Node execution through npm bin.
- Responsibilities: Install, uninstall, copy provider files, generate statusline script, and mutate Claude settings.

**Installed Statusline Command:**
- Location: Generated `<targetDir>/statusline.sh` from `bin/install.js`
- Triggers: Claude Code statusline hook executing the configured `statusLine.command`.
- Responsibilities: Read statusline JSON, derive display fields, call provider code, cache usage data, and render output.

**Provider Modules:**
- Location: `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Triggers: Sourcing by generated `statusline-provider.sh`.
- Responsibilities: Implement token lookup, API fetch, and provider-specific formatting.

**GSD CLI Utility:**
- Location: `.codex/gsd-core/bin/gsd-tools.cjs`
- Triggers: GSD workflows and local runtime hooks.
- Responsibilities: Route state, phase, roadmap, validation, mapping, and capability commands.

**GSD Hooks:**
- Location: `.codex/hooks/gsd-check-update.js`, `.codex/hooks/gsd-context-monitor.js`
- Triggers: Hook events configured in `.codex/hooks.json`.
- Responsibilities: Check GSD updates and inject context usage warnings from temporary statusline bridge files.

## Architectural Constraints

- **Threading:** `bin/install.js` runs as a single Node process. Generated `statusline.sh` and provider scripts run as single shell processes per Claude statusline invocation. GSD hooks run as separate Node processes from `.codex/hooks/*.js`.
- **Global state:** Package-level constants in `bin/install.js` and color variables in `bin/shared-helpers.sh` are module/script globals. Runtime mutable state is persisted in `<targetDir>/settings.json`, `<targetDir>/statusline-cache.json`, and GSD temp files under `/tmp` from `.codex/hooks/gsd-context-monitor.js`.
- **Circular imports:** Not detected in the tracked package files. `.codex/gsd-core/bin/gsd-tools.cjs` imports many CJS modules from `.codex/gsd-core/bin/lib/`; treat that dispatcher as the dependency root for GSD CLI operations.
- **Provider compatibility:** Every file under `bin/providers/` must implement `get_provider_token`, `fetch_usage_data`, and `format_usage_lines` because the generated runtime calls those names directly.
- **Generated-file ownership:** Do not edit installed `<targetDir>/statusline.sh` manually; edit `generateStatuslineScript()` in `bin/install.js` and reinstall.
- **Secret handling:** Do not commit provider token values. Runtime code references `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_AUTH_TOKEN`, `${SCRIPT_DIR}/.credentials.json`, and `~/.chelper/config.yaml`; documents and logs should mention only key names and file paths.
- **Published package boundary:** Git-tracked package code is `package.json`, `README.md`, `.npmignore`, `.gitignore`, `.github/demo.png`, and `bin/`. Local `.codex/` tooling is present in the workspace but not listed by `git ls-files`.

## Anti-Patterns

### Editing Installed Runtime Files

**What happens:** A change is made directly in `<targetDir>/statusline.sh`, `<targetDir>/statusline-helpers.sh`, or `<targetDir>/statusline-provider.sh`.
**Why it's wrong:** Reinstall overwrites generated/copied runtime files, and the repo source no longer explains the installed behavior.
**Do this instead:** Edit `generateStatuslineScript()` in `bin/install.js`, shared helper functions in `bin/shared-helpers.sh`, or provider functions in `bin/providers/`.

### Breaking the Provider Function Contract

**What happens:** A provider file omits or renames `get_provider_token`, `fetch_usage_data`, or `format_usage_lines`.
**Why it's wrong:** The generated script calls these functions by fixed names in `bin/install.js:333`, `bin/install.js:335`, and `bin/install.js:349`.
**Do this instead:** Add provider-specific behavior inside the required functions in `bin/providers/<provider>.sh`, then update provider validation and selection in `bin/install.js`.

### Putting Statusline Package Features in `.codex/`

**What happens:** A feature for the npm statusline package is implemented under `.codex/`.
**Why it's wrong:** `.codex/` is local GSD workflow tooling, not the published package entrypoint or runtime payload.
**Do this instead:** Put user-facing statusline package code in `bin/install.js`, `bin/shared-helpers.sh`, or `bin/providers/`.

### Adding Runtime Dependencies Without Installer Checks

**What happens:** Generated shell code starts calling a new command without updating dependency checks.
**Why it's wrong:** `checkDeps()` in `bin/install.js` is the only install-time dependency gate, and missing tools fail later inside Claude statusline execution.
**Do this instead:** Add required command detection to `checkDeps()` in `bin/install.js` and document it in `README.md`.

## Error Handling

**Strategy:** Fail fast during install, degrade quietly during statusline rendering, and keep GSD hooks non-blocking.

**Patterns:**
- `bin/install.js` uses `fail()` plus `process.exit(1)` for missing dependencies, missing source files, and invalid `settings.json`.
- `bin/install.js` warns and defaults to Anthropic for unknown provider flags.
- Generated shell code suppresses provider/API errors with `2>/dev/null`, falls back to cached data when available, and prints a minimal statusline if no usage data exists.
- Provider scripts return non-zero from `fetch_usage_data()` when tokens are empty or API responses do not match expected JSON.
- `.codex/hooks/gsd-context-monitor.js` and `.codex/hooks/gsd-check-update.js` swallow hook failures so hook errors do not block tool execution.

## Cross-Cutting Concerns

**Logging:** `bin/install.js` uses colored `console.log` and `console.error` helpers. Generated shell/provider scripts print only statusline output, not diagnostics. GSD hooks produce JSON hook output or exit silently.
**Validation:** `bin/install.js` validates supported provider names, source file presence, dependency commands, and parseability of target `settings.json`. Provider scripts validate API response shape with `jq -e`.
**Authentication:** No app-level auth layer exists. Provider API auth is bearer-token based and resolved at runtime from environment variables or external credential stores.
**Caching:** Generated statusline code caches provider usage in `<targetDir>/statusline-cache.json` for 60 seconds.
**Configuration:** User-facing statusline configuration is written to `<targetDir>/settings.json`; GSD workflow configuration is under `.codex/` and `.planning/`.

---

*Architecture analysis: 2026-06-20*
