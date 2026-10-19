#!/usr/bin/env bash
# scripts/lib/commit-validate.sh - Conventional Commits message validation
# Rules: specs/003-standardize-commits/contracts/scope-and-type-rules.md section 4

COMMIT_TYPES=(feat fix chore docs style refactor perf test build ci req infra)
HEADER_MAX=100   # header length must be strictly less than this

# Results of validate_message, parallel arrays
V_RULE=()
V_SEV=()
V_DETAIL=()
V_SUGGEST=()

_add_issue() { # rule severity detail suggestion
    V_RULE+=("$1")
    V_SEV+=("$2")
    V_DETAIL+=("$3")
    V_SUGGEST+=("${4:-}")
}

is_commit_type() {
    local t="$1" x
    for x in "${COMMIT_TYPES[@]}"; do
        [ "$x" = "$t" ] && return 0
    done
    return 1
}

# Number of issues with severity "error"
validation_error_count() {
    local n=0 s
    for s in "${V_SEV[@]+"${V_SEV[@]}"}"; do
        [ "$s" = "error" ] && n=$((n + 1))
    done
    echo "$n"
}

# Parsed pieces of the last validated header
H_TYPE=""
H_SCOPE=""
H_HAS_SCOPE=false
H_BANG=false
H_SUMMARY=""

