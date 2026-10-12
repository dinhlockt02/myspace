#!/usr/bin/env bash
# scripts/lib/pr-git.sh - Git operations and remote branch management for PR workflow

get_current_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

get_git_remote_url() {
    local remote="${1:-origin}"
    git remote get-url "$remote" 2>/dev/null || echo ""
}

# Extracts "owner/repo" from origin URL (HTTPS or SSH)
parse_github_repo_slug() {
    local remote_url
    remote_url=$(get_git_remote_url "origin")
    if [ -z "$remote_url" ]; then
        echo ""
        return 1
    fi

    # Handle SSH: git@github.com:owner/repo.git
    # Handle HTTPS: https://github.com/owner/repo.git
    local slug
    slug=$(echo "$remote_url" | sed -E 's/^(https?:\/\/|git@)github\.com[:\/]//; s/\.git$//')
    echo "$slug"
}

check_git_clean() {
    local status
    status=$(git status --porcelain 2>/dev/null || echo "")
    if [ -z "$status" ]; then
        return 0
    else
        return 1
    fi
}

get_git_uncommitted_files() {
    git status --porcelain 2>/dev/null | awk '{print $2}' || true
}

push_current_branch() {
    local branch="$1"
    local is_json="${2:-false}"

    if [ -z "$branch" ] || [ "$branch" = "unknown" ]; then
        if ! $is_json; then log_error "Invalid git branch name: $branch"; fi
        return 1
    fi

    if ! $is_json; then
        log_info "Pushing branch '${branch}' to origin with upstream tracking..."
    fi

    if ! git push -u origin "$branch" >/dev/null 2>&1; then
        if ! $is_json; then
            log_error "Failed to push branch '${branch}' to origin. Check git credentials and remote connectivity."
        fi
        return 1
    fi

    if ! $is_json; then
        log_success "Branch '${branch}' successfully synchronized with origin."
    fi
    return 0
}

get_branch_commits() {
    local base="${1:-main}"
    # Find merge base
    local mb
    mb=$(git merge-base "$base" HEAD 2>/dev/null || echo "$base")
    git log --oneline "${mb}..HEAD" 2>/dev/null || git log -n 5 --oneline
}

get_branch_changed_files() {
    local base="${1:-main}"
    local mb
    mb=$(git merge-base "$base" HEAD 2>/dev/null || echo "$base")
    git diff --name-only "${mb}...HEAD" 2>/dev/null || git diff --name-only HEAD~1
}
