#!/usr/bin/env bash
# scripts/lib/commit-classify.sh - Scope, type and breaking-change heuristics for staged changes
# Rules: specs/003-standardize-commits/contracts/scope-and-type-rules.md
# Requires commit-staging.sh (STAGED_PATHS / STAGED_STATUS).

# Per-file results, parallel to STAGED_PATHS
FILE_SCOPE=()
FILE_CATEGORY=()

# Overall results
SCOPE_LIST=()          # distinct primary scopes, in order of first appearance
MULTI_SCOPE=false
PROPOSED_SCOPE=""      # empty means "no scope"
PROPOSED_TYPE=""       # empty means "ambiguous"
TYPE_CANDIDATES=()
BREAKING_HINTS=()

# First matching rule wins (section 1 of the rules)
scope_for_path() {
    local p="$1" rest
    case "$p" in
        apps/*/*) rest="${p#apps/}"; printf '%s' "${rest%%/*}" ;;
        .github/*) printf 'ci' ;;
        infra/*) printf 'infra' ;;
        packages/*|shared/*) printf 'shared' ;;
        scripts/*) printf 'scripts' ;;
        *) printf 'repo' ;;
    esac
}

# source / test / docs / ci / build / config / lockfile / other
category_for_path() {
    local p="$1" b="${1##*/}"
    case "$b" in
        pnpm-lock.yaml|package-lock.json|yarn.lock|go.sum) printf 'lockfile'; return ;;
    esac
    case "$p" in
        .github/*) printf 'ci'; return ;;
    esac
    case "$p" in
        *_test.go|*.test.*|*.spec.*|tests/*|*/tests/*) printf 'test'; return ;;
    esac
    case "$p" in
        *.md|README*|docs/*|specs/*) printf 'docs'; return ;;
    esac
    case "$b" in
        package.json|go.mod|Makefile|Dockerfile*|nx.json|pnpm-workspace.yaml|project.json) printf 'build'; return ;;
    esac
    case "$p" in
        *.go|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.sh|*.py|*.css|*.html) printf 'source'; return ;;
        *.json|*.yml|*.yaml|*.toml|*.tf|.gitignore|.claude/*|.agents/*|.specify/*) printf 'config'; return ;;
    esac
    printf 'other'
}

_is_dep_manifest() { # package.json or go.mod
    case "${1##*/}" in package.json|go.mod) return 0 ;; esac
    return 1
}

_is_req_path() {
    case "$1" in
        specs/*/spec.md|specs/*/checklists/requirements.md) return 0 ;;
    esac
    return 1
}