# validate_message <message> [git_state]
# Fills V_* arrays with every issue found. Always returns 0; use validation_error_count.
validate_message() {
    local msg="$1" state="${2:-normal}"
    V_RULE=(); V_SEV=(); V_DETAIL=(); V_SUGGEST=()
    H_TYPE=""; H_SCOPE=""; H_HAS_SCOPE=false; H_BANG=false; H_SUMMARY=""

    # empty-message
    if [ -z "${msg//[[:space:]]/}" ]; then
        _add_issue empty-message error "The commit message is empty or only whitespace." \
            "Write a header such as 'fix(scope): handle empty input'."
        return 0
    fi

    local header="${msg%%$'\n'*}"

    # Git-generated messages are accepted as git created them during a merge or rebase
    if [ "$state" = "merge" ] || [ "$state" = "rebase" ]; then
        case "$header" in
            "Merge "*|"Revert "*|"fixup! "*|"squash! "*) return 0 ;;
        esac
    fi

    local re='^([A-Za-z][A-Za-z0-9]*)(\(([^)]*)\))?(!)?:[[:space:]](.*)$'
    if [[ "$header" =~ $re ]]; then
        H_TYPE="${BASH_REMATCH[1]}"
        [ -n "${BASH_REMATCH[2]}" ] && H_HAS_SCOPE=true
        H_SCOPE="${BASH_REMATCH[3]}"
        [ -n "${BASH_REMATCH[4]}" ] && H_BANG=true
        H_SUMMARY="${BASH_REMATCH[5]}"
    else
        _add_issue header-format error "The header must look like 'type(scope)!: summary' (scope and ! optional)." \
            "Start with a type, then ': ', then the summary."
        H_SUMMARY="$header"
        _add_issue type-invalid error "No commit type found in the header." \
            "Use one of: ${COMMIT_TYPES[*]}"
    fi

    # type-invalid (only when a type was parsed)
    if [ -n "$H_TYPE" ] && ! is_commit_type "$H_TYPE"; then
        _add_issue type-invalid error "'${H_TYPE}' is not a valid type." "Use one of: ${COMMIT_TYPES[*]}"
    fi

    # scope-invalid
    if $H_HAS_SCOPE && ! [[ "$H_SCOPE" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        _add_issue scope-invalid error "The scope '${H_SCOPE}' must be lowercase letters, digits and hyphens." \
            "Use a scope such as idea-collector, ci or scripts, or drop the parentheses."
    fi

    # header-too-long (strictly less than HEADER_MAX)
    if [ "${#header}" -ge "$HEADER_MAX" ]; then
        _add_issue header-too-long error "The header is ${#header} characters; it must be under ${HEADER_MAX}." \
            "Shorten the summary and move detail into the body."
    fi

    # uppercase-summary
    if [[ "$H_SUMMARY" =~ ^[A-Z] ]]; then
        local lowered="${H_SUMMARY:0:1}"
        lowered="${lowered,,}${H_SUMMARY:1}"
        _add_issue uppercase-summary error "The summary must start with a lowercase letter." "${lowered}"
    fi

    # trailing-period
    if [[ "$header" == *. ]]; then
        _add_issue trailing-period error "The header must not end with a period." "${header%.}"
    fi

    # not-imperative (warning: a heuristic that must never block a commit)
    _check_imperative "$H_SUMMARY"

    # missing-blank-line: line 2, when present, must be blank
    local -a lines
    mapfile -t lines <<< "$msg"
    if [ "${#lines[@]}" -gt 1 ] && [ -n "${lines[1]//[[:space:]]/}" ]; then
        _add_issue missing-blank-line error "Line 2 must be blank when a body or footer follows the header." \
            "Insert an empty line after the header."
    fi

    _check_footers "$msg" "${lines[@]+"${lines[@]}"}"
    return 0
}

# Verbs commonly written in the third person, and words ending in ed/ing that are real imperatives
IMPERATIVE_THIRD_PERSON=" adds fixes updates removes changes creates deletes uses makes handles moves renames allows enables ensures bumps drops sets gets improves refactors replaces introduces implements includes passes stops starts skips prevents resolves corrects cleans "
IMPERATIVE_ALLOWLIST=" embed speed need feed seed proceed exceed succeed bleed breed shed shred red bed wed sled bring swing string ring sing ping spring "

_check_imperative() { # summary
    local summary="$1" word
    [ -z "$summary" ] && return 0
    word="${summary%%[[:space:]]*}"
    word="${word,,}"
    [[ "$IMPERATIVE_ALLOWLIST" == *" ${word} "* ]] && return 0
    if [[ "$IMPERATIVE_THIRD_PERSON" == *" ${word} "* ]] || { [ "${#word}" -gt 3 ] && [[ "$word" =~ (ed|ing)$ ]]; }; then
        local base="$word"
        if [[ "$word" == *ing ]]; then base="${word%ing}"
        elif [[ "$word" == *ed ]]; then base="${word%ed}"
        elif [[ "$word" == *ies ]]; then base="${word%ies}y"
        elif [[ "$word" == *es ]]; then base="${word%es}"
        elif [[ "$word" == *s ]]; then base="${word%s}"; fi
        _add_issue not-imperative warning "'${word}' is not in the imperative mood (heuristic)." \
            "Start with the imperative verb, for example '${base}'."
    fi
    return 0
}

# breaking-footer-missing (both directions) and footer-format
_check_footers() { # msg lines...
    local msg="$1"
    shift
    local has_footer=false
    grep -Eq '^BREAKING[ -]CHANGE: .+' <<< "$msg" && has_footer=true
    if $H_BANG && ! $has_footer; then
        _add_issue breaking-footer-missing error "'!' in the header requires a 'BREAKING CHANGE: <description>' footer." \
            "Add a footer line: BREAKING CHANGE: <what breaks>"
    elif ! $H_BANG && $has_footer; then
        _add_issue breaking-footer-missing error "A 'BREAKING CHANGE:' footer requires '!' before the colon in the header." \
            "Write the header as type(scope)!: summary"
    fi

    # footer block: the last paragraph, when its first line looks like a trailer
    local last="${msg##*$'\n\n'}"
    [ "$last" = "$msg" ] && return 0
    local first="${last%%$'\n'*}" l trailer_re='^([A-Za-z][A-Za-z-]*|BREAKING CHANGE): .+$'
    [[ "$first" =~ $trailer_re ]] || return 0
    while IFS= read -r l; do
        [[ "$l" =~ $trailer_re ]] && continue
        [[ "$l" =~ ^[[:space:]] ]] && continue    # continuation line
        _add_issue footer-format error "Footer line is not 'Token: value': ${l}" \
            "Write footers as 'Token: value', for example 'Co-Authored-By: Name <email>'."
    done <<< "$last"
    return 0
}

# Print issues as text (stderr)
print_validation_issues() {
    local i tag
    for i in "${!V_RULE[@]}"; do
        if [ "${V_SEV[$i]}" = "error" ]; then tag="error"; else tag="warning"; fi
        say "  - [${tag}] ${V_RULE[$i]}: ${V_DETAIL[$i]}"
        [ -n "${V_SUGGEST[$i]}" ] && say "      suggestion: ${V_SUGGEST[$i]}"
    done
    return 0
}

# JSON array of issues
validation_issues_json() {
    local out="[" i
    for i in "${!V_RULE[@]}"; do
        [ "$i" -gt 0 ] && out+=","
        out+="{\"rule\":$(json_str "${V_RULE[$i]}"),\"severity\":$(json_str "${V_SEV[$i]}"),\"detail\":$(json_str "${V_DETAIL[$i]}"),\"suggestion\":$(json_str_or_null "${V_SUGGEST[$i]}")}"
    done
    printf '%s]' "$out"
}
