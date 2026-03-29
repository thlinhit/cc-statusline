#!/bin/bash
# Z.AI provider for cc-statusline
# Implements: get_provider_token, fetch_usage_data, format_usage_lines

# ── Get Z.AI API token ─────────────────────────────────────────
# Priority: 1) settings.json in script dir  2) ~/.chelper/config.yaml
get_provider_token() {
    # Method 1: Check settings.json in script directory (for Z.AI Claude Code)
    if [ -n "${SCRIPT_DIR}" ]; then
        local settings_file="${SCRIPT_DIR}/settings.json"
        if [ -f "$settings_file" ]; then
            local token
            token=$(jq -r '.env.ANTHROPIC_AUTH_TOKEN // empty' "$settings_file" 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi

    # Method 2: Check ~/.chelper/config.yaml (legacy/fallback)
    local config_file="${HOME}/.chelper/config.yaml"
    if [ -f "$config_file" ]; then
        local token
        token=$(grep "^api_key:" "$config_file" | sed 's/^api_key:[[:space:]]*//' | tr -d '[:space:]"')

        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi
    fi

    echo ""
    return 1
}

# ── Fetch Z.AI usage data ──────────────────────────────────────
fetch_usage_data() {
    local token="$1"
    [ -z "$token" ] && return 1

    local response
    response=$(curl -s --max-time 5 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        "https://api.z.ai/api/monitor/usage/quota/limit" 2>/dev/null)

    if [ -n "$response" ] && echo "$response" | jq -e '.data' >/dev/null 2>&1; then
        echo "$response"
        return 0
    fi

    return 1
}

# ── Format Z.AI usage lines ────────────────────────────────────
# Updated for new API response structure (2025-03)
# API now returns limits as array: .data.limits[]
format_usage_lines() {
    local usage_data="$1"
    [ -z "$usage_data" ] && return

    local bar_width=10
    local rate_lines=""

    # TOKENS_LIMIT (current) - first TOKENS_LIMIT in limits array
    # New structure: .data.limits[] where type == "TOKENS_LIMIT"
    local tokens_pct tokens_reset_iso tokens_reset tokens_bar tokens_pct_color tokens_pct_fmt
    tokens_pct=$(echo "$usage_data" | jq -r '(.data.limits[] | select(.type == "TOKENS_LIMIT") | .percentage // 0)' | head -1)
    tokens_reset_iso=$(echo "$usage_data" | jq -r '(.data.limits[] | select(.type == "TOKENS_LIMIT") | .nextResetTime // empty)' | head -1)

    # Convert milliseconds to seconds for date formatting if needed
    if [ -n "$tokens_reset_iso" ] && [ "$tokens_reset_iso" != "null" ]; then
        # nextResetTime is in milliseconds, convert to seconds for formatting
        tokens_reset_iso=$(( tokens_reset_iso / 1000 ))
        tokens_reset=$(date -j -r "$tokens_reset_iso" +"%l:%M%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
        [ -z "$tokens_reset" ] && tokens_reset=$(date -d "@$tokens_reset_iso" +"%l:%M%P" 2>/dev/null | sed 's/^ //; s/\.//g')
    fi

    tokens_bar=$(build_bar "$tokens_pct" "$bar_width")
    tokens_pct_color=$(color_for_pct "$tokens_pct")
    tokens_pct_fmt=$(printf "%3d" "$tokens_pct")

    rate_lines="${white}current${reset} ${tokens_bar} ${tokens_pct_color}${tokens_pct_fmt}%${reset} ${dim}⟳${reset} ${white}${tokens_reset}${reset}"

    # TIME_LIMIT (tools/MCP) - find TIME_LIMIT in limits array
    # New structure: .data.limits[] where type == "TIME_LIMIT"
    local time_used time_limit time_pct time_bar time_pct_color time_pct_fmt time_seconds
    time_used=$(echo "$usage_data" | jq -r '(.data.limits[] | select(.type == "TIME_LIMIT") | .currentValue // 0)')
    time_limit=$(echo "$usage_data" | jq -r '(.data.limits[] | select(.type == "TIME_LIMIT") | .usage // 1)')

    if [ "$time_limit" -gt 0 ]; then
        time_pct=$(( time_used * 100 / time_limit ))
    else
        time_pct=0
    fi

    time_bar=$(build_bar "$time_pct" "$bar_width")
    time_pct_color=$(color_for_pct "$time_pct")
    time_pct_fmt=$(printf "%3d" "$time_pct")

    # Convert seconds to readable format
    if [ "$time_used" -ge 3600 ]; then
        time_seconds="$(( time_used / 3600 ))h$(( (time_used % 3600) / 60 ))m"
    elif [ "$time_used" -ge 60 ]; then
        time_seconds="$(( time_used / 60 ))m"
    else
        time_seconds="${time_used}s"
    fi

    rate_lines="${rate_lines}
${white}tools${reset}   ${time_bar} ${time_pct_color}${time_pct_fmt}%${reset} ${dim}(${reset}${white}${time_seconds}${reset}${dim})${reset}"

    printf "%b" "$rate_lines"
}
