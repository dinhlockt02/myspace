#!/usr/bin/env bash
# scripts/lib/pr-client.sh - Dual GitHub communication client (gh CLI + REST API fallback)

PR_CLIENT_MODE=""
EXISTING_PR_NUMBER=""
EXISTING_PR_URL=""
EXISTING_PR_DRAFT=false

check_github_auth() {
    # 1. Try official GitHub CLI first
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        PR_CLIENT_MODE="gh"
        return 0
    fi

    # 2. Fall back to GITHUB_TOKEN environment variable
    if [ -n "$GITHUB_TOKEN" ]; then
        PR_CLIENT_MODE="rest"
        return 0
    fi

    PR_CLIENT_MODE="none"
    return 1
}

check_existing_pr() {
    local branch="$1"
    local base="${2:-main}"
    EXISTING_PR_NUMBER=""
    EXISTING_PR_URL=""
    EXISTING_PR_DRAFT=false

    if ! check_github_auth; then
        return 1
    fi

    local slug
    slug=$(parse_github_repo_slug)
    [ -z "$slug" ] && return 1

    if [ "$PR_CLIENT_MODE" = "gh" ]; then
        local raw
        raw=$(gh pr list --head "$branch" --base "$base" --state open --json number,url,isDraft --jq '.[0]' 2>/dev/null || echo "")
        if [ -n "$raw" ] && [ "$raw" != "null" ]; then
            EXISTING_PR_NUMBER=$(echo "$raw" | grep -o '"number":[0-9]*' | cut -d: -f2)
            EXISTING_PR_URL=$(echo "$raw" | grep -o '"url":"[^"]*' | cut -d'"' -f4)
            if echo "$raw" | grep -q '"isDraft":true'; then
                EXISTING_PR_DRAFT=true
            fi
            return 0
        fi
    elif [ "$PR_CLIENT_MODE" = "rest" ]; then
        local owner
        owner=$(echo "$slug" | cut -d/ -f1)
        local resp
        resp=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                     -H "Accept: application/vnd.github.v3+json" \
                     "https://api.github.com/repos/${slug}/pulls?head=${owner}:${branch}&base=${base}&state=open" 2>/dev/null || echo "[]")
        local num
        num=$(echo "$resp" | grep -o '"number": [0-9]*' | head -n 1 | awk '{print $2}' || echo "")
        if [ -n "$num" ]; then
            EXISTING_PR_NUMBER="$num"
            EXISTING_PR_URL=$(echo "$resp" | grep -o '"html_url": "[^"]*' | head -n 1 | cut -d'"' -f4)
            if echo "$resp" | grep -q '"draft": true'; then
                EXISTING_PR_DRAFT=true
            fi
            return 0
        fi
    fi

    return 1
}

