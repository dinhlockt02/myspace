#!/usr/bin/env bash
# scripts/commit-workflow.sh - Standardized Conventional Commits workflow CLI
#
# Usage: ./scripts/commit-workflow.sh <propose|validate|commit> [options] [--json]
# See specs/003-standardize-commits/contracts/cli-schema.yml for the full contract.
set -euo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper modules (commit-output.sh must come first)
source "${SCRIPT_DIR}/lib/commit-output.sh"
[ -f "${SCRIPT_DIR}/lib/reporter.sh" ] && source "${SCRIPT_DIR}/lib/reporter.sh"
for lib in commit-staging commit-classify commit-validate secret-patterns commit-safety \
           commit-cmd-propose commit-cmd-validate commit-cmd-commit; do
    [ -f "${SCRIPT_DIR}/lib/${lib}.sh" ] && source "${SCRIPT_DIR}/lib/${lib}.sh"
done

JSON_MODE=false

usage() {
    cat >&2 <<'USAGE'
Usage: commit-workflow.sh <command> [options] [--json]

Commands:
  propose    Read-only. Analyse the staged changes and print a proposal.
  validate   Validate a commit message ("<message>", --file <path>, or - for stdin).
  commit     Validate, run safety checks, and commit the staged changes.

Global options:
  --json     Emit one machine-readable JSON object on stdout.
  -h, --help Show this help.

See specs/003-standardize-commits/contracts/cli-schema.yml for all options and exit codes.
USAGE
}

main() {
    local cmd="${1:-}"
    if [ -z "$cmd" ]; then
        usage
        return "$EX_USAGE"
    fi
    shift

    case "$cmd" in
        -h|--help|help) usage; return 0 ;;
    esac

    local -a args=()
    local a
    for a in "$@"; do
        if [ "$a" = "--json" ]; then JSON_MODE=true; else args+=("$a"); fi
    done

    case "$cmd" in
        propose)  cmd_propose  "${args[@]+"${args[@]}"}" ;;
        validate) cmd_validate "${args[@]+"${args[@]}"}" ;;
        commit)   cmd_commit   "${args[@]+"${args[@]}"}" ;;
        *)
            say_err "unknown command: ${cmd}"
            usage
            return "$EX_USAGE"
            ;;
    esac
}

main "$@"
