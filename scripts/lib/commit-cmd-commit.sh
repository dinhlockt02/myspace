#!/usr/bin/env bash
# scripts/lib/commit-cmd-commit.sh - `commit`: validate, check safety, confirm, then commit the staged set
#
# Guarantees: commits exactly what is staged; never runs git add, `commit -a`, --amend or --no-verify.

COMMIT_TRAILERS=()
COMMIT_WARNINGS_JSON="[]"

_commit_json() { # status hash header error
    local status="$1" hash="${2:-}" header="${3:-}" error="${4:-}"
    printf '{"status":%s,"hash":%s,"header":%s,"validation_warnings":%s,"error":%s}\n' \
        "$(json_str "$status")" "$(json_str_or_null "$hash")" "$(json_str_or_null "$header")" \
        "$COMMIT_WARNINGS_JSON" "$(json_str_or_null "$error")"
}

# Fail with a structured error. Usage: _commit_fail <exit-code> <message>
_commit_fail() {
    say_err "$2"
    $JSON_MODE && _commit_json error "" "${COMMIT_HEADER:-}" "$2"
    return "$1"
}

# Success if the last paragraph of the message is a footer block (Token: value lines)
_last_paragraph_is_footer() {
    local msg="$1" last l
    last="${msg##*$'\n\n'}"
    [ "$last" = "$msg" ] && return 1
    while IFS= read -r l; do
        [[ "$l" =~ ^([A-Za-z][A-Za-z-]*|BREAKING\ CHANGE):\ .+$ ]] || return 1
    done <<< "$last"
    return 0
}

# Append a footer line to the message, joining an existing footer block or starting a new one
append_footer_line() { # msg line
    local msg="$1" line="$2"
    if _last_paragraph_is_footer "$msg"; then
        printf '%s\n%s' "$msg" "$line"
    else
        printf '%s\n\n%s' "$msg" "$line"
    fi
}

