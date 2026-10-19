#!/usr/bin/env bash
# scripts/lib/commit-cmd-propose.sh - `propose`: read-only analysis of the staged changes

PROPOSE_WARNINGS=()

_emit_propose_json() { # status error-or-empty
    local status="$1" error="${2:-}" i out files="[" first=true
    for i in "${!STAGED_PATHS[@]}"; do
        $first || files+=","
        files+="{\"path\":$(json_str "${STAGED_PATHS[$i]}"),\"status\":$(json_str "${STAGED_STATUS[$i]}"),\"scope\":$(json_str "${FILE_SCOPE[$i]:-}"),\"category\":$(json_str "${FILE_CATEGORY[$i]:-}")}"
        first=false
    done
    files+="]"

    local split="[]"
    $MULTI_SCOPE && split=$(split_suggestion_json)

    out="{\"status\":$(json_str "$status")"
    out+=",\"error\":$(json_str_or_null "$error")"
    out+=",\"branch\":$(json_str "$(current_branch)")"
    out+=",\"git_state\":$(json_str "$PROPOSE_GIT_STATE")"
    out+=",\"staged_count\":${STAGED_COUNT},\"unstaged_count\":${UNSTAGED_COUNT}"
    out+=",\"files\":${files}"
    out+=",\"proposal\":{\"type\":$(json_str_or_null "$P_TYPE"),\"type_candidates\":$(json_str_array "${TYPE_CANDIDATES[@]+"${TYPE_CANDIDATES[@]}"}")"
    out+=",\"scope\":$(json_str_or_null "$P_SCOPE"),\"summary\":$(json_str_or_null "$P_SUMMARY")"
    out+=",\"header\":$(json_str_or_null "$P_HEADER"),\"message\":$(json_str_or_null "$P_MESSAGE")"
    out+=",\"breaking_hints\":$(json_str_array "${BREAKING_HINTS[@]+"${BREAKING_HINTS[@]}"}")}"
    out+=",\"warnings\":$(json_str_array "${PROPOSE_WARNINGS[@]+"${PROPOSE_WARNINGS[@]}"}")"
    out+=",\"safety_findings\":$(safety_findings_json)"
    out+=",\"split_suggestion\":${split}}"
    printf '%s\n' "$out"
}

_print_propose_text() {
    local w i
    say "Branch: $(current_branch)   staged: ${STAGED_COUNT}   unstaged: ${UNSTAGED_COUNT}   state: ${PROPOSE_GIT_STATE}"
    for i in "${!STAGED_PATHS[@]}"; do
        say "  ${STAGED_STATUS[$i]} ${STAGED_PATHS[$i]}  [${FILE_SCOPE[$i]:-}]"
        [ "$i" -ge 29 ] && { say "  ... and $((STAGED_COUNT - 30)) more"; break; }
    done
    if [ -n "$P_TYPE" ]; then
        say "Proposed type: ${P_TYPE}"
    else
        say "Type is ambiguous; candidates: ${TYPE_CANDIDATES[*]+${TYPE_CANDIDATES[*]}}"
    fi
    say "Proposed scope: ${P_SCOPE:-<none>}"
    [ -n "$P_HEADER" ] && say "Proposed header: ${P_HEADER}"
    for w in "${PROPOSE_WARNINGS[@]+"${PROPOSE_WARNINGS[@]}"}"; do say "warning: ${w}"; done
    for w in "${BREAKING_HINTS[@]+"${BREAKING_HINTS[@]}"}"; do say "possible breaking change: ${w}"; done
    $MULTI_SCOPE && { say "This changeset spans several scopes; consider splitting it:"; split_suggestion_text; }
    return 0
}

cmd_propose() {
    local force_type="" force_scope="" force_scope_set=false summary=""
    ALLOW_SENSITIVE_PATHS=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --type) force_type="${2:-}"; shift 2 ;;
            --scope) force_scope="${2:-}"; force_scope_set=true; shift 2 ;;
            --summary) summary="${2:-}"; shift 2 ;;
            --allow-sensitive) ALLOW_SENSITIVE_PATHS+=("${2:-}"); shift 2 ;;
            *) say_err "propose: unknown option '$1'"; return "$EX_USAGE" ;;
        esac
    done

    PROPOSE_WARNINGS=(); PROPOSE_GIT_STATE=$(git_state)
    P_TYPE=""; P_SCOPE=""; P_SUMMARY="$summary"; P_HEADER=""; P_MESSAGE=""
    BREAKING_HINTS=(); TYPE_CANDIDATES=(); MULTI_SCOPE=false
    SAFETY_KIND=(); SAFETY_PATH=(); SAFETY_RULE=(); SAFETY_OVERRIDABLE=(); SAFETY_ALLOWED=()

    load_staged

    # Constitution Principle VI
    if ! require_unprotected_branch; then
        $JSON_MODE && _emit_propose_json error "protected-branch"
        return "$EX_PROTECTED"
    fi

    if [ "$STAGED_COUNT" -eq 0 ]; then
        say "Nothing is staged."
        say "Stage the changes you want to commit first, for example: git add <paths>   (or git add -p)"
        [ "$UNSTAGED_COUNT" -gt 0 ] && say "(${UNSTAGED_COUNT} unstaged change(s) exist; they are not touched.)"
        $JSON_MODE && _emit_propose_json empty
        return "$EX_EMPTY"
    fi

    classify_staged
    compute_breaking_hints

    local safe=true
    run_safety_checks || safe=false

    # Edge cases
    [ "$UNSTAGED_COUNT" -gt 0 ] && PROPOSE_WARNINGS+=("unstaged-present")
    [ "$STAGED_COUNT" -gt "$LARGE_CHANGESET_FILES" ] && PROPOSE_WARNINGS+=("large-changeset")
    $MULTI_SCOPE && PROPOSE_WARNINGS+=("multi-scope")
    if [ "$PROPOSE_GIT_STATE" != "normal" ]; then
        PROPOSE_WARNINGS+=("merge-in-progress")
        P_MESSAGE=$(merge_message)
    fi

    # Overrides, then the header
    P_TYPE="${force_type:-$PROPOSED_TYPE}"
    if $force_scope_set; then
        [ "$force_scope" = "none" ] && P_SCOPE="" || P_SCOPE="$force_scope"
    else
        P_SCOPE="$PROPOSED_SCOPE"
    fi
    P_HEADER=$(build_header "$P_TYPE" "$P_SCOPE" "$P_SUMMARY")
    [ "$PROPOSE_GIT_STATE" = "normal" ] && P_MESSAGE="$P_HEADER"
    # The scope is omitted from the header when it equals the type, so report null too
    [ "$P_SCOPE" = "$P_TYPE" ] && P_SCOPE=""

    _print_propose_text

    if ! $safe; then
        say_err "blocked by safety findings:"
        print_safety_findings
        $JSON_MODE && _emit_propose_json blocked
        return "$EX_BLOCKED"
    fi
    if [ "${#SAFETY_KIND[@]}" -gt 0 ]; then
        say "Allowed safety findings:"
        print_safety_findings
    fi

    $JSON_MODE && _emit_propose_json ok
    return 0
}
