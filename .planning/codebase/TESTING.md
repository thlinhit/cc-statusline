# Testing Patterns

**Analysis Date:** 2026-06-20

## Test Framework

**Runner:**
- Not detected. `package.json` defines package metadata and the `cc-statusline` binary, but no `scripts.test` command.
- Not detected: `jest.config.*`, `vitest.config.*`, `ava.config.*`, `tap.config.*`, `c8.config.*`, or `nyc.config.*`.

**Assertion Library:**
- Not detected. No assertion library dependency or import is present in `package.json` or source files.

**Run Commands:**
```bash
# Not detected: no repo test command is defined in package.json.
# Not detected: no watch command is defined.
# Not detected: no coverage command is defined.
```

## Test File Organization

**Location:**
- No test directory or co-located test files are present.
- Source files currently live under `bin/`: `bin/install.js`, `bin/shared-helpers.sh`, `bin/providers/anthropic.sh`, `bin/providers/zai.sh`.

**Naming:**
- Not detected. Repository scan found no `*.test.*` or `*.spec.*` files.

**Structure:**
```text
cc-statusline/
├── bin/                    # Runtime source only
│   ├── install.js          # Executable Node installer
│   ├── shared-helpers.sh   # Bash helper functions
│   └── providers/          # Bash provider implementations
└── package.json            # No test scripts
```

## Test Structure

**Suite Organization:**
```javascript
// Not detected in repo.
// No describe/test/expect or node:test pattern exists yet.
```

**Patterns:**
- Setup pattern: Not detected.
- Teardown pattern: Not detected.
- Assertion pattern: Not detected.
- Async testing pattern: Not detected.
- CLI invocation testing pattern: Not detected.

## Mocking

**Framework:** Not detected

**Patterns:**
```javascript
// Not detected in repo.
// No mocking helper, fixture loader, or dependency injection test pattern exists yet.
```

**What to Mock:**
- No current repo mocking standard exists. Any future tests for `bin/install.js` need isolation around filesystem writes to target Claude directories, especially generated `statusline.sh`, `statusline-helpers.sh`, `statusline-provider.sh`, `settings.json`, and `statusline-cache.json`.
- Any future tests for dependency checks in `bin/install.js` need isolation around `child_process.execSync` calls for `jq`, `curl`, and optional `git`.
- Any future tests for provider scripts need controlled command responses for `curl`, `jq`, `security`, `secret-tool`, `git`, `date`, `shasum`, and `sha256sum`.
- Any future tests for token lookup should use config key names only (`CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_AUTH_TOKEN`, `api_key`) and must not use real credential values.

**What NOT to Mock:**
- No established rule is present. Given current source shape, pure formatting helpers in `bin/shared-helpers.sh` can be exercised with real shell execution and sample inputs when a test runner is introduced.
- Do not mock away the generated-script contract between `bin/install.js`, `bin/shared-helpers.sh`, and `bin/providers/*.sh`; compatibility among those files is core behavior.

## Fixtures and Factories

**Test Data:**
```json
{
  "model": { "display_name": "Claude" },
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 0,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 0
    }
  },
  "cwd": "/path/to/project",
  "session": { "start_time": "2026-06-20T00:00:00Z" }
}
```

**Location:**
- Not detected. No `fixtures/`, `test/fixtures/`, or sample JSON files are present.
- The input shape above is inferred from fields read by the generated statusline script inside `bin/install.js`; it is not stored as a repo fixture.

## Coverage

**Requirements:** None enforced

**View Coverage:**
```bash
# Not detected: no coverage tool or coverage script is configured.
```

## Test Types

**Unit Tests:**
- Not present. Candidate units from current source are JavaScript helpers in `bin/install.js` and Bash formatting helpers in `bin/shared-helpers.sh`.

**Integration Tests:**
- Not present. Current integration surfaces are installer file copying/settings mutation in `bin/install.js` and provider API formatting in `bin/providers/anthropic.sh` and `bin/providers/zai.sh`.

**E2E Tests:**
- Not used. There is no automated test that installs `cc-statusline` into a temporary Claude config directory and invokes generated `statusline.sh`.

## Common Patterns

**Async Testing:**
```javascript
// Not detected.
// The async production path is getProvider(args) and run() in bin/install.js.
```

**Error Testing:**
```javascript
// Not detected.
// Fatal production paths call fail(...) and process.exit(1) in bin/install.js.
```

**Manual Verification Surface:**
- README install commands exercise the published CLI path through `npx @thlinh/cc-statusline`.
- README uninstall commands exercise `bin/install.js` with `--uninstall`.
- Provider behavior depends on local tools and config paths documented by source files: `jq`, `curl`, optional `git`, macOS `security`, Linux `secret-tool`, `settings.json`, and `~/.chelper/config.yaml`.

---

*Testing analysis: 2026-06-20*
