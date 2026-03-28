#!/bin/bash
# Anthropic provider for cc-statusline
# Implements: get_provider_token, fetch_usage_data, format_usage_lines

# ── Get Anthropic OAuth token ─────────────────────────────
get_provider_token() {
    local token=""

    # Check environment variable first
    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi

    # Check macOS keychain
    if command -v security >/dev/null 2>&1; then
        local blob
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi

    # Check credentials file
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"
            return 0
        fi
    fi

    # Check Linux secret-tool
    if command -v secret-tool >/dev/null 2>&1; then
        local blob
        blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi

    echo ""
}

# ── Fetch Anthropic usage data ────────────────────────────
fetch_usage_data() {
    local token="$1"
    [ -z "$token" ] && return 1

    local response
    response=$(curl -s --max-time 5 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-code/2.1.34" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
        echo "$response"
        return 0
    fi

    return 1
}

# ── Format Anthropic usage lines ──────────────────────────
format_usage_lines() {
    local usage_data="$1"
    [ -z "$usage_data" ] && return

    local bar_width=10
    local rate_lines=""

    # Five hour (current) usage
    local five_hour_pct five_hour_reset_iso five_hour_reset five_hour_bar five_hour_pct_color five_hour_pct_fmt
    five_hour_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    five_hour_reset_iso=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
    five_hour_reset=$(format_reset_time "$five_hour_reset_iso" "time")
    five_hour_bar=$(build_bar "$five_hour_pct" "$bar_width")
    five_hour_pct_color=$(color_for_pct "$five_hour_pct")
    five_hour_pct_fmt=$(printf "%3d" "$five_hour_pct")

    rate_lines+="${white}current${reset} ${five_hour_bar} ${five_hour_pct_color}${five_hour_pct_fmt}%${reset} ${dim}⟳${reset} ${white}${five_hour_reset}${reset}"

    # Seven day (weekly) usage
    local seven_day_pct seven_day_reset_iso seven_day_reset seven_day_bar seven_day_pct_color seven_day_pct_fmt
    seven_day_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    seven_day_reset_iso=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')
    seven_day_reset=$(format_reset_time "$seven_day_reset_iso" "datetime")
    seven_day_bar=$(build_bar "$seven_day_pct" "$bar_width")
    seven_day_pct_color=$(color_for_pct "$seven_day_pct")
    seven_day_pct_fmt=$(printf "%3d" "$seven_day_pct")

    rate_lines+="\n${white}weekly${reset}  ${seven_day_bar} ${seven_day_pct_color}${seven_day_pct_fmt}%${reset} ${dim}⟳${reset} ${white}${seven_day_reset}${reset}"

    # Extra usage (monthly credits) - if enabled
    local extra_enabled extra_pct extra_used extra_limit extra_bar extra_pct_color extra_reset extra_col
    extra_enabled=$(echo "$usage_data" | jq -r '.extra_usage.is_enabled // false')
    if [ "$extra_enabled" = "true" ]; then
        extra_pct=$(echo "$usage_data" | jq -r '.extra_usage.utilization // 0' | awk '{printf "%.0f", $1}')
        extra_used=$(echo "$usage_data" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.2f", $1/100}')
        extra_limit=$(echo "$usage_data" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.2f", $1/100}')
        extra_bar=$(build_bar "$extra_pct" "$bar_width")
        extra_pct_color=$(color_for_pct "$extra_pct")

        # Calculate next month reset
        extra_reset=$(date -v+1m -v1d +"%b %-d" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [ -z "$extra_reset" ]; then
            extra_reset=$(date -d "$(date +%Y-%m-01) +1 month" +"%b %-d" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        fi

        extra_col="${white}extra${reset}   ${extra_bar} ${extra_pct_color}\$${extra_used}${dim}/${reset}${white}\$${extra_limit}${reset} ${dim}⟳${reset} ${white}${extra_reset}${reset}"
        rate_lines+="\n${extra_col}"
    fi

    printf "%b" "$rate_lines"
}