cmd_commit() {
    local message="" have_message=false file="" assume_yes=false from_stdin=false
    COMMIT_TRAILERS=(); ALLOW_SENSITIVE_PATHS=(); COMMIT_HEADER=""; COMMIT_WARNINGS_JSON="[]"
    BREAKING_TEXT=""; NO_BREAKING=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --message) message="${2:-}"; have_message=true; shift 2 ;;
            --file) file="${2:-}"; shift 2 ;;
            --breaking) BREAKING_TEXT="${2:-}"; shift 2 ;;
            --no-breaking) NO_BREAKING=true; shift ;;
            --trailer) COMMIT_TRAILERS+=("${2:-}"); shift 2 ;;
            --allow-sensitive) ALLOW_SENSITIVE_PATHS+=("${2:-}"); shift 2 ;;
            --yes) assume_yes=true; shift ;;
            *) say_err "commit: unknown option '$1'"; return "$EX_USAGE" ;;
        esac
    done

    load_staged
    local state
    state=$(git_state)

    # 1. Protected branch (constitution Principle VI)
    if ! require_unprotected_branch; then
        $JSON_MODE && _commit_json error "" "" "protected branch"
        return "$EX_PROTECTED"
    fi

    # 2. Something must be staged
    if [ "$STAGED_COUNT" -eq 0 ]; then
        say "Nothing is staged. Stage the changes first, for example: git add <paths>"
        $JSON_MODE && _commit_json error "" "" "nothing staged"
        return "$EX_EMPTY"
    fi

    # 3. Obtain the message: --message, --file, or stdin
    if [ -n "$file" ]; then
        [ -f "$file" ] || { _commit_fail "$EX_USAGE" "commit: file not found: ${file}"; return $?; }
        message=$(cat "$file")
    elif ! $have_message; then
        if [ ! -t 0 ]; then
            message=$(cat)
            from_stdin=true
        else
            _commit_fail "$EX_USAGE" "commit: provide --message, --file, or pipe the message on stdin"
            return $?
        fi
    fi
    # Drop trailing blank lines and whitespace
    message="${message%"${message##*[![:space:]]}"}"

    # 3b. Breaking-change decision (FR-008): hints require --breaking or --no-breaking
    local hdr_re='^([A-Za-z][A-Za-z0-9]*(\([^)]*\))?)(!?):' header_has_bang=false first_line
    first_line="${message%%$'\n'*}"
    [[ "$first_line" =~ $hdr_re ]] && [ -n "${BASH_REMATCH[3]}" ] && header_has_bang=true
    compute_breaking_hints
    if [ -n "$BREAKING_TEXT" ]; then
        if ! $header_has_bang && [[ "$first_line" =~ $hdr_re ]]; then
            message="${BASH_REMATCH[1]}!:${first_line#"${BASH_REMATCH[0]}"}${message#"$first_line"}"
        fi
        if ! grep -q '^BREAKING CHANGE:' <<< "$message"; then
            message=$(append_footer_line "$message" "BREAKING CHANGE: ${BREAKING_TEXT}")
        fi
    elif ! $NO_BREAKING && ! $header_has_bang && [ "${#BREAKING_HINTS[@]}" -gt 0 ]; then
        say_err "this change may be breaking. Decide explicitly with --breaking \"<what breaks>\" or --no-breaking:"
        local h
        for h in "${BREAKING_HINTS[@]}"; do say "  - ${h}"; done
        $JSON_MODE && printf '{"status":"error","hash":null,"header":%s,"validation_warnings":[],"breaking_hints":%s,"error":"breaking-change decision required"}\n' \
            "$(json_str_or_null "$first_line")" "$(json_str_array "${BREAKING_HINTS[@]}")"
        return "$EX_BREAKING"
    fi

    # 4. Footers: --trailer lines (Token: value)
    local t
    for t in "${COMMIT_TRAILERS[@]+"${COMMIT_TRAILERS[@]}"}"; do
        if ! [[ "$t" =~ ^[A-Za-z][A-Za-z-]*:\ .+$ ]]; then
            _commit_fail "$EX_INVALID" "invalid --trailer '${t}': expected 'Token: value'"
            return $?
        fi
        message=$(append_footer_line "$message" "$t")
    done

    # 5. Validate: errors block, warnings are reported only
    validate_message "$message" "$state"
    COMMIT_HEADER="${message%%$'\n'*}"
    local warn_json="[" i first=true
    for i in "${!V_RULE[@]}"; do
        [ "${V_SEV[$i]}" = "warning" ] || continue
        $first || warn_json+=","
        warn_json+="{\"rule\":$(json_str "${V_RULE[$i]}"),\"detail\":$(json_str "${V_DETAIL[$i]}"),\"suggestion\":$(json_str_or_null "${V_SUGGEST[$i]}")}"
        first=false
    done
    COMMIT_WARNINGS_JSON="${warn_json}]"
    if [ "$(validation_error_count)" -gt 0 ]; then
        say_err "the commit message is invalid:"
        print_validation_issues
        $JSON_MODE && printf '{"status":"error","hash":null,"header":%s,"validation_warnings":%s,"issues":%s,"error":"invalid message"}\n' \
            "$(json_str_or_null "$COMMIT_HEADER")" "$COMMIT_WARNINGS_JSON" "$(validation_issues_json)"
        return "$EX_INVALID"
    fi
    if [ "${#V_RULE[@]}" -gt 0 ]; then
        say "message warnings (they do not block the commit):"
        print_validation_issues
    fi

    # 6. Safety: sensitive paths and credential patterns
    if ! run_safety_checks; then
        say_err "blocked by safety findings:"
        print_safety_findings
        $JSON_MODE && printf '{"status":"error","hash":null,"header":%s,"validation_warnings":%s,"safety_findings":%s,"error":"blocked by safety findings"}\n' \
            "$(json_str_or_null "$COMMIT_HEADER")" "$COMMIT_WARNINGS_JSON" "$(safety_findings_json)"
        return "$EX_BLOCKED"
    fi

    # 7. Confirmation: the contributor must have confirmed this exact message
    if ! $assume_yes; then
        if [ -t 0 ] && ! $from_stdin; then
            say "About to commit ${STAGED_COUNT} staged file(s) with this message:"
            say ""
            printf '%s\n\n' "$message" >&2
            local answer=""
            printf 'Commit? [y/N] ' >&2
            read -r answer || answer=""
            if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
                say "Cancelled. Nothing was committed and the staged files are unchanged."
                $JSON_MODE && _commit_json error "" "$COMMIT_HEADER" "cancelled"
                return "$EX_NOCONFIRM"
            fi
        else
            _commit_fail "$EX_NOCONFIRM" "confirmation required: show the exact message to the contributor, then re-run with --yes"
            return $?
        fi
    fi

    # 8. Commit exactly the staged set
    local out hash
    if ! out=$(printf '%s\n' "$message" | git commit -F - 2>&1); then
        say_err "git refused the commit:"
        say "$out"
        $JSON_MODE && _commit_json error "" "$COMMIT_HEADER" "git refused the commit"
        return "$EX_GITFAIL"
    fi
    hash=$(git rev-parse --short HEAD)
    say "Committed ${hash}: ${COMMIT_HEADER}"
    $JSON_MODE && _commit_json committed "$hash" "$COMMIT_HEADER" ""
    return 0
}
