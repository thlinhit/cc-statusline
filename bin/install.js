#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");
const readline = require("readline");

// ANSI colors
const blue = "\x1b[38;2;0;153;255m";
const green = "\x1b[38;2;0;175;80m";
const red = "\x1b[38;2;255;85;85m";
const yellow = "\x1b[38;2;230;200;0m";
const dim = "\x1b[2m";
const reset = "\x1b[0m";

function log(msg) {
  console.log(`  ${msg}`);
}

function success(msg) {
  console.log(`  ${green}✓${reset} ${msg}`);
}

function warn(msg) {
  console.log(`  ${yellow}!${reset} ${msg}`);
}

function fail(msg) {
  console.error(`  ${red}✗${reset} ${msg}`);
}

// Parse command line arguments
function parseArgs() {
  const args = {};
  for (let i = 2; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg === "--uninstall") {
      args.uninstall = true;
    } else if (arg.startsWith("--dir=")) {
      args.dir = arg.split("=")[1];
    } else if (arg === "--dir" && i + 1 < process.argv.length) {
      args.dir = process.argv[++i];
    } else if (arg.startsWith("--provider=")) {
      args.provider = arg.split("=")[1];
    } else if (arg === "--provider" && i + 1 < process.argv.length) {
      args.provider = process.argv[++i];
    }
  }
  return args;
}

// Check required dependencies
function checkDeps() {
  const { execSync } = require("child_process");
  const missing = [];

  try {
    execSync("which jq", { stdio: "ignore" });
  } catch {
    missing.push("jq");
  }

  try {
    execSync("which curl", { stdio: "ignore" });
  } catch {
    missing.push("curl");
  }

  // Git is optional
  let hasGit = false;
  try {
    execSync("which git", { stdio: "ignore" });
    hasGit = true;
  } catch {
    // Git is optional
  }

  return { missing, hasGit };
}

// Prompt for provider selection
function promptProvider() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(
      `\n  ${blue}Which API provider are you using?${reset}\n    ${dim}1) Anthropic${reset}\n    ${dim}2) Z.AI${reset}\n  ${blue}>${reset} `,
      (answer) => {
        rl.close();
        const choice = answer.trim();
        if (choice === "1" || choice.toLowerCase().startsWith("a")) {
          resolve("anthropic");
        } else if (choice === "2" || choice.toLowerCase().startsWith("z")) {
          resolve("zai");
        } else {
          warn("Invalid choice, defaulting to Anthropic");
          resolve("anthropic");
        }
      }
    );
  });
}

// Get provider name (from flag or prompt)
async function getProvider(args) {
  if (args.provider) {
    const provider = args.provider.toLowerCase();
    if (provider === "anthropic" || provider === "zai") {
      return provider;
    }
    warn(`Unknown provider "${args.provider}", defaulting to Anthropic`);
    return "anthropic";
  }
  return await promptProvider();
}

// Uninstall function
function uninstall(targetDir) {
  const STATUSLINE_DEST = path.join(targetDir, "statusline.sh");
  const HELPERS_DEST = path.join(targetDir, "statusline-helpers.sh");
  const PROVIDER_DEST = path.join(targetDir, "statusline-provider.sh");
  const CACHE_DEST = path.join(targetDir, "statusline-cache.json");
  const SETTINGS_FILE = path.join(targetDir, "settings.json");
  const BACKUP_DEST = STATUSLINE_DEST + ".bak";

  console.log();
  console.log(`  ${blue}Claude Line Uninstaller${reset}`);
  console.log(`  ${dim}───────────────────────${reset}`);
  console.log();

  if (fs.existsSync(BACKUP_DEST)) {
    // Restore from backup
    fs.copyFileSync(BACKUP_DEST, STATUSLINE_DEST);
    fs.unlinkSync(BACKUP_DEST);
    success(`Restored backup from ${dim}statusline.sh.bak${reset}`);

    // Only remove cache file (runtime-generated, always safe)
    if (fs.existsSync(CACHE_DEST)) {
      fs.unlinkSync(CACHE_DEST);
      success(`Removed ${dim}statusline-cache.json${reset}`);
    }

    log(
      `${dim}Note: Helper files (statusline-helpers.sh, statusline-provider.sh)${reset}`
    );
    log(
      `${dim}      were preserved as they may belong to the restored backup.${reset}`
    );
    log(
      `${dim}      Remove manually if not needed.${reset}`
    );
  } else if (fs.existsSync(STATUSLINE_DEST)) {
    // No backup: remove all installed files
    fs.unlinkSync(STATUSLINE_DEST);
    success(`Removed ${dim}statusline.sh${reset}`);

    if (fs.existsSync(HELPERS_DEST)) {
      fs.unlinkSync(HELPERS_DEST);
      success(`Removed ${dim}statusline-helpers.sh${reset}`);
    }

    if (fs.existsSync(PROVIDER_DEST)) {
      fs.unlinkSync(PROVIDER_DEST);
      success(`Removed ${dim}statusline-provider.sh${reset}`);
    }

    if (fs.existsSync(CACHE_DEST)) {
      fs.unlinkSync(CACHE_DEST);
      success(`Removed ${dim}statusline-cache.json${reset}`);
    }
  } else {
    warn("No statusline found — nothing to remove");
  }

  // Remove statusLine from settings.json
  if (fs.existsSync(SETTINGS_FILE)) {
    try {
      const settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf-8"));
      const expectedCommand = `bash "${targetDir}/statusline.sh"`;

      if (
        settings.statusLine &&
        settings.statusLine.type === "command" &&
        settings.statusLine.command === expectedCommand
      ) {
        delete settings.statusLine;
        fs.writeFileSync(
          SETTINGS_FILE,
          JSON.stringify(settings, null, 2) + "\n"
        );
        success(`Removed statusLine from ${dim}settings.json${reset}`);
      }
    } catch (err) {
      fail(`Could not parse ${SETTINGS_FILE} — ${err.message}`);
    }
  }

  console.log();
  log(`${green}Done!${reset} Restart Claude Code to apply changes.`);
  console.log();
}

