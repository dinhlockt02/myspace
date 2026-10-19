#!/usr/bin/env bash
# scripts/lib/commit-cmd-validate.sh - `validate`: check a message without touching git state

cmd_validate() {
    local message="" have_message=false file="" from_stdin=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --file) file="${2:-}"; shift 2 ;;
            -) from_stdin=true; shift ;;
            -*) say_err "validate: unknown option '$1'"; return "$EX_USAGE" ;;
            *) message="$1"; have_message=true; shift ;;
        esac
    done

    if [ -n "$file" ]; then
        [ -f "$file" ] || { say_err "validate: file not found: ${file}"; return "$EX_USAGE"; }
        message=$(cat "$file")
    elif $from_stdin; then
        message=$(cat)
    elif ! $have_message; then
        say_err "validate: provide a message, --file <path>, or - for stdin"
        return "$EX_USAGE"
    fi

    # Read-only: the git state only decides whether merge/rebase messages are accepted
    local state=normal
    git rev-parse --git-dir >/dev/null 2>&1 && state=$(git_state)

    validate_message "$message" "$state"
    local errors valid=true
    errors=$(validation_error_count)
    [ "$errors" -gt 0 ] && valid=false

    if $valid; then
        if [ "${#V_RULE[@]}" -gt 0 ]; then
            say "valid, with warnings:"
            print_validation_issues
        else
            say "valid"
        fi
    else
        say "invalid (${errors} error(s)):"
        print_validation_issues
    fi
    $JSON_MODE && printf '{"valid":%s,"issues":%s}\n' "$valid" "$(validation_issues_json)"
    $valid && return 0
    return "$EX_INVALID"
}
