#!/usr/bin/env bash
# scripts/pr-workflow.sh - Core developer Pull Request & Merge Request workflow CLI
set -eo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH="" cd "${SCRIPT_DIR}/.." && pwd)"

# Auto-discover standard toolchains if not present in current shell PATH
if ! command -v node >/dev/null 2>&1 && [ -s "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1090
    source "$NVM_DIR/nvm.sh"
fi
if ! command -v go >/dev/null 2>&1 && [ -d "/usr/local/go/bin" ]; then
    export PATH="$PATH:/usr/local/go/bin"
fi
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Source helper modules
[ -f "${SCRIPT_DIR}/lib/reporter.sh" ] && source "${SCRIPT_DIR}/lib/reporter.sh"
[ -f "${SCRIPT_DIR}/lib/pr-git.sh" ] && source "${SCRIPT_DIR}/lib/pr-git.sh"
[ -f "${SCRIPT_DIR}/lib/pr-client.sh" ] && source "${SCRIPT_DIR}/lib/pr-client.sh"
[ -f "${SCRIPT_DIR}/lib/pr-formatter.sh" ] && source "${SCRIPT_DIR}/lib/pr-formatter.sh"
[ -f "${SCRIPT_DIR}/lib/pr-gates.sh" ] && source "${SCRIPT_DIR}/lib/pr-gates.sh"

# Default state
CMD=""
FLAG_DRAFT=true
FLAG_READY=false
BASE_BRANCH="main"
CUSTOM_TITLE=""
CUSTOM_NOTES=""
FLAG_JSON=false

show_help() {
    cat << 'EOF'
Usage: ./scripts/pr-workflow.sh [COMMAND] [OPTIONS]
       pnpm run pr [-- COMMAND [OPTIONS]]

Myspace Monorepo Pull Request & Merge Request Lifecycle CLI.

COMMANDS:
  create, new, open, create-mr    Create a new GitHub Pull Request from active branch
  update, sync, refresh, update-mr Refresh description and metadata on existing PR
  status, checks, info            Inspect PR state, CI/CD checks, and merge readiness
  check, verify, pre-flight       Execute local quality and security gates only

OPTIONS:
  --draft            Create Pull Request in Draft mode (default)
  --ready, --publish Create or promote Pull Request as Ready for Review
  --base <branch>    Set target integration branch (default: main)
  --title <text>     Custom PR title (overrides auto-generated title)
  --notes <text>     Append custom reviewer notes/highlights during update
  --json             Output machine-readable JSON payload
  --help, -h         Show this help message

EXIT CODES:
  0  SUCCESS
  1  PREFLIGHT_ERROR (git dirty, lint/test failure, or secret detected)
  2  AUTH_ERROR (GitHub credentials missing)
  3  REMOTE_ERROR (git push or remote network failure)
  4  GITHUB_API_ERROR (GitHub API operation failure)
  5  SPEC_ERROR (active feature specification not found)

EOF
    exit 0
}

# Parse command line
while [[ $# -gt 0 ]]; do
    case "$1" in
        create|new|open|create-mr)
            CMD="create"
            ;;
        update|sync|refresh|update-mr)
            CMD="update"
            ;;
        status|checks|info)
            CMD="status"
            ;;
        check|verify|pre-flight)
            CMD="check"
            ;;
        --draft)
            FLAG_DRAFT=true
            FLAG_READY=false
            ;;
        --ready|--publish)
            FLAG_READY=true
            FLAG_DRAFT=false
            ;;
        --base)
            shift
            BASE_BRANCH="$1"
            ;;
        --title)
            shift
            CUSTOM_TITLE="$1"
            ;;
        --notes)
            shift
            CUSTOM_NOTES="$1"
            ;;
        --json)
            FLAG_JSON=true
            ;;
        --help|-h)
            show_help
            ;;
        --)
            # Bare argument separator
            ;;
        *)
            echo "Unknown option or command: $1" >&2
            echo "Run ./scripts/pr-workflow.sh --help for usage information." >&2
            exit 1
            ;;
    esac
    shift
done

