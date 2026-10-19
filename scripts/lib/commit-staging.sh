#!/usr/bin/env bash
# scripts/lib/commit-staging.sh - Staging area, branch and git-state inspection

# Beyond this many staged files a per-file review is no longer realistic (research D11)
LARGE_CHANGESET_FILES=200

PROTECTED_BRANCHES=(main master)

# Populated by load_staged
STAGED_STATUS=()
STAGED_PATHS=()
STAGED_COUNT=0
UNSTAGED_COUNT=0

# Load the staged set: status (A/M/D/R) and repository-relative path per file
load_staged() {
    STAGED_STATUS=()
    STAGED_PATHS=()
    local status path old
    while IFS= read -r -d '' status; do
        case "$status" in
            R*|C*)
                IFS= read -r -d '' old
                IFS= read -r -d '' path
                STAGED_STATUS+=("R")
                ;;
            *)
                IFS= read -r -d '' path
                STAGED_STATUS+=("${status:0:1}")
                ;;
        esac
        STAGED_PATHS+=("$path")
    done < <(git diff --cached --name-status -z)
    STAGED_COUNT=${#STAGED_PATHS[@]}
    UNSTAGED_COUNT=$(git diff --name-only -z | tr -cd '\0' | wc -c | tr -d ' ')
}

current_branch() {
    git branch --show-current 2>/dev/null || true
}

is_protected_branch() {
    local b="$1" p
    for p in "${PROTECTED_BRANCHES[@]}"; do
        [ "$b" = "$p" ] && return 0
    done
    return 1
}

# Echo normal | merge | rebase | cherry-pick
git_state() {
    local p
    p=$(git rev-parse --git-path MERGE_HEAD 2>/dev/null) && [ -e "$p" ] && { echo merge; return 0; }
    p=$(git rev-parse --git-path rebase-merge 2>/dev/null) && [ -e "$p" ] && { echo rebase; return 0; }
    p=$(git rev-parse --git-path rebase-apply 2>/dev/null) && [ -e "$p" ] && { echo rebase; return 0; }
    p=$(git rev-parse --git-path CHERRY_PICK_HEAD 2>/dev/null) && [ -e "$p" ] && { echo cherry-pick; return 0; }
    echo normal
}

# Contents of the merge message git prepared, if any
merge_message() {
    local p
    p=$(git rev-parse --git-path MERGE_MSG 2>/dev/null) || return 0
    [ -f "$p" ] && cat "$p"
    return 0
}

# Constitution Principle VI: never commit on a protected branch.
# Echoes guidance to stderr and returns EX_PROTECTED when the branch is protected.
require_unprotected_branch() {
    local b
    b=$(current_branch)
    if [ -n "$b" ] && is_protected_branch "$b"; then
        say_err "branch '${b}' is protected: do not commit on it (constitution Principle VI)."
        say "Ask for a branch name that follows the naming rules, then run: git switch -c <name>"
        return "$EX_PROTECTED"
    fi
    return 0
}
