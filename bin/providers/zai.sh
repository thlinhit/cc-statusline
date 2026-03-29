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

    # Batch jq call: extract TOKENS_LIMIT and TIME_LIMIT in one pass
    local tokens_pct tokens_reset_ms time_used time_limit
    IFS='|' read -r tokens_pct tokens_reset_ms time_used time_limit < <(
        echo "$usage_data" | jq -r '
            reduce .data.limits[] as $l (
                {p: 0, r: null, u: null, lim: null};
                if ($l.type == "TOKENS_LIMIT" and .r == null) then
                    .p = ($l.percentage // 0) | .r = ($l.nextResetTime // "")
                elif ($l.type == "TIME_LIMIT" and .u == null) then
                    .u = ($l.currentValue // 0) | .lim = ($l.usage // 1)
                else . end
            ) | [.p, (.r // ""), (.u // 0), (.lim // 1)] | join("|")
        '
    )

    # Convert milliseconds to formatted time using shared helper
    local tokens_reset=""
    [ -n "$tokens_reset_ms" ] && tokens_reset=$(_format_epoch_time "$(( tokens_reset_ms / 1000 ))" "time")

    local tokens_bar tokens_pct_color tokens_pct_fmt
    tokens_bar=$(build_bar "$tokens_pct" "$bar_width")
    tokens_pct_color=$(color_for_pct "$tokens_pct")
    tokens_pct_fmt=$(printf "%3d" "$tokens_pct")

    rate_lines="${white}current${reset} ${tokens_bar} ${tokens_pct_color}${tokens_pct_fmt}%${reset} ${dim}⟳${reset} ${white}${tokens_reset}${reset}"

    local time_pct time_bar time_pct_color time_pct_fmt time_seconds

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