// Generate statusline.sh content
function generateStatuslineScript(provider) {
  const providerName = provider === "anthropic" ? "Anthropic" : "Z.AI";

  return `#!/bin/bash
set -f

# Generated by cc-statusline installer
# Provider: ${providerName}
# DO NOT EDIT THIS FILE DIRECTLY - it will be overwritten on reinstall

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# Self-locate script directory
SCRIPT_DIR="$(cd "$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

# Source shared helpers
. "\${SCRIPT_DIR}/statusline-helpers.sh"

# Source provider implementation
. "\${SCRIPT_DIR}/statusline-provider.sh"

# ── Extract JSON data ───────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')

size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
[ "$size" -eq 0 ] 2>/dev/null && size=200000

input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
current=$(( input_tokens + cache_create + cache_read ))

used_tokens=$(format_tokens $current)
total_tokens=$(format_tokens $size)

if [ "$size" -gt 0 ]; then
    pct_used=$(( current * 100 / size ))
else
    pct_used=0
fi

effort="default"
settings_path="\${SCRIPT_DIR}/settings.json"
if [ -f "$settings_path" ]; then
    effort=$(jq -r '.effortLevel // "default"' "$settings_path" 2>/dev/null)
fi

# ── LINE 1: Model │ Context % │ Directory (branch) │ Session │ Effort ──
sep=" \${dim}│\${reset} "
pct_color=$(color_for_pct "$pct_used")
cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)
dirname=$(basename "$cwd")

git_branch=""
git_dirty=""
if command -v git >/dev/null 2>&1 && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
        git_dirty="*"
    fi
fi

session_duration=""
session_start=$(echo "$input" | jq -r '.session.start_time // empty')
if [ -n "$session_start" ] && [ "$session_start" != "null" ]; then
    start_epoch=$(iso_to_epoch "$session_start")
    if [ -n "$start_epoch" ]; then
        now_epoch=$(date +%s)
        elapsed=$(( now_epoch - start_epoch ))
        if [ "$elapsed" -ge 3600 ]; then
            session_duration="$(( elapsed / 3600 ))h$(( (elapsed % 3600) / 60 ))m"
        elif [ "$elapsed" -ge 60 ]; then
            session_duration="$(( elapsed / 60 ))m"
        else
            session_duration="\${elapsed}s"
        fi
    fi
fi

line1="\${blue}\${model_name}\${reset}"
line1+="\${sep}"
line1+="🧠 \${pct_color}\${pct_used}%${reset}"
line1+="\${sep}"
line1+="\${cyan}\${dirname}\${reset}"
if [ -n "$git_branch" ]; then
    line1+=" \${green}(\${git_branch}\${red}\${git_dirty}\${green})\${reset}"
fi
if [ -n "$session_duration" ]; then
    line1+="\${sep}"
    line1+="\${dim}⏱ \${reset}\${white}\${session_duration}\${reset}"
fi
line1+="\${sep}"
case "$effort" in
    high)   line1+="\${magenta}● \${effort}\${reset}" ;;
    medium) line1+="\${dim}◑ \${effort}\${reset}" ;;
    low)    line1+="\${dim}◔ \${effort}\${reset}" ;;
    *)      line1+="\${dim}◑ \${effort}\${reset}" ;;
esac

# ── Fetch provider usage data (cached) ──────────────────
cache_file="\${SCRIPT_DIR}/statusline-cache.json"
cache_max_age=60
needs_refresh=true
usage_data=""

if [ -f "$cache_file" ]; then
    cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
    now=$(date +%s)
    cache_age=$(( now - cache_mtime ))
    if [ "$cache_age" -lt "$cache_max_age" ]; then
        # Check if cached provider matches current provider
        cached_provider=$(jq -r '.provider // empty' "$cache_file" 2>/dev/null)
        if [ "$cached_provider" = "${provider}" ]; then
            needs_refresh=false
            usage_data=$(cat "$cache_file" 2>/dev/null | jq -r '.data // empty')
        fi
    fi
fi

if $needs_refresh; then
    token=$(get_provider_token)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        response=$(fetch_usage_data "$token")
        if [ -n "$response" ]; then
            usage_data="$response"
            echo '{"provider": "${provider}", "fetched_at": '$(date +%s)', "data": '$(echo "$response" | jq -c .)'}' > "$cache_file"
        fi
    fi
    if [ -z "$usage_data" ] && [ -f "$cache_file" ]; then
        usage_data=$(cat "$cache_file" 2>/dev/null | jq -r '.data // empty')
    fi
fi

# ── Provider usage lines ─────────────────────────────────
rate_lines=""
if [ -n "$usage_data" ] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
    rate_lines=$(format_usage_lines "$usage_data")
fi

# ── Output ──────────────────────────────────────────────
printf "%b" "$line1"
[ -n "$rate_lines" ] && printf "\\n\\n%b" "$rate_lines"

exit 0
`;
}

