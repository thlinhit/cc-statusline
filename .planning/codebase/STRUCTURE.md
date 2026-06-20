# Codebase Structure

**Analysis Date:** 2026-06-20

## Directory Layout

```text
cc-statusline/
|-- bin/                         # Published CLI installer and shell runtime sources
|   |-- install.js               # npm bin entrypoint and generated statusline template
|   |-- shared-helpers.sh        # shared shell formatting/time helpers
|   `-- providers/               # provider-specific shell implementations
|       |-- anthropic.sh         # Anthropic usage provider
|       `-- zai.sh               # Z.AI usage provider
|-- .codex/                      # local GSD tooling layer in the workspace
|   |-- agents/                  # GSD agent prompt/config pairs
|   |-- gsd-core/                # GSD workflows, templates, references, and CJS tools
|   |-- hooks/                   # GSD hook scripts
|   |-- scripts/                 # GSD maintenance scripts
|   |-- skills/                  # one SKILL.md directory per gsd command
|   |-- config.toml              # Codex agent registry
|   `-- hooks.json               # Codex hook event configuration
|-- .planning/
|   `-- codebase/                # generated codebase map documents
|-- .github/                     # demo image for README
|-- .claude/                     # ignored local Claude settings
|-- node_modules/                # ignored installed dependencies
|-- package.json                 # package metadata and bin mapping
|-- README.md                    # user-facing docs
|-- LICENSE                      # MIT license
|-- .npmignore                   # npm publish exclusions
`-- .gitignore                   # git ignore rules
```

## Directory Purposes

**`bin/`:**
- Purpose: Contains the source code for the published `cc-statusline` package.
- Contains: One Node installer file and shell sources copied/generated into a Claude config directory.
- Key files: `bin/install.js`, `bin/shared-helpers.sh`
- Subdirectories: `bin/providers/`

**`bin/providers/`:**
- Purpose: Holds provider-specific API integration code behind the shared provider function contract.
- Contains: Shell scripts named by provider key.
- Key files: `bin/providers/anthropic.sh`, `bin/providers/zai.sh`
- Subdirectories: None.

**`.codex/`:**
- Purpose: Stores local GSD/Codex runtime tooling for this workspace.
- Contains: Agent configs, skills, workflows, hooks, templates, references, generated manifests, and helper scripts.
- Key files: `.codex/config.toml`, `.codex/hooks.json`, `.codex/gsd-core/bin/gsd-tools.cjs`
- Subdirectories: `.codex/agents/`, `.codex/gsd-core/`, `.codex/hooks/`, `.codex/scripts/`, `.codex/skills/`

**`.codex/agents/`:**
- Purpose: Defines GSD subagent behavior and runtime config.
- Contains: Paired `.md` instruction files and `.toml` runtime config files.
- Key files: `.codex/agents/gsd-codebase-mapper.md`, `.codex/agents/gsd-codebase-mapper.toml`, `.codex/agents/gsd-planner.md`, `.codex/agents/gsd-executor.md`
- Subdirectories: None.

**`.codex/gsd-core/`:**
- Purpose: Stores the local GSD workflow engine resources.
- Contains: CJS command tooling, workflows, templates, references, contexts, and version metadata.
- Key files: `.codex/gsd-core/bin/gsd-tools.cjs`, `.codex/gsd-core/bin/gsd_run`, `.codex/gsd-core/workflows/map-codebase.md`, `.codex/gsd-core/templates/codebase/architecture.md`
- Subdirectories: `.codex/gsd-core/bin/`, `.codex/gsd-core/workflows/`, `.codex/gsd-core/templates/`, `.codex/gsd-core/references/`, `.codex/gsd-core/contexts/`

**`.codex/gsd-core/bin/`:**
- Purpose: Provides executable GSD command utilities.
- Contains: Node CJS entrypoints, a shell launcher, shared manifests, and domain-specific CJS modules.
- Key files: `.codex/gsd-core/bin/gsd-tools.cjs`, `.codex/gsd-core/bin/gsd_run`, `.codex/gsd-core/bin/check-latest-version.cjs`
- Subdirectories: `.codex/gsd-core/bin/lib/`, `.codex/gsd-core/bin/shared/`

**`.codex/gsd-core/bin/lib/`:**
- Purpose: Holds the GSD command implementation modules imported by `.codex/gsd-core/bin/gsd-tools.cjs`.
- Contains: CommonJS modules for state, phases, roadmap, verification, config, runtime hooks, workstreams, drift detection, and capability routing.
- Key files: `.codex/gsd-core/bin/lib/state.cjs`, `.codex/gsd-core/bin/lib/phase.cjs`, `.codex/gsd-core/bin/lib/verify.cjs`, `.codex/gsd-core/bin/lib/config-loader.cjs`, `.codex/gsd-core/bin/lib/command-routing-hub.cjs`

**`.codex/gsd-core/workflows/`:**
- Purpose: Contains multi-step GSD workflow definitions consumed by skills and agents.
- Contains: Markdown workflow files and workflow-specific subdirectories.
- Key files: `.codex/gsd-core/workflows/map-codebase.md`, `.codex/gsd-core/workflows/plan-phase.md`, `.codex/gsd-core/workflows/execute-phase.md`, `.codex/gsd-core/workflows/discuss-phase.md`
- Subdirectories: `.codex/gsd-core/workflows/discuss-phase/`, `.codex/gsd-core/workflows/execute-phase/`, `.codex/gsd-core/workflows/help/`

**`.codex/gsd-core/templates/`:**
- Purpose: Stores reusable Markdown/JSON templates for GSD project artifacts.
- Contains: Planning templates, phase templates, codebase map templates, security templates, and research templates.
- Key files: `.codex/gsd-core/templates/project.md`, `.codex/gsd-core/templates/roadmap.md`, `.codex/gsd-core/templates/codebase/architecture.md`, `.codex/gsd-core/templates/codebase/structure.md`
- Subdirectories: `.codex/gsd-core/templates/codebase/`, `.codex/gsd-core/templates/research-project/`

**`.codex/gsd-core/references/`:**
- Purpose: Stores reusable GSD reference guidance for planning, execution, verification, research, and UI workflows.
- Contains: Markdown references and fixture directories.
- Key files: `.codex/gsd-core/references/project-skills-discovery.md`, `.codex/gsd-core/references/planner-guidance.md`, `.codex/gsd-core/references/verification-patterns.md`
- Subdirectories: `.codex/gsd-core/references/few-shot-examples/`, `.codex/gsd-core/references/edge-probe-fixtures/`, `.codex/gsd-core/references/prohibition-probe-fixtures/`

**`.codex/hooks/`:**
- Purpose: Implements local GSD hook behavior.
- Contains: Node scripts run by Codex hook events.
- Key files: `.codex/hooks/gsd-check-update.js`, `.codex/hooks/gsd-context-monitor.js`
- Subdirectories: None.

**`.codex/scripts/`:**
- Purpose: Stores GSD maintenance utilities.
- Contains: CommonJS scripts and helper libraries.
- Key files: `.codex/scripts/fix-slash-commands.cjs`, `.codex/scripts/changeset/cli.cjs`, `.codex/scripts/lib/allowlist-ratchet.cjs`
- Subdirectories: `.codex/scripts/changeset/`, `.codex/scripts/lib/`

**`.codex/skills/`:**
- Purpose: Exposes local GSD command skills.
- Contains: One directory per `gsd-*` command, each with `SKILL.md`.
- Key files: `.codex/skills/gsd-map-codebase/SKILL.md`, `.codex/skills/gsd-plan-phase/SKILL.md`, `.codex/skills/gsd-execute-phase/SKILL.md`
- Subdirectories: `gsd-*` skill directories only; no `rules/*.md` files detected.

**`.planning/codebase/`:**
- Purpose: Stores generated codebase map documents for GSD planning and execution.
- Contains: `ARCHITECTURE.md` and `STRUCTURE.md` for this mapping run.
- Key files: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`

**`.github/`:**
- Purpose: Stores repository media used by documentation.
- Contains: Demo image.
- Key files: `.github/demo.png`

**`.claude/`:**
- Purpose: Local Claude workspace settings.
- Contains: Local settings files.
- Key files: `.claude/settings.local.json`
- Note: `.claude` is ignored by `.gitignore` and excluded by `.npmignore`.

**`node_modules/`:**
- Purpose: Local installed dependencies.
- Contains: Installed package files.
- Key files: `node_modules/.package-lock.json`
- Note: `node_modules` is ignored by `.gitignore` and excluded by `.npmignore`.

## Key File Locations

**Entry Points:**
- `package.json`: Defines the npm package and maps `cc-statusline` to `bin/install.js`.
- `bin/install.js`: Main installer/uninstaller entrypoint.
- `.codex/gsd-core/bin/gsd-tools.cjs`: Local GSD CLI utility entrypoint.
- `.codex/gsd-core/bin/gsd_run`: Shell launcher that delegates to `gsd-tools.cjs`.
- `.codex/hooks/gsd-check-update.js`: SessionStart hook command.
- `.codex/hooks/gsd-context-monitor.js`: SubagentStart, Stop, and PostToolUse hook command.

**Configuration:**
- `package.json`: Package metadata and executable mapping.
- `.gitignore`: Git ignore rules for `node_modules`, `.DS_Store`, `docs`, `.worktrees`, and `.claude`.
- `.npmignore`: NPM publish exclusions for `.claude`, `.github`, `.gitignore`, `.worktrees`, `docs`, `node_modules`, and `.DS_Store`.
- `.codex/config.toml`: Codex/GSD agent registry and hook feature flag.
- `.codex/hooks.json`: Codex hook event wiring.
- `.codex/gsd-install-state.json`: Local GSD install state metadata.
- `.codex/gsd-file-manifest.json`: Local GSD file manifest.

**Core Logic:**
- `bin/install.js`: Installer, uninstaller, generated statusline script template, provider selection, and settings mutation.
- `bin/shared-helpers.sh`: Shared shell helper functions.
- `bin/providers/anthropic.sh`: Anthropic provider implementation.
- `bin/providers/zai.sh`: Z.AI provider implementation.
- `.codex/gsd-core/bin/gsd-tools.cjs`: GSD command router.
- `.codex/gsd-core/bin/lib/commands.cjs`: Standalone GSD utility commands.
- `.codex/gsd-core/bin/lib/config-loader.cjs`: GSD project configuration loader.
- `.codex/gsd-core/bin/lib/runtime-slash.cjs`: Runtime-specific GSD command formatting.
- `.codex/gsd-core/bin/lib/command-routing-hub.cjs`: Pure-result GSD command dispatch hub.

**Testing:**
- Not detected: no `tests/`, `*.test.*`, `*.spec.*`, `jest.config.*`, or `vitest.config.*` files are present in the tracked package tree.
- If tests are introduced, place package tests under `tests/` and add explicit scripts/config to `package.json`.

**Documentation:**
- `README.md`: User-facing installation, requirements, provider, uninstall, and installed-file documentation.
- `LICENSE`: MIT license.
- `.planning/codebase/ARCHITECTURE.md`: Architecture map.
- `.planning/codebase/STRUCTURE.md`: Structure map.

**Assets:**
- `.github/demo.png`: README demo image.

## Naming Conventions

**Files:**
- `install.js`: Single JavaScript CLI entrypoint in `bin/`.
- `*.sh`: Shell runtime sources and provider modules, for example `bin/shared-helpers.sh` and `bin/providers/anthropic.sh`.
- Provider files use lowercase provider keys that match `--provider` values, for example `zai` maps to `bin/providers/zai.sh`.
- `*.cjs`: GSD CommonJS utility modules under `.codex/gsd-core/bin/` and `.codex/scripts/`.
- `SKILL.md`: GSD skill instruction file inside each `.codex/skills/gsd-*` directory.
- Paired GSD agent files use the same base name with `.md` and `.toml`, for example `.codex/agents/gsd-codebase-mapper.md` and `.codex/agents/gsd-codebase-mapper.toml`.
- Top-level documentation uses uppercase names, for example `README.md`, `LICENSE`, and `.planning/codebase/ARCHITECTURE.md`.

**Directories:**
- `bin/` is the package executable/source directory.
- `bin/providers/` is a plural collection directory for provider modules.
- `.codex/skills/gsd-*` uses one command per directory.
- `.codex/gsd-core/workflows/` uses kebab-case workflow filenames.
- `.codex/gsd-core/templates/` groups reusable artifact templates.
- `.planning/codebase/` uses uppercase document filenames for generated maps.

**Special Patterns:**
- New provider files must be shell scripts in `bin/providers/<provider>.sh`.
- New provider files must implement `get_provider_token`, `fetch_usage_data`, and `format_usage_lines`.
- Generated statusline code belongs in the `generateStatuslineScript(provider)` template inside `bin/install.js`.
- GSD command skills belong in `.codex/skills/gsd-<command>/SKILL.md`.
- GSD workflow definitions belong in `.codex/gsd-core/workflows/<command>.md`.
- GSD agent definitions belong in `.codex/agents/<agent>.md` plus `.codex/agents/<agent>.toml`, and must be registered in `.codex/config.toml`.

## Where to Add New Code

**New Statusline Feature:**
- Primary code: `bin/install.js`
- Shared shell helper: `bin/shared-helpers.sh`
- Provider-specific behavior: `bin/providers/anthropic.sh` or `bin/providers/zai.sh`
- Documentation: `README.md`
- Tests: create `tests/` and add a test script to `package.json` because no test harness exists.

**New CLI Flag:**
- Argument parsing: `parseArgs()` in `bin/install.js`
- Runtime handling: `run()` in `bin/install.js`
- User docs: `README.md`

**New Provider:**
- Implementation: `bin/providers/<provider>.sh`
- Provider validation and display names: `getProvider()` and `run()` in `bin/install.js`
- Generated runtime compatibility: ensure the provider implements `get_provider_token`, `fetch_usage_data`, and `format_usage_lines`
- Documentation: `README.md`

**New Shared Formatting Utility:**
- Implementation: `bin/shared-helpers.sh`
- Generated script usage: `generateStatuslineScript(provider)` in `bin/install.js`
- Provider usage: relevant file in `bin/providers/`

**Generated Runtime Change:**
- Implementation: `generateStatuslineScript(provider)` in `bin/install.js`
- Do not edit installed `<targetDir>/statusline.sh` as source.

**New GSD Skill:**
- Skill instructions: `.codex/skills/gsd-<command>/SKILL.md`
- Workflow: `.codex/gsd-core/workflows/<command>.md`
- Agent config if needed: `.codex/agents/<agent>.toml`
- Agent prompt if needed: `.codex/agents/<agent>.md`
- Agent registration: `.codex/config.toml`

**New GSD CJS Utility:**
- Implementation: `.codex/gsd-core/bin/lib/<name>.cjs`
- Dispatcher wiring: `.codex/gsd-core/bin/gsd-tools.cjs` or a command-family router in `.codex/gsd-core/bin/lib/`
- Shell launcher remains `.codex/gsd-core/bin/gsd_run`

**Utilities:**
- Package runtime helpers: `bin/shared-helpers.sh`
- Installer-only helpers: keep in `bin/install.js` unless duplication justifies extraction.
- GSD tooling helpers: `.codex/gsd-core/bin/lib/` or `.codex/scripts/lib/`

## Special Directories

**`.codex/`:**
- Purpose: Local GSD/Codex runtime and workflow tooling.
- Generated: Yes, managed by GSD installation/update workflows.
- Committed: No in the current git index; `git status --short` reports `.codex/` as untracked.

**`.planning/codebase/`:**
- Purpose: Generated codebase maps consumed by GSD planning and execution workflows.
- Generated: Yes.
- Committed: No existing tracked files detected before this mapping run.

**`node_modules/`:**
- Purpose: Local dependency install directory.
- Generated: Yes.
- Committed: No; ignored by `.gitignore`.

**`.claude/`:**
- Purpose: Local Claude runtime settings for this workspace.
- Generated: User/runtime local.
- Committed: No; ignored by `.gitignore` and excluded by `.npmignore`.

**`.github/`:**
- Purpose: Repository media for documentation.
- Generated: No.
- Committed: Yes; `.github/demo.png` is tracked.
- NPM package: Excluded by `.npmignore`.

**`bin/providers/`:**
- Purpose: Provider plugin directory for statusline usage APIs.
- Generated: No.
- Committed: Yes.

---

*Structure analysis: 2026-06-20*
