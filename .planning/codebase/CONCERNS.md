# Codebase Concerns

**Analysis Date:** 2026-06-20

## Tech Debt

**Packaging allowlist is missing:**
- Issue: `package.json` publishes by default from the workspace instead of declaring an explicit `files` allowlist, and `.npmignore` excludes only a few paths.
- Files: `package.json`, `.npmignore`, `.codex/`, `.planning/codebase/CONCERNS.md`
- Impact: `npm pack --dry-run` includes the untracked `.codex/` workflow/runtime tree because `.npmignore` does not exclude `.codex`; after this map exists, `.planning/` is also publishable unless ignored. The dry-run package surface is 544 files and 6.8 MB unpacked for a CLI whose runtime files are `bin/install.js`, `bin/shared-helpers.sh`, `bin/providers/anthropic.sh`, and `bin/providers/zai.sh`.
- Fix approach: Add a `files` allowlist in `package.json` for `bin/`, `README.md`, and `LICENSE`, or add `.codex`, `.planning`, `.agents`, and other local tooling directories to `.npmignore`.

**No automated quality harness:**
- Issue: There are no test, lint, format, or CI commands in `package.json`.
- Files: `package.json`, `bin/install.js`, `bin/shared-helpers.sh`, `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Impact: Installer file mutation, provider parsing, cache behavior, and cross-platform shell/date behavior can regress without detection.
- Fix approach: Add `npm test`, shell syntax checks, shell linting, and focused installer/provider tests that run without calling external APIs.

**Generated shell script is embedded as a large template string:**
- Issue: `generateStatuslineScript()` owns the installed `statusline.sh` as a long JavaScript template string instead of a separately testable shell source file.
- Files: `bin/install.js`
- Impact: Shell code in `bin/install.js` is harder to lint, run through `bash -n`, diff, and reuse independently from installer logic.
- Fix approach: Move the statusline shell source into `bin/statusline.sh` or a template file, test it directly, and keep installer logic limited to file copy/config mutation.

**Installer has no durable config backup:**
- Issue: Existing `settings.statusLine` is overwritten when it differs from this package's command, but the previous `settings.json` value is not backed up.
- Files: `bin/install.js`
- Impact: Users with an existing Claude Code status line lose that setting on install; uninstall only removes this package's matching command and cannot restore the previous status line config.
- Fix approach: Store a package-owned backup of the previous `statusLine` value and restore it on uninstall when it has not been changed by the user.

## Known Bugs

**Repeated installs can overwrite the original statusline backup:**
- Symptoms: Each install copies the current `statusline.sh` to `statusline.sh.bak`. A second install can replace the user's original backup with a generated package file.
- Files: `bin/install.js`
- Trigger: Run the installer twice against the same `--dir` that already had a user-owned `statusline.sh`.
- Workaround: Manually preserve `statusline.sh.bak` before reinstalling.

**Installer overwrites unrelated statusLine settings:**
- Symptoms: `settings.statusLine` is replaced whenever it does not exactly match this package's command.
- Files: `bin/install.js`
- Trigger: Install into a Claude config directory that already has a different `settings.statusLine.command`.
- Workaround: Manually copy the existing `statusLine` block before install and restore it if needed.

**Inline `--dir=~/...` paths are not expanded:**
- Symptoms: `--dir ~/.claude-z` works through shell tilde expansion, but `--dir=~/.claude-z` is stored as a literal path beginning with `~`.
- Files: `bin/install.js`, `README.md`
- Trigger: Run `npx @thlinh/cc-statusline --dir=~/.claude-z`.
- Workaround: Use `--dir ~/.claude-z` or an absolute path.

**Non-UTC ISO timestamps can format with the wrong instant on macOS fallback:**
- Symptoms: `iso_to_epoch()` strips timezone offsets before calling macOS `date`; offsets such as `+07:00` or `-04:00` are parsed as local wall time rather than the represented instant.
- Files: `bin/shared-helpers.sh`
- Trigger: Provider reset times or session start times include a non-UTC numeric offset and GNU `date -d` is unavailable.
- Workaround: Prefer UTC `Z` timestamps until offset-aware parsing is implemented.

**Z.AI YAML parsing is ad hoc:**
- Symptoms: Token lookup reads only a top-level `api_key:` line and strips whitespace/quotes with `grep`, `sed`, and `tr`; inline comments or nested YAML shapes can be misread.
- Files: `bin/providers/zai.sh`
- Trigger: `~/.chelper/config.yaml` contains anything other than the simple `api_key: value` shape.
- Workaround: Put the token in `${SCRIPT_DIR}/settings.json` under the `ANTHROPIC_AUTH_TOKEN`-compatible env key shape used by the Z.AI provider, or keep `~/.chelper/config.yaml` flat and comment-free.

## Security Considerations

**Workspace-local tooling can be published accidentally:**
- Risk: Publishing from the current workspace includes `.codex/config.toml`, `.codex/agents/`, `.codex/gsd-core/`, `.codex/hooks.json`, and `.codex/skills/` because hidden tooling directories are not ignored by `.npmignore`.
- Files: `.npmignore`, `package.json`, `.codex/`
- Current mitigation: `.gitignore` and `.npmignore` exclude `node_modules`, `.DS_Store`, `docs`, `.worktrees`, and `.claude`; they do not exclude `.codex` or `.planning`.
- Recommendations: Use a positive `files` allowlist in `package.json`; treat `.codex/`, `.planning/`, `.agents/`, and local runtime config paths as never-publish paths.

**Installer target directory is unrestricted:**
- Risk: A caller can point `--dir` at any writable directory, and uninstall removes fixed filenames from that directory.
- Files: `bin/install.js`
- Current mitigation: The CLI only removes `statusline.sh`, `statusline-helpers.sh`, `statusline-provider.sh`, and `statusline-cache.json`, and updates `settings.json` only when the command matches.
- Recommendations: Resolve and display the final target path, reject dangerous targets such as `/`, and require confirmation or a `--force` flag for non-default directories.

**Usage cache permissions rely on process defaults:**
- Risk: `statusline-cache.json` contains account usage/quota response data and is written with shell redirection using the user's current `umask`.
- Files: `bin/install.js`
- Current mitigation: Tokens are not intentionally written to the cache; providers pass tokens only to `curl` headers.
- Recommendations: Write cache atomically with restrictive permissions, and document that cache data is usage metadata rather than credentials.

**Credential fallbacks read local secret stores without visibility:**
- Risk: Providers read `CLAUDE_CODE_OAUTH_TOKEN`, macOS keychain blobs, `${SCRIPT_DIR}/.credentials.json`, Linux `secret-tool`, `${SCRIPT_DIR}/settings.json`, and `~/.chelper/config.yaml`; failures are silent and can make troubleshooting opaque.
- Files: `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Current mitigation: Provider functions avoid logging token values and return an empty token on failure.
- Recommendations: Add debug output gated behind an explicit env var that reports only source names and failure categories, never token values.

