#!/bin/bash
# Z.AI provider for cc-statusline
# Implements: get_provider_token, fetch_usage_data, format_usage_lines

# ── Get Z.AI API token from config.yaml ───────────────────
get_provider_token() {
    local config_file="${HOME}/.chelper/config.yaml"
    [ ! -f "$config_file" ] && echo "" && return 1

    # Extract api_key using basic string parsing (no yaml parser dependency)
    local token
    token=$(grep "^api_key:" "$config_file" | sed 's/^api_key:[[:space:]]*//' | tr -d '[:space:]"'"'')

    if [ -n "$token" ]; then
        echo "$token"
        return 0
    fi

    echo ""
    return 1
}

# ── Fetch Z.AI usage data ──────────────────────────────────
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

# ── Format Z.AI usage lines ────────────────────────────────
format_usage_lines() {
    local usage_data="$1"
    [ -z "$usage_data" ] && return

    local bar_width=10
    local rate_lines=""

    # TOKENS_LIMIT (current)
    local tokens_used tokens_limit tokens_pct tokens_reset_iso tokens_reset tokens_bar tokens_pct_color tokens_pct_fmt tokens_display
    tokens_used=$(echo "$usage_data" | jq -r '.data.TOKENS_LIMIT.used // 0')
    tokens_limit=$(echo "$usage_data" | jq -r '.data.TOKENS_LIMIT.limit // 1')
    tokens_reset_iso=$(echo "$usage_data" | jq -r '.data.TOKENS_LIMIT.reset_time // empty')

    if [ "$tokens_limit" -gt 0 ]; then
        tokens_pct=$(( tokens_used * 100 / tokens_limit ))
    else
        tokens_pct=0
    fi

    tokens_reset=$(format_reset_time "$tokens_reset_iso" "time")
    tokens_bar=$(build_bar "$tokens_pct" "$bar_width")
    tokens_pct_color=$(color_for_pct "$tokens_pct")
    tokens_pct_fmt=$(printf "%3d" "$tokens_pct")
    tokens_display=$(format_tokens "$tokens_used")

    rate_lines+="${white}current${reset} ${tokens_bar} ${tokens_pct_color}${tokens_pct_fmt}%${reset} ${dim}(${reset}${white}${tokens_display}${reset}${dim})${reset} ${dim}⟳${reset} ${white}${tokens_reset}${reset}"

    # TIME_LIMIT (tools/MCP) - no reset time shown
    local time_used time_limit time_pct time_bar time_pct_color time_pct_fmt time_seconds
    time_used=$(echo "$usage_data" | jq -r '.data.TIME_LIMIT.used // 0')
    time_limit=$(echo "$usage_data" | jq -r '.data.TIME_LIMIT.limit // 1')

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

    rate_lines+="\n${white}tools${reset}   ${time_bar} ${time_pct_color}${time_pct_fmt}%${reset} ${dim}(${reset}${white}${time_seconds}${reset}${dim})${reset}"

    printf "%b" "$rate_lines"
}
