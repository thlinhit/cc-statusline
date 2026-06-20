#!/bin/bash
# Anthropic provider for cc-statusline
# Implements: get_provider_token, fetch_usage_data, format_usage_lines

# ── Derive keychain service name from data directory ──────
# Default ~/.claude uses "Claude Code-credentials"
# Non-default dirs use "Claude Code-credentials-{sha256(path)[:8]}"
_keychain_service_name() {
    local default_dir="${HOME}/.claude"
    if [ "$SCRIPT_DIR" = "$default_dir" ]; then
        echo "Claude Code-credentials"
    else
        local hash
        hash=$(printf '%s' "$SCRIPT_DIR" | shasum -a 256 2>/dev/null | cut -c1-8)
        if [ -z "$hash" ]; then
            hash=$(printf '%s' "$SCRIPT_DIR" | sha256sum 2>/dev/null | cut -c1-8)
        fi
        echo "Claude Code-credentials-${hash}"
    fi
}

_refresh_claude_code_api_token() {
    local api_file="$1"
    local refresh_token scope client_id
    IFS='|' read -r refresh_token scope client_id < <(
        jq -r '[
            (.refresh_token // ""),
            (.scope // ""),
            (.client_id // "9d1c250a-e61b-44d9-88ed-5944d1962f5e")
        ] | join("|")' "$api_file" 2>/dev/null
    )

    [ -z "$refresh_token" ] || [ "$refresh_token" = "null" ] && return 1
    [ -z "$scope" ] || [ "$scope" = "null" ] && scope="user:profile user:inference"

    local request response
    request=$(jq -cn \
        --arg grant_type "refresh_token" \
        --arg refresh_token "$refresh_token" \
        --arg client_id "$client_id" \
        --arg scope "$scope" \
        '{grant_type:$grant_type, refresh_token:$refresh_token, client_id:$client_id, scope:$scope}')

    response=$(curl -s --max-time 30 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$request" \
        "https://platform.claude.com/v1/oauth/token" 2>/dev/null)

    local access_token new_refresh_token expires_in new_scope token_type
    IFS='|' read -r access_token new_refresh_token expires_in new_scope token_type < <(
        echo "$response" | jq -r '[
            (.access_token // ""),
            (.refresh_token // ""),
            (.expires_in // 0 | tostring),
            (.scope // ""),
            (.token_type // "Bearer")
        ] | join("|")' 2>/dev/null
    )

    [ -z "$access_token" ] || [ "$access_token" = "null" ] && return 1
    [ -z "$new_refresh_token" ] || [ "$new_refresh_token" = "null" ] && new_refresh_token="$refresh_token"
    [ -z "$new_scope" ] || [ "$new_scope" = "null" ] && new_scope="$scope"
    [ "$expires_in" -gt 0 ] 2>/dev/null || expires_in=3600

    local now expires_at tmp_file
    now=$(date +%s)
    expires_at=$(( now + expires_in ))
    tmp_file="${api_file}.tmp.$$"

    if jq \
        --arg access_token "$access_token" \
        --arg refresh_token "$new_refresh_token" \
        --arg expires_in "$expires_in" \
        --arg expires_at "$expires_at" \
        --arg scope "$new_scope" \
        --arg token_type "$token_type" \
        '.access_token = $access_token
         | .refresh_token = $refresh_token
         | .expires_in = ($expires_in | tonumber)
         | .expires_at = ($expires_at | tonumber)
         | .scope = $scope
         | .token_type = $token_type' \
        "$api_file" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$api_file" 2>/dev/null || rm -f "$tmp_file"
    else
        rm -f "$tmp_file"
    fi

    echo "$access_token"
}

_get_claude_code_api_token() {
    local api_file="$1"
    local access_token expires_at now
    IFS='|' read -r access_token expires_at < <(
        jq -r '[
            (.access_token // .accessToken // ""),
            (.expires_at // 0 | tostring)
        ] | join("|")' "$api_file" 2>/dev/null
    )

    now=$(date +%s)
    if [ -n "$access_token" ] && [ "$access_token" != "null" ] && [ "$expires_at" -gt $(( now + 60 )) ] 2>/dev/null; then
        echo "$access_token"
        return 0
    fi

    _refresh_claude_code_api_token "$api_file"
}

# ── Get Anthropic OAuth token ─────────────────────────────
get_provider_token() {
    local token=""

    # Check environment variable first
    if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi

    local service_name
    service_name=$(_keychain_service_name)

    # Check macOS keychain
    if command -v security >/dev/null 2>&1; then
        local blob
        blob=$(security find-generic-password -s "$service_name" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi

    # Check credentials file in the script's own directory
    local creds_file="${SCRIPT_DIR}/.credentials.json"
    if [ -f "$creds_file" ]; then
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"
            return 0
        fi
    fi

    # Check Claude Code's OAuth API token file
    local api_file="${SCRIPT_DIR}/.claude-code-api.json"
    if [ -f "$api_file" ]; then
        token=$(_get_claude_code_api_token "$api_file")
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"
            return 0
        fi
    fi

    # Check Linux secret-tool
    if command -v secret-tool >/dev/null 2>&1; then
        local blob
        blob=$(timeout 2 secret-tool lookup service "$service_name" 2>/dev/null)
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

_format_spent_usage_line() {
    local usage_data="$1"
    local bar_width=10

    local spend_pct_raw spend_used spend_limit spend_resets
    IFS='|' read -r spend_pct_raw spend_used spend_limit spend_resets < <(
        echo "$usage_data" | jq -r '
            def num:
                if . == null then null
                elif type == "number" then .
                elif type == "string" then ((gsub("[$,]"; "") | tonumber?) // null)
                else null
                end;
            def first_non_null($values):
                (($values | map(num) | map(select(. != null)) | .[0]) // null);
            def pct($used; $limit; $explicit):
                if $explicit != null then $explicit
                elif ($limit != null and $limit > 0) then (($used * 100) / $limit)
                else 0
                end;
            def pow10($exp):
                reduce range(0; (($exp // 0) | floor)) as $i (1; . * 10);
            def money($value):
                if $value == null then null
                elif ($value | type) == "object" then
                    (($value.amount_minor // $value.amount // null) | num) as $amount
                    | (($value.exponent // 2) | num) as $exponent
                    | if $amount == null then null else ($amount / pow10($exponent)) end
                else
                    ($value | num)
                end;
            def line($used; $limit; $util; $reset; $scale):
                if $used == null then empty
                else
                    ($limit // (if ($util != null and $util > 0) then (($used * 100) / $util) else null end)) as $resolved_limit
                    | ([
                        (if $resolved_limit == null then "" else pct($used; $limit; $util) end),
                        (if $scale == "cents" then ($used / 100) else $used end),
                        (if $resolved_limit == null then "" elif $scale == "cents" then ($resolved_limit / 100) else $resolved_limit end),
                        ($reset // "")
                    ] | join("|"))
                end;
            def cents_obj($obj):
                line(
                    first_non_null([$obj.used_cents, $obj.spent_cents, $obj.current_spend_cents, $obj.used_credits]);
                    first_non_null([$obj.limit_cents, $obj.spend_limit_cents, $obj.monthly_limit_cents, $obj.monthly_limit]);
                    (($obj.utilization // $obj.percentage // $obj.percent) | num);
                    ($obj.resets_at // $obj.reset_at // $obj.next_reset_at // "");
                    "cents"
                );
            def dollar_obj($obj):
                line(
                    first_non_null([$obj.used_dollars, $obj.spent_dollars, $obj.used, $obj.spent, $obj.current_spend, $obj.current_usage, $obj.amount_used]);
                    first_non_null([$obj.limit_dollars, $obj.spend_limit, $obj.limit, $obj.upper_limit, $obj.monthly_limit_dollars, $obj.monthly_spend_limit, $obj.monthly_limit]);
                    (($obj.utilization // $obj.percentage // $obj.percent) | num);
                    ($obj.resets_at // $obj.reset_at // $obj.next_reset_at // "");
                    "dollars"
                );
            def anthropic_spend_obj($obj):
                line(
                    money($obj.used);
                    money($obj.limit);
                    (($obj.percent // $obj.utilization // $obj.percentage) | num);
                    ($obj.resets_at // $obj.reset_at // $obj.next_reset_at // "");
                    "dollars"
                );
            [
                anthropic_spend_obj(.spend // {}),
                (if (.extra_usage.is_enabled // false) then cents_obj(.extra_usage) else empty end),
                cents_obj(.spent_usage // {}),
                dollar_obj(.spent_usage // {}),
                cents_obj(.spend_usage // {}),
                dollar_obj(.spend_usage // {}),
                cents_obj(.spending // {}),
                dollar_obj(.spending // {}),
                cents_obj(.usage_spend // {}),
                dollar_obj(.usage_spend // {}),
                cents_obj(.monthly_usage // {}),
                dollar_obj(.monthly_usage // {})
            ] | map(select(. != null and . != "")) | .[0] // empty
        '
    )

    [ -z "$spend_used" ] && return

    local spend_pct spend_bar spend_pct_color spend_used_fmt spend_limit_fmt spend_col
    spend_used_fmt=$(awk "BEGIN {printf \"%.2f\", $spend_used}")

    if [ -n "$spend_limit" ]; then
        spend_pct=$(awk "BEGIN {printf \"%.0f\", $spend_pct_raw}")
        spend_bar=$(build_bar "$spend_pct" "$bar_width")
        spend_pct_color=$(color_for_pct "$spend_pct")
        spend_limit_fmt=$(awk "BEGIN {printf \"%.2f\", $spend_limit}")
        spend_col="${white}spent${reset}   ${spend_bar} ${spend_pct_color}\$${spend_used_fmt}${dim}/${reset}${white}\$${spend_limit_fmt}${reset}"
    else
        spend_col="${white}spent${reset}   ${white}\$${spend_used_fmt}${reset}"
    fi
    if [ -n "$spend_resets" ] && [ "$spend_resets" != "null" ]; then
        local spend_reset
        spend_reset=$(format_reset_time "$spend_resets" "datetime")
        [ -n "$spend_reset" ] && spend_col+=" ${dim}⟳${reset} ${white}${spend_reset}${reset}"
    fi

    printf "%b" "$spend_col"
}

# ── Format Anthropic usage lines ──────────────────────────
format_usage_lines() {
    local usage_data="$1"
    [ -z "$usage_data" ] && return

    local usage_display="${CC_STATUSLINE_USAGE_DISPLAY:-limits}"
    if [ "$usage_display" = "spent" ]; then
        _format_spent_usage_line "$usage_data"
        return
    fi

    local bar_width=10
    local rate_lines=""

    # Batch jq call 1: extract all base usage fields
    local five_hour_util five_hour_resets seven_day_util seven_day_resets extra_enabled
    IFS='|' read -r five_hour_util five_hour_resets seven_day_util seven_day_resets extra_enabled < <(
        echo "$usage_data" | jq -r '[
            .five_hour.utilization // 0,
            (.five_hour.resets_at // ""),
            .seven_day.utilization // 0,
            (.seven_day.resets_at // ""),
            (.extra_usage.is_enabled // false | tostring)
        ] | join("|")'
    )
    local five_hour_pct five_hour_reset five_hour_bar five_hour_pct_color five_hour_pct_fmt
    five_hour_pct=$(awk "BEGIN {printf \"%.0f\", $five_hour_util}")
    five_hour_reset=$(format_reset_time "$five_hour_resets" "time")
    five_hour_bar=$(build_bar "$five_hour_pct" "$bar_width")
    five_hour_pct_color=$(color_for_pct "$five_hour_pct")
    five_hour_pct_fmt=$(printf "%3d" "$five_hour_pct")

    rate_lines+="${white}current${reset} ${five_hour_bar} ${five_hour_pct_color}${five_hour_pct_fmt}%${reset} ${dim}⟳${reset} ${white}${five_hour_reset}${reset}"

    local seven_day_pct seven_day_reset seven_day_bar seven_day_pct_color seven_day_pct_fmt
    seven_day_pct=$(awk "BEGIN {printf \"%.0f\", $seven_day_util}")
    seven_day_reset=$(format_reset_time "$seven_day_resets" "datetime")
    seven_day_bar=$(build_bar "$seven_day_pct" "$bar_width")
    seven_day_pct_color=$(color_for_pct "$seven_day_pct")
    seven_day_pct_fmt=$(printf "%3d" "$seven_day_pct")

    rate_lines+="\n${white}weekly${reset}  ${seven_day_bar} ${seven_day_pct_color}${seven_day_pct_fmt}%${reset} ${dim}⟳${reset} ${white}${seven_day_reset}${reset}"

    # Extra usage (monthly credits) - if enabled
    local extra_pct extra_used extra_limit extra_bar extra_pct_color extra_reset extra_col
    if [ "$extra_enabled" = "true" ]; then
        local extra_util extra_used_raw extra_limit_raw
        IFS='|' read -r extra_util extra_used_raw extra_limit_raw < <(
            echo "$usage_data" | jq -r '[
                .extra_usage.utilization // 0,
                .extra_usage.used_credits // 0,
                .extra_usage.monthly_limit // 0
            ] | join("|")'
        )
        extra_pct=$(awk "BEGIN {printf \"%.0f\", $extra_util}")
        extra_used=$(awk "BEGIN {printf \"%.2f\", $extra_used_raw/100}")
        extra_limit=$(awk "BEGIN {printf \"%.2f\", $extra_limit_raw/100}")
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