// Main install function
async function run() {
  const args = parseArgs();

  // Default directory
  const targetDir = args.dir || path.join(os.homedir(), ".claude");

  // Uninstall mode
  if (args.uninstall) {
    uninstall(targetDir);
    return;
  }

  // Install mode
  console.log();
  console.log(`  ${blue}Claude Line Installer${reset}`);
  console.log(`  ${dim}─────────────────────${reset}`);
  console.log();

  // Check dependencies
  const { missing, hasGit } = checkDeps();
  if (missing.length > 0) {
    fail(`Missing required dependencies: ${missing.join(", ")}`);
    log(`  Install them and try again.`);
    if (missing.includes("jq")) {
      log(`  ${dim}brew install jq${reset}`);
    }
    process.exit(1);
  }
  success("Dependencies found (jq, curl)");

  if (!hasGit) {
    warn("git not found - branch display will be disabled");
  }

  // Get provider
  const provider = await getProvider(args);
  const providerName = provider === "anthropic" ? "Anthropic" : "Z.AI";
  success(`Installing for ${providerName}`);

  // Create target directory if needed
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
    success(`Created ${targetDir}`);
  }

  // File paths
  const STATUSLINE_DEST = path.join(targetDir, "statusline.sh");
  const HELPERS_DEST = path.join(targetDir, "statusline-helpers.sh");
  const PROVIDER_DEST = path.join(targetDir, "statusline-provider.sh");
  const SETTINGS_FILE = path.join(targetDir, "settings.json");
  const BACKUP_DEST = STATUSLINE_DEST + ".bak";

  // Source files
  const HELPERS_SRC = path.resolve(__dirname, "shared-helpers.sh");
  const PROVIDER_SRC = path.resolve(__dirname, "providers", `${provider}.sh`);

  // Check source files exist
  if (!fs.existsSync(HELPERS_SRC)) {
    fail(`Source file not found: ${HELPERS_SRC}`);
    process.exit(1);
  }
  if (!fs.existsSync(PROVIDER_SRC)) {
    fail(`Source file not found: ${PROVIDER_SRC}`);
    process.exit(1);
  }

  // Backup existing statusline.sh
  if (fs.existsSync(STATUSLINE_DEST)) {
    fs.copyFileSync(STATUSLINE_DEST, BACKUP_DEST);
    warn(`Backed up existing statusline to ${dim}statusline.sh.bak${reset}`);
  }

  // Copy shared helpers
  fs.copyFileSync(HELPERS_SRC, HELPERS_DEST);
  fs.chmodSync(HELPERS_DEST, 0o644);
  success(`Installed helpers to ${dim}${HELPERS_DEST}${reset}`);

  // Copy provider script
  fs.copyFileSync(PROVIDER_SRC, PROVIDER_DEST);
  fs.chmodSync(PROVIDER_DEST, 0o644);
  success(
    `Installed ${providerName} provider to ${dim}${PROVIDER_DEST}${reset}`
  );

  // Generate and write statusline.sh
  const statuslineContent = generateStatuslineScript(provider);
  fs.writeFileSync(STATUSLINE_DEST, statuslineContent);
  fs.chmodSync(STATUSLINE_DEST, 0o755);
  success(`Installed statusline to ${dim}${STATUSLINE_DEST}${reset}`);

  // Update settings.json
  let settings = {};
  if (fs.existsSync(SETTINGS_FILE)) {
    try {
      settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf-8"));
    } catch {
      fail(`Could not parse ${SETTINGS_FILE} — fix it manually`);
      process.exit(1);
    }
  }

  const statusLineConfig = {
    type: "command",
    command: `bash "${targetDir}/statusline.sh"`,
  };

  if (
    settings.statusLine &&
    settings.statusLine.type === "command" &&
    settings.statusLine.command === statusLineConfig.command
  ) {
    success("Settings already configured");
  } else {
    settings.statusLine = statusLineConfig;
    fs.writeFileSync(
      SETTINGS_FILE,
      JSON.stringify(settings, null, 2) + "\n"
    );
    success(`Updated ${dim}settings.json${reset} with statusLine config`);
  }

  console.log();
  log(
    `${green}Done!${reset} Restart Claude Code to see your new status line.`
  );
  console.log();
  log(`${dim}Provider: ${providerName}${reset}`);
  console.log();
}

run().catch((err) => {
  fail(err.message);
  process.exit(1);
});