_is_infra_path() {
    case "$1" in
        infra/*|apps/*/infra/*) return 0 ;;
    esac
    return 1
}

_in_list() { # needle list...
    local n="$1" x
    shift
    for x in "$@"; do [ "$x" = "$n" ] && return 0; done
    return 1
}

# Classify the staged set. Fills FILE_*, SCOPE_LIST, MULTI_SCOPE, PROPOSED_SCOPE, PROPOSED_TYPE, TYPE_CANDIDATES.
classify_staged() {
    FILE_SCOPE=(); FILE_CATEGORY=(); SCOPE_LIST=(); TYPE_CANDIDATES=()
    MULTI_SCOPE=false; PROPOSED_SCOPE=""; PROPOSED_TYPE=""
    local i p cat sc
    for i in "${!STAGED_PATHS[@]}"; do
        p="${STAGED_PATHS[$i]}"
        FILE_SCOPE+=("$(scope_for_path "$p")")
        FILE_CATEGORY+=("$(category_for_path "$p")")
    done
    [ "${#STAGED_PATHS[@]}" -eq 0 ] && return 0

    # --- scope: primary files decide; tests, docs and lockfiles are companions of a main change
    local -a primary=() tests=() docs=()
    for i in "${!STAGED_PATHS[@]}"; do
        case "${FILE_CATEGORY[$i]}" in
            lockfile) ;;
            test) tests+=("${FILE_SCOPE[$i]}") ;;
            docs) docs+=("${FILE_SCOPE[$i]}") ;;
            *) primary+=("${FILE_SCOPE[$i]}") ;;
        esac
    done
    local -a basis=()
    if [ "${#primary[@]}" -gt 0 ]; then basis=("${primary[@]}")
    elif [ "${#tests[@]}" -gt 0 ]; then basis=("${tests[@]}")
    elif [ "${#docs[@]}" -gt 0 ]; then basis=("${docs[@]}")
    fi
    for sc in "${basis[@]+"${basis[@]}"}"; do
        _in_list "$sc" "${SCOPE_LIST[@]+"${SCOPE_LIST[@]}"}" || SCOPE_LIST+=("$sc")
    done
    if [ "${#SCOPE_LIST[@]}" -gt 1 ]; then
        MULTI_SCOPE=true
    elif [ "${#SCOPE_LIST[@]}" -eq 1 ] && [ "${SCOPE_LIST[0]}" != "repo" ]; then
        PROPOSED_SCOPE="${SCOPE_LIST[0]}"
    fi

    # --- type: evidence only; ambiguous sets get ranked candidates
    local all_dep=true all_req=true all_infra=true all_docs=true all_test=true all_ci=true
    local new_source=false mod_source=false
    for i in "${!STAGED_PATHS[@]}"; do
        p="${STAGED_PATHS[$i]}"; cat="${FILE_CATEGORY[$i]}"
        if [ "$cat" != "lockfile" ] && ! _is_dep_manifest "$p"; then all_dep=false; fi
        _is_req_path "$p" || all_req=false
        _is_infra_path "$p" || all_infra=false
        [ "$cat" = "docs" ] || all_docs=false
        [ "$cat" = "test" ] || all_test=false
        [ "$cat" = "ci" ] || all_ci=false
        if [ "$cat" = "source" ]; then
            if [ "${STAGED_STATUS[$i]}" = "A" ]; then new_source=true; else mod_source=true; fi
        fi
    done

    if $all_dep; then PROPOSED_TYPE="build"; PROPOSED_SCOPE="deps"
    elif $all_req; then PROPOSED_TYPE="req"
    elif $all_infra; then PROPOSED_TYPE="infra"
    elif $all_docs; then PROPOSED_TYPE="docs"
    elif $all_test; then PROPOSED_TYPE="test"
    elif $all_ci; then PROPOSED_TYPE="ci"
    elif ! _has_added_or_deleted && git diff --cached --ignore-all-space --quiet 2>/dev/null; then PROPOSED_TYPE="style"
    fi

    if [ -z "$PROPOSED_TYPE" ]; then
        if $new_source; then TYPE_CANDIDATES+=(feat refactor); fi
        if $mod_source; then
            local c
            for c in fix feat refactor perf; do
                _in_list "$c" "${TYPE_CANDIDATES[@]+"${TYPE_CANDIDATES[@]}"}" || TYPE_CANDIDATES+=("$c")
            done
        fi
        if ! $new_source && ! $mod_source; then TYPE_CANDIDATES+=(chore build); fi
    fi
    return 0
}

_has_added_or_deleted() {
    local s
    for s in "${STAGED_STATUS[@]}"; do
        [ "$s" != "M" ] && return 0
    done
    return 1
}

# Echo the header for the given parts; the scope is omitted when empty or equal to the type
build_header() { # type scope summary [bang]
    local type="$1" scope="$2" summary="$3" bang="${4:-}"
    [ -z "$type" ] || [ -z "$summary" ] && return 0
    if [ -n "$scope" ] && [ "$scope" != "$type" ]; then
        printf '%s(%s)%s: %s' "$type" "$scope" "$bang" "$summary"
    else
        printf '%s%s: %s' "$type" "$bang" "$summary"
    fi
}

# Advisory breaking-change hints (section 3 of the rules). Only the contributor decides.
compute_breaking_hints() {
    BREAKING_HINTS=()
    local i p s removed
    for i in "${!STAGED_PATHS[@]}"; do
        p="${STAGED_PATHS[$i]}"; s="${STAGED_STATUS[$i]}"
        if [ "$s" = "D" ] || [ "$s" = "R" ]; then
            case "$p" in
                apps/*/backend/*|packages/*|shared/*|contracts/*|*/contracts/*)
                    BREAKING_HINTS+=("removed or renamed file in a public area: ${p}") ;;
            esac
            case "$p" in
                *migration*|*schema*) BREAKING_HINTS+=("deleted migration or schema file: ${p}") ;;
            esac
        fi
        [ "$s" = "D" ] && continue
        case "$p" in
            *.tf)
                if git diff --cached -U0 --no-color -- "$p" | grep -Eq '^-[[:space:]]*(variable|output)[[:space:]]+"'; then
                    BREAKING_HINTS+=("removed or renamed Terraform variable/output in ${p}")
                fi ;;
            *.go|*.ts|*.tsx|*.js|*.jsx)
                removed=$(git diff --cached -U0 --no-color -- "$p" | grep -E '^-(func (\([^)]*\) )?[A-Z]|export )' || true)
                [ -n "$removed" ] && BREAKING_HINTS+=("removed or changed an exported symbol in ${p}") ;;
        esac
    done
    return 0
}

# Text and JSON for splitting a multi-scope changeset: groups of files by path scope
split_suggestion_text() {
    local sc i files
    for sc in "${SCOPE_LIST[@]}"; do
        files=""
        for i in "${!STAGED_PATHS[@]}"; do
            [ "${FILE_SCOPE[$i]}" = "$sc" ] && files+=" ${STAGED_PATHS[$i]}"
        done
        say "  - ${sc}:${files}"
    done
    say "  Commit one scope at a time, for example: git restore --staged -- <files of the other scopes>"
}

split_suggestion_json() {
    local out="[" first=true sc i
    local -a fl
    for sc in "${SCOPE_LIST[@]+"${SCOPE_LIST[@]}"}"; do
        fl=()
        for i in "${!STAGED_PATHS[@]}"; do
            [ "${FILE_SCOPE[$i]}" = "$sc" ] && fl+=("${STAGED_PATHS[$i]}")
        done
        $first || out+=","
        out+="{\"scope\":$(json_str "$sc"),\"files\":$(json_str_array "${fl[@]}")}"
        first=false
    done
    printf '%s]' "$out"
}
