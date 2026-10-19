#!/usr/bin/env bash
# scripts/tests/commit-workflow.test.sh - Test runner for scripts/commit-workflow.sh
#
# Builds throwaway git repositories in mktemp -d and asserts on CLI output and exit codes.
# Test cases live in scripts/tests/cases/*.sh (one file per user story).
# Usage: bash scripts/tests/commit-workflow.test.sh [case-file-substring]
set -uo pipefail

TESTS_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CW="$(CDPATH="" cd "${TESTS_DIR}/.." && pwd)/commit-workflow.sh"

PASS=0
FAIL=0
CURRENT=""
TMP_ROOTS=()

cleanup() {
    local d
    for d in "${TMP_ROOTS[@]+"${TMP_ROOTS[@]}"}"; do
        [ -n "$d" ] && rm -rf "$d"
    done
}
trap cleanup EXIT

# Run the CLI inside the current directory
cw() { bash "$CW" "$@"; }

# Create a repo with a realistic file layout, an initial commit on main, then switch to feat/test.
# The new repo path is stored in REPO and the shell is moved into it.
mk_repo() {
    REPO=$(mktemp -d)
    TMP_ROOTS+=("$REPO")
    cd "$REPO" || exit 1
    git init -q -b main
    git config user.name "Test User"
    git config user.email "test@example.com"
    git config commit.gpgsign false
    mkdir -p apps/idea-collector/backend/handlers apps/idea-collector/infra apps/commifra \
             .github/workflows specs/003-x/checklists docs
    printf 'package main\n' > apps/idea-collector/backend/main.go
    printf 'package handlers\n' > apps/idea-collector/backend/handlers/auth.go
    printf 'variable "a" {}\n' > apps/idea-collector/infra/main.tf
    printf '# commifra\n' > apps/commifra/README.md
    printf 'name: push\n' > .github/workflows/on_push.yml
    printf '# spec\n' > specs/003-x/spec.md
    printf '# reqs\n' > specs/003-x/checklists/requirements.md
    printf '# plan\n' > specs/003-x/plan.md
    printf '# doc\n' > docs/a.md
    printf '# readme\n' > README.md
    printf 'lock: 1\n' > pnpm-lock.yaml
    printf '{"name":"x"}\n' > package.json
    git add -A
    git commit -q -m "chore: initial"
    git switch -q -c feat/test
}

begin() { CURRENT="$1"; }

ok() { PASS=$((PASS + 1)); }

fail() {
    FAIL=$((FAIL + 1))
    printf 'FAIL [%s] %s\n' "$CURRENT" "$1" >&2
    [ -n "${2:-}" ] && printf '       %s\n' "$2" >&2
}

assert_eq() { # expected actual label
    if [ "$1" = "$2" ]; then ok; else fail "$3" "expected [$1] got [$2]"; fi
}

assert_contains() { # haystack needle label
    if [[ "$1" == *"$2"* ]]; then ok; else fail "$3" "missing [$2] in [${1:0:300}]"; fi
}

assert_not_contains() { # haystack needle label
    if [[ "$1" != *"$2"* ]]; then ok; else fail "$3" "unexpected [$2] in [${1:0:300}]"; fi
}

# Run a command, capture stdout, stderr and the exit code into OUT, ERR, CODE
run() {
    local errf
    errf=$(mktemp)
    OUT=$("$@" 2>"$errf" </dev/null)
    CODE=$?
    ERR=$(cat "$errf")
    rm -f "$errf"
}

assert_code() { # expected label
    assert_eq "$1" "$CODE" "$2 (exit code)"
}

summary() {
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    [ "$FAIL" -eq 0 ]
}

main() {
    local filter="${1:-}" f
    for f in "${TESTS_DIR}"/cases/*.sh; do
        [ -f "$f" ] || continue
        [ -n "$filter" ] && [[ "$f" != *"$filter"* ]] && continue
        printf '== %s\n' "$(basename "$f")"
        # shellcheck disable=SC1090
        source "$f"
    done
    summary
}

main "$@"