## Performance Bottlenecks

**Statusline redraw can block on network calls:**
- Problem: When the cache is older than 60 seconds, each statusline invocation can call the provider API with `curl --max-time 5`.
- Files: `bin/install.js`, `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Cause: Usage fetching is synchronous inside the command Claude Code runs for status rendering.
- Improvement path: Keep the statusline path cache-first and background-refresh usage data, or reduce the blocking timeout and expose stale-cache indicators.

**Git dirty detection can be slow in large repos:**
- Problem: Every statusline run calls `git -C "$cwd" --no-optional-locks status --porcelain` when inside a worktree.
- Files: `bin/install.js`
- Cause: Dirty-state calculation scans worktree state synchronously during prompt/status rendering.
- Improvement path: Cache git status briefly, make dirty detection optional, or use lighter checks for branch-only display.

**Multiple JSON parses per render:**
- Problem: The generated statusline script invokes `jq` repeatedly for the same input JSON and cache file.
- Files: `bin/install.js`
- Cause: Fields are extracted one-by-one rather than through a single `jq` projection.
- Improvement path: Extract statusline input fields in one `jq` call, and parse cache/provider data once per render.

## Fragile Areas

**Provider API schemas are hard-coded:**
- Files: `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Why fragile: The Anthropic provider expects `.five_hour`, `.seven_day`, and `.extra_usage`; the Z.AI provider expects `.data.limits[]` entries with `TOKENS_LIMIT` and `TIME_LIMIT`.
- Safe modification: Keep provider parsing behind `format_usage_lines()` and add fixture tests for successful responses, missing fields, nulls, and API error payloads.
- Test coverage: No provider fixtures or tests are present.

