#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# shellcheck disable=SC1091
. "${repo_root}/bin/shared-helpers.sh"
# shellcheck disable=SC1091
. "${repo_root}/bin/providers/anthropic.sh"

# Keep assertions stable by disabling ANSI colors.
blue=""
orange=""
green=""
cyan=""
red=""
yellow=""
white=""
magenta=""
dim=""
reset=""

assert_contains() {
    local haystack="$1"
    local needle="$2"
    if ! grep -Fq -- "$needle" <<<"$haystack"; then
        printf 'Expected output to contain: %s\nActual output:\n%s\n' "$needle" "$haystack" >&2
        exit 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    if grep -Fq -- "$needle" <<<"$haystack"; then
        printf 'Expected output not to contain: %s\nActual output:\n%s\n' "$needle" "$haystack" >&2
        exit 1
    fi
}

anthropic_usage='{
  "five_hour": {
    "utilization": 12,
    "resets_at": "2026-06-20T12:00:00Z"
  },
  "seven_day": {
    "utilization": 34,
    "resets_at": "2026-06-24T12:00:00Z"
  },
  "extra_usage": {
    "is_enabled": true,
    "utilization": 36.44,
    "used_credits": 4300,
    "monthly_limit": 11800
  }
}'

output=$(format_usage_lines "$anthropic_usage")
assert_contains "$output" "current"
assert_contains "$output" "weekly"
assert_contains "$output" "extra"
assert_contains "$output" '$43.00/$118.00'

output=$(CC_STATUSLINE_USAGE_DISPLAY=spent format_usage_lines "$anthropic_usage")
assert_contains "$output" "spent"
assert_contains "$output" '$43.00/$118.00'
assert_not_contains "$output" "current"
assert_not_contains "$output" "weekly"
assert_not_contains "$output" "extra"

enterprise_usage='{
  "spent_usage": {
    "spent": 42.5,
    "limit": 118,
    "utilization": 36.02
  }
}'

output=$(CC_STATUSLINE_USAGE_DISPLAY=spent format_usage_lines "$enterprise_usage")
assert_contains "$output" "spent"
assert_contains "$output" '$42.50/$118.00'
assert_not_contains "$output" "current"
assert_not_contains "$output" "weekly"

anthropic_enterprise_limit_usage='{
  "spend": {
    "enabled": true,
    "used": {
      "amount_minor": 4300,
      "currency": "USD",
      "exponent": 2
    },
    "limit": {
      "amount_minor": 11800,
      "currency": "USD",
      "exponent": 2
    },
    "percent": 36.44,
    "severity": "ok"
  }
}'

output=$(CC_STATUSLINE_USAGE_DISPLAY=spent format_usage_lines "$anthropic_enterprise_limit_usage")
assert_contains "$output" "spent"
assert_contains "$output" '$43.00/$118.00'
assert_not_contains "$output" "current"
assert_not_contains "$output" "weekly"

anthropic_enterprise_usage='{
  "five_hour": {
    "utilization": 16,
    "resets_at": "2026-06-20T10:00:00Z"
  },
  "seven_day": {
    "utilization": 12,
    "resets_at": "2026-06-21T01:00:00Z"
  },
  "spend": {
    "enabled": true,
    "used": {
      "amount_minor": 4300,
      "currency": "USD",
      "exponent": 2
    },
    "limit": null,
    "percent": 36.44,
    "severity": "ok"
  }
}'

output=$(CC_STATUSLINE_USAGE_DISPLAY=spent format_usage_lines "$anthropic_enterprise_usage")
assert_contains "$output" "spent"
assert_contains "$output" '$43.00/$118.00'
assert_not_contains "$output" "current"
assert_not_contains "$output" "weekly"

anthropic_enterprise_zero_usage='{
  "spend": {
    "used": {
      "amount_minor": 0,
      "currency": "USD",
      "exponent": 2
    },
    "limit": null,
    "percent": 0,
    "severity": "normal",
    "enabled": false
  }
}'

output=$(CC_STATUSLINE_USAGE_DISPLAY=spent format_usage_lines "$anthropic_enterprise_zero_usage")
assert_contains "$output" "spent"
assert_contains "$output" '$0.00'
assert_not_contains "$output" "/"
assert_not_contains "$output" "current"
assert_not_contains "$output" "weekly"

printf '{"access_token":"test-oauth-token","expires_at":4102444800}\n' >"${tmpdir}/.claude-code-api.json"
token=$(SCRIPT_DIR="$tmpdir" get_provider_token)
if [ "$token" != "test-oauth-token" ]; then
    printf 'Expected get_provider_token to read .claude-code-api.json access_token\n' >&2
    exit 1
fi

expired_dir="${tmpdir}/expired"
mkdir -p "$expired_dir"
printf '{"access_token":"old-token","refresh_token":"old-refresh","expires_at":1,"scope":"bedrock/invoke-model"}\n' >"${expired_dir}/.claude-code-api.json"
curl() {
    printf '{"access_token":"new-token","refresh_token":"new-refresh","expires_in":3600,"scope":"bedrock/invoke-model","token_type":"Bearer"}\n'
}
token=$(SCRIPT_DIR="$expired_dir" get_provider_token)
if [ "$token" != "new-token" ]; then
    printf 'Expected expired .claude-code-api.json token to refresh\n' >&2
    exit 1
fi
stored_token=$(jq -r '.access_token' "${expired_dir}/.claude-code-api.json")
if [ "$stored_token" != "new-token" ]; then
    printf 'Expected refreshed token to be persisted to .claude-code-api.json\n' >&2
    exit 1
fi