execute_pr_create() {
    local branch="$1"
    local base="$2"
    local is_draft="$3"
    local custom_title="$4"
    local is_json="$5"

    local title
    title=$(generate_pr_title "$branch" "$custom_title")
    local body
    body=$(generate_pr_body "$branch" "$base")

    create_github_pr "$branch" "$base" "$title" "$body" "$is_draft" "$is_json"
}

execute_pr_update() {
    local branch="$1"
    local base="$2"
    local custom_notes="$3"
    local is_json="$4"

    if ! check_existing_pr "$branch" "$base"; then
        if ! $is_json; then log_error "No active open PR found for branch ${branch} to update."; fi
        return 4
    fi

    local title=""
    if [ -n "$CUSTOM_TITLE" ]; then
        title="$CUSTOM_TITLE"
    fi
    local body
    body=$(generate_pr_body "$branch" "$base" "$custom_notes")

    update_github_pr "$EXISTING_PR_NUMBER" "$title" "$body" "$is_json"
}

execute_pr_status() {
    local branch="$1"
    local base="$2"
    local is_json="$3"

    get_github_pr_status "$branch" "$base" "$is_json"
}

# Execute main workflow
run_pr_workflow() {
    local branch
    branch=$(get_current_git_branch)

    if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
        if [ "$CMD" != "check" ]; then
            if $FLAG_JSON; then
                printf '{"status":"error","error":"Cannot create or update PR from base branch (%s). Please checkout a feature branch."}\n' "$branch"
            else
                log_error "Cannot create or update PR from base branch ($branch). Please checkout a feature branch."
            fi
            exit 1
        fi
    fi

    # If purely checking local quality gates, execute and exit
    if [ "$CMD" = "check" ]; then
        run_preflight_gates "$FLAG_JSON"
        return $?
    fi

    # Require GitHub CLI (gh) and authentication before running PR workflows
    if ! check_github_auth; then
        if ! command -v gh >/dev/null 2>&1; then
            if $FLAG_JSON; then
                printf '{"status":"error","error":"GitHub CLI (gh) is not installed. Please install gh (https://cli.github.com/) before running PR workflows."}\n'
            else
                log_error "GitHub CLI ('gh') is not installed."
                printf "  • Please install gh from https://cli.github.com/ before running PR workflows.\n\n"
            fi
        else
            if $FLAG_JSON; then
                printf '{"status":"error","error":"GitHub CLI is not authenticated. Please run \\"gh auth login\\" before running PR workflows."}\n'
            else
                log_error "GitHub CLI ('gh') is not authenticated."
                printf "  • Please run 'gh auth login' to authenticate with your GitHub account before running PR workflows.\n\n"
            fi
        fi
        exit 2
    fi

    # Auto-detect command if none specified
    if [ -z "$CMD" ]; then
        if check_existing_pr "$branch" "$BASE_BRANCH"; then
            CMD="update"
        else
            CMD="create"
        fi
    fi

    case "$CMD" in
        create)
            # 1. Run pre-flight gates
            run_preflight_gates "$FLAG_JSON" || exit 1

            # 2. Push branch to remote with upstream tracking
            push_current_branch "$branch" "$FLAG_JSON" || exit 3

            # 3. Create or fallback to update if PR already exists
            if check_existing_pr "$branch" "$BASE_BRANCH"; then
                if ! $FLAG_JSON; then log_info "PR already exists for ${branch}; updating existing PR..."; fi
                execute_pr_update "$branch" "$BASE_BRANCH" "$CUSTOM_NOTES" "$FLAG_JSON"
            else
                execute_pr_create "$branch" "$BASE_BRANCH" "$FLAG_DRAFT" "$CUSTOM_TITLE" "$FLAG_JSON"
            fi
            ;;
        update)
            # 1. Run pre-flight gates
            run_preflight_gates "$FLAG_JSON" || exit 1

            # 2. Push branch to remote
            push_current_branch "$branch" "$FLAG_JSON" || exit 3

            # 3. Execute update
            execute_pr_update "$branch" "$BASE_BRANCH" "$CUSTOM_NOTES" "$FLAG_JSON"
            ;;
        status)
            execute_pr_status "$branch" "$BASE_BRANCH" "$FLAG_JSON"
            ;;
        *)
            log_error "Unrecognized command: $CMD"
            exit 1
            ;;
    esac
}

run_pr_workflow