create_github_pr() {
    local branch="$1"
    local base="$2"
    local title="$3"
    local body="$4"
    local is_draft="$5"
    local is_json="$6"

    if ! check_github_auth; then
        if ! $is_json; then
            log_error "GitHub authentication missing. Either login via 'gh auth login' or export 'GITHUB_TOKEN'."
        else
            printf '{"status":"error","error":"GitHub authentication missing. Either login via gh auth login or export GITHUB_TOKEN"}\n'
        fi
        return 2
    fi

    local slug
    slug=$(parse_github_repo_slug)

    if [ "$PR_CLIENT_MODE" = "gh" ]; then
        local draft_flag=""
        if $is_draft; then
            draft_flag="--draft"
        fi

        local pr_url
        pr_url=$(gh pr create --repo "$slug" --base "$base" --head "$branch" --title "$title" --body "$body" $draft_flag 2>&1) || {
            if ! $is_json; then log_error "GitHub CLI PR creation failed: $pr_url"; fi
            return 4
        }
        # Extract URL from output
        local final_url
        final_url=$(echo "$pr_url" | grep -o 'https://github.com/[^ ]*' | tail -n 1 || echo "$pr_url")
        local pr_num
        pr_num=$(echo "$final_url" | awk -F'/' '{print $NF}')

        if $is_json; then
            printf '{"status":"success","action":"created","pr_number":%s,"pr_url":"%s","is_draft":%s,"head_branch":"%s","base_branch":"%s"}\n' \
                   "${pr_num:-0}" "$final_url" "$is_draft" "$branch" "$base"
        else
            printf "\n"
            log_success "Pull Request successfully created! (Draft: %s)" "$is_draft"
            printf "  • URL:    %s\n" "$final_url"
            printf "  • Number: #%s\n" "${pr_num:-0}"
            printf "  • Branch: %s -> %s\n" "$branch" "$base"
            printf "\n"
        fi
        return 0

    elif [ "$PR_CLIENT_MODE" = "rest" ]; then
        # Construct JSON payload for REST API
        local json_payload
        # Use python or node to safely encode JSON body if available, or temporary file
        local body_escaped
        body_escaped=$(printf '%s' "$body" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g')
        local title_escaped
        title_escaped=$(printf '%s' "$title" | sed -e 's/"/\\"/g')

        local resp
        resp=$(curl -s -X POST \
                    -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    "https://api.github.com/repos/${slug}/pulls" \
                    -d "{\"title\":\"${title_escaped}\",\"body\":\"${body_escaped}\",\"head\":\"${branch}\",\"base\":\"${base}\",\"draft\":${is_draft}}" 2>&1)

        local final_url
        final_url=$(echo "$resp" | grep -o '"html_url": "[^"]*' | head -n 1 | cut -d'"' -f4)
        local pr_num
        pr_num=$(echo "$resp" | grep -o '"number": [0-9]*' | head -n 1 | awk '{print $2}')

        if [ -n "$final_url" ]; then
            if $is_json; then
                printf '{"status":"success","action":"created","pr_number":%s,"pr_url":"%s","is_draft":%s,"head_branch":"%s","base_branch":"%s"}\n' \
                       "${pr_num:-0}" "$final_url" "$is_draft" "$branch" "$base"
            else
                printf "\n"
                log_success "Pull Request successfully created via REST API! (Draft: %s)" "$is_draft"
                printf "  • URL:    %s\n" "$final_url"
                printf "  • Number: #%s\n" "${pr_num:-0}"
                printf "\n"
            fi
            return 0
        else
            local err_msg
            err_msg=$(echo "$resp" | grep -o '"message": "[^"]*' | cut -d'"' -f4 || echo "$resp")
            if ! $is_json; then log_error "GitHub REST API error: $err_msg"; fi
            return 4
        fi
    fi
}

update_github_pr() {
    local pr_number="$1"
    local title="$2"
    local body="$3"
    local is_json="$4"

    if ! check_github_auth; then
        if ! $is_json; then log_error "GitHub authentication missing."; fi
        return 2
    fi

    local slug
    slug=$(parse_github_repo_slug)

    if [ "$PR_CLIENT_MODE" = "gh" ]; then
        if [ -n "$title" ]; then
            gh pr edit "$pr_number" --repo "$slug" --title "$title" --body "$body" >/dev/null 2>&1 || {
                if ! $is_json; then log_error "Failed to update PR #$pr_number via GitHub CLI."; fi
                return 4
            }
        else
            gh pr edit "$pr_number" --repo "$slug" --body "$body" >/dev/null 2>&1 || {
                if ! $is_json; then log_error "Failed to update PR #$pr_number body via GitHub CLI."; fi
                return 4
            }
        fi

        if [ "$FLAG_READY" = "true" ]; then
            gh pr ready "$pr_number" --repo "$slug" >/dev/null 2>&1 || true
        fi

        local pr_url="https://github.com/${slug}/pull/${pr_number}"
        if $is_json; then
            local is_draft="false"
            if [ "$FLAG_READY" != "true" ] && [ "$EXISTING_PR_DRAFT" = "true" ]; then
                is_draft="true"
            fi
            printf '{"status":"success","action":"updated","pr_number":%s,"pr_url":"%s","is_draft":%s}\n' "$pr_number" "$pr_url" "$is_draft"
        else
            log_success "Pull Request #$pr_number description updated successfully!"
            if [ "$FLAG_READY" = "true" ]; then
                log_success "Pull Request #$pr_number promoted to Ready for Review!"
            fi
            printf "  • URL: %s\n\n" "$pr_url"
        fi
        return 0

    elif [ "$PR_CLIENT_MODE" = "rest" ]; then
        local body_escaped
        body_escaped=$(printf '%s' "$body" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g')
        local patch_data="{\"body\":\"${body_escaped}\"}"
        if [ -n "$title" ]; then
            local title_escaped
            title_escaped=$(printf '%s' "$title" | sed -e 's/"/\\"/g')
            patch_data="{\"title\":\"${title_escaped}\",\"body\":\"${body_escaped}\"}"
        fi

        local resp
        resp=$(curl -s -X PATCH \
                    -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    "https://api.github.com/repos/${slug}/pulls/${pr_number}" \
                    -d "$patch_data" 2>&1)

        local final_url
        final_url=$(echo "$resp" | grep -o '"html_url": "[^"]*' | head -n 1 | cut -d'"' -f4)
        if [ -n "$final_url" ]; then
            if $is_json; then
                printf '{"status":"success","action":"updated","pr_number":%s,"pr_url":"%s"}\n' "$pr_number" "$final_url"
            else
                log_success "Pull Request #$pr_number updated successfully via REST API!"
                printf "  • URL: %s\n\n" "$final_url"
            fi
            return 0
        else
            if ! $is_json; then log_error "GitHub REST API update error: $resp"; fi
            return 4
        fi
    fi
}

get_github_pr_status() {
    local branch="$1"
    local base="${2:-main}"
    local is_json="$3"

    if ! check_github_auth; then
        if ! $is_json; then log_error "GitHub authentication missing."; fi
        return 2
    fi

    local slug
    slug=$(parse_github_repo_slug)

    if [ "$PR_CLIENT_MODE" = "gh" ]; then
        if $is_json; then
            gh pr view "$branch" --repo "$slug" --json number,title,state,isDraft,mergeable,reviewDecision,url,statusCheckRollup 2>/dev/null || {
                printf '{"status":"error","error":"No active PR found for branch %s"}\n' "$branch"
                return 4
            }
        else
            printf "${COLOR_BOLD}Pull Request Status & CI Health (${branch}):${COLOR_RESET}\n"
            gh pr view "$branch" --repo "$slug" || {
                log_warn "Could not view PR for ${branch}."
                return 4
            }
            printf "\n${COLOR_BOLD}CI Checks:${COLOR_RESET}\n"
            gh pr checks "$branch" --repo "$slug" || true
        fi
        return 0
    elif [ "$PR_CLIENT_MODE" = "rest" ]; then
        if check_existing_pr "$branch" "$base"; then
            if $is_json; then
                printf '{"status":"success","action":"status","pr_number":%s,"pr_url":"%s","is_draft":%s}\n' \
                       "$EXISTING_PR_NUMBER" "$EXISTING_PR_URL" "$EXISTING_PR_DRAFT"
            else
                log_info "Active PR for ${branch}: #${EXISTING_PR_NUMBER} (${EXISTING_PR_URL})"
            fi
            return 0
        else
            if ! $is_json; then log_warn "No active open PR found for branch ${branch}"; fi
            return 4
        fi
    fi
}
