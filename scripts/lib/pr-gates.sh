#!/usr/bin/env bash
# scripts/lib/pr-gates.sh - Pre-flight verification gates (git clean, lint, test, secrets audit)

GATE_GIT_CLEAN=false
GATE_LINT=false
GATE_TEST=false
GATE_SECRETS=false

check_git_cleanliness() {
    local is_json="${1:-false}"
    if check_git_clean; then
        GATE_GIT_CLEAN=true
        if ! $is_json; then log_success "Git working tree is clean."; fi
        return 0
    else
        GATE_GIT_CLEAN=false
        local uncommitted
        uncommitted=$(get_git_uncommitted_files)
        if ! $is_json; then
            log_error "Working tree has uncommitted or untracked changes:"
            printf "%s\n" "$uncommitted" | sed 's/^/  • /'
            log_error "Please commit or stash changes before running the PR workflow."
        fi
        return 1
    fi
}

check_secret_leak_audit() {
    local is_json="${1:-false}"
    local base="${2:-main}"
    local mb
    mb=$(git merge-base "$base" HEAD 2>/dev/null || echo "$base")

    local diff_content
    diff_content=$(git diff "${mb}..HEAD" 2>/dev/null || git diff HEAD~1 2>/dev/null || echo "")

    local secret_pattern='(aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{30,}|ghp_[a-zA-Z0-9]{36}|BEGIN[[:space:]]+(RSA|EC|OPENSSH|DSA)[[:space:]]+PRIVATE[[:space:]]+KEY)'

    if echo "$diff_content" | grep -Ei "$secret_pattern" >/dev/null 2>&1; then
        GATE_SECRETS=false
        if ! $is_json; then
            log_error "Potential credential or private key detected in branch diff!"
            log_error "Under Monorepo Constitution Principle IV, secrets must NEVER be committed."
        fi
        return 1
    fi

    GATE_SECRETS=true
    if ! $is_json; then log_success "Secret leak audit passed (zero sensitive patterns detected)."; fi
    return 0
}

run_project_quality_checks() {
    local is_json="${1:-false}"
    local base="${2:-main}"

    if ! $is_json; then log_info "Executing local quality gates across affected packages..."; fi

    # 1. Monorepo linting
    if (cd "$REPO_ROOT" && NX_DAEMON=false pnpm nx run-many -t lint --parallel=2 >/dev/null 2>&1); then
        GATE_LINT=true
        if ! $is_json; then log_success "Lint checks passed."; fi
    else
        GATE_LINT=false
        if ! $is_json; then log_error "Lint checks failed across workspace projects."; fi
        return 1
    fi

    # 2. Monorepo and backend testing
    local test_passed=true
    # Check if backend Go tests exist
    if [ -f "$REPO_ROOT/apps/idea-collector/backend/main.go" ]; then
        if ! (cd "$REPO_ROOT/apps/idea-collector/backend" && go test ./... >/dev/null 2>&1); then
            test_passed=false
        fi
    fi

    if $test_passed; then
        GATE_TEST=true
        if ! $is_json; then log_success "Test suites passed."; fi
        return 0
    else
        GATE_TEST=false
        if ! $is_json; then log_error "Project test suites failed."; fi
        return 1
    fi
}

run_preflight_gates() {
    local is_json="${1:-false}"
    local base="${2:-main}"

    if ! $is_json; then
        printf "\n${COLOR_BOLD}Evaluating Pre-Flight Quality Gates:${COLOR_RESET}\n"
    fi

    local all_passed=true

    check_git_cleanliness "$is_json" || all_passed=false
    check_secret_leak_audit "$is_json" "$base" || all_passed=false
    run_project_quality_checks "$is_json" "$base" || all_passed=false

    if $is_json; then
        if $all_passed; then
            printf '{"status":"success","action":"checked","quality_gates":{"git_clean":%s,"lint":%s,"test":%s,"secrets_clear":%s}}\n' \
                   "$GATE_GIT_CLEAN" "$GATE_LINT" "$GATE_TEST" "$GATE_SECRETS"
        else
            printf '{"status":"error","action":"checked","error":"Pre-flight quality gates failed","quality_gates":{"git_clean":%s,"lint":%s,"test":%s,"secrets_clear":%s}}\n' \
                   "$GATE_GIT_CLEAN" "$GATE_LINT" "$GATE_TEST" "$GATE_SECRETS"
        fi
    else
        if $all_passed; then
            printf "\n"
            log_success "All pre-flight quality gates PASSED. Cleared for Pull Request operations."
            printf "\n"
        else
            printf "\n"
            log_error "One or more pre-flight quality gates FAILED. Halting PR operation."
            printf "\n"
        fi
    fi

    if $all_passed; then
        return 0
    else
        return 1
    fi
}