**Cross-platform command behavior is hand-rolled:**
- Files: `bin/shared-helpers.sh`, `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Why fragile: The scripts branch across GNU/macOS `date`, `stat`, `shasum`/`sha256sum`, `security`, `secret-tool`, and `timeout`.
- Safe modification: Centralize platform detection helpers in `bin/shared-helpers.sh` and test them under macOS and Linux shells.
- Test coverage: `bash -n` passes locally for the checked shell files, but `shellcheck` is not installed and there are no cross-platform tests.

**Cache writes are non-atomic:**
- Files: `bin/install.js`
- Why fragile: Concurrent statusline invocations can write `statusline-cache.json` at the same time, leaving truncated or invalid JSON.
- Safe modification: Write to a temporary file in the same directory and rename it into place after `jq` validates the payload.
- Test coverage: No concurrency or corrupted-cache tests are present.

**Installer combines parsing, prompting, filesystem mutation, and generated script content:**
- Files: `bin/install.js`
- Why fragile: A single file owns CLI parsing, dependency checks, provider prompting, install/uninstall mutation, backup behavior, settings mutation, and the generated runtime script.
- Safe modification: Split argument parsing, settings mutation, file installation, and statusline template generation into separate functions/modules with unit tests.
- Test coverage: No installer tests are present.

## Scaling Limits

**Package size scales with local workspace artifacts:**
- Current capacity: `npm pack --dry-run` from this workspace reports 544 files and 6.8 MB unpacked.
- Limit: Any additional local hidden tooling directory that is not ignored can be shipped in the package.
- Scaling path: Use `package.json.files` as a publish allowlist so package size tracks only runtime assets.

**Statusline work scales with repository size and API latency:**
- Current capacity: Each render performs synchronous JSON parsing, optional git status, optional keychain/config lookup, and optional API fetch.
- Limit: Large repositories and slow provider APIs increase prompt/status rendering latency.
- Scaling path: Cache git/API results independently and make slow decorations optional.

## Dependencies at Risk

**Anthropic OAuth usage endpoint:**
- Risk: The provider calls `https://api.anthropic.com/api/oauth/usage` with a hard-coded beta header and `User-Agent`.
- Impact: API, header, or response-shape changes can silently remove Anthropic usage display.
- Migration plan: Isolate endpoint metadata in provider config, handle explicit error payloads, and maintain response fixtures for expected shapes.

**Z.AI quota endpoint:**
- Risk: The provider calls `https://api.z.ai/api/monitor/usage/quota/limit` and assumes current field names.
- Impact: Z.AI usage lines disappear or arithmetic fails when the quota response shape changes.
- Migration plan: Add schema-tolerant parsing and fixture coverage for each supported Z.AI response version.

**System tools are unmanaged runtime dependencies:**
- Risk: `jq` and `curl` are required at install/runtime, while `git`, `security`, `secret-tool`, `timeout`, `shasum`, `sha256sum`, `stat`, and platform-specific `date` behavior affect optional features.
- Impact: Users on Linux, macOS, minimal containers, or nonstandard shells can get partial output with little diagnostic context.
- Migration plan: Add dependency diagnostics per feature, document Linux install commands, and gate optional capabilities cleanly.

## Missing Critical Features

**No dry-run or plan mode for installer mutations:**
- Problem: Users cannot preview which files and settings will be changed before install/uninstall.
- Blocks: Safe adoption in shared dotfile workflows and scripted environments.

**No package publish guard:**
- Problem: There is no prepack check that fails when `.codex/`, `.planning/`, `.claude/`, `node_modules/`, or other local-only directories are included.
- Blocks: Safe npm publishing from a development workspace.

**No explicit noninteractive confirmation contract:**
- Problem: Passing `--provider` skips the provider prompt, but there is no `--yes`, `--dry-run`, or machine-readable output mode.
- Blocks: Reliable use from provisioning scripts that need deterministic behavior and audit logs.

## Test Coverage Gaps

**Installer backup and settings behavior:**
- What's not tested: First install, reinstall, uninstall with a backup, uninstall without a backup, existing unrelated `settings.statusLine`, invalid `settings.json`, and path handling for `--dir` forms.
- Files: `bin/install.js`
- Risk: User config can be overwritten or fail to restore.
- Priority: High

**Provider parsing and authentication source selection:**
- What's not tested: Anthropic keychain/file/env fallback ordering, Z.AI settings/config fallback ordering, missing token behavior, malformed JSON, missing fields, and API error bodies.
- Files: `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Risk: Usage data silently disappears or displays incorrect percentages.
- Priority: High

**Generated statusline render path:**
- What's not tested: Claude Code input parsing, context percentage math, session duration, effort display, git branch/dirty display, cache freshness, stale cache fallback, and empty input fallback.
- Files: `bin/install.js`, `bin/shared-helpers.sh`
- Risk: The main user-facing statusline can break despite `bin/install.js` remaining syntactically valid JavaScript.
- Priority: High

**Cross-platform shell helpers:**
- What's not tested: GNU/macOS `date`, `stat`, timezone offsets, `shasum`/`sha256sum` fallback, missing `timeout`, and shells with different default `umask`.
- Files: `bin/shared-helpers.sh`, `bin/providers/anthropic.sh`, `bin/install.js`
- Risk: Features work on one developer machine but fail for users on another platform.
- Priority: Medium

**Packaging contents:**
- What's not tested: `npm pack --dry-run` output and tarball file allowlist.
- Files: `package.json`, `.npmignore`
- Risk: Local workflow artifacts or generated planning files ship to npm.
- Priority: High

---

*Concerns audit: 2026-06-20*
