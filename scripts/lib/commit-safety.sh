#!/usr/bin/env bash
# scripts/lib/commit-safety.sh - Sensitive path and credential-pattern detection (FR-009, SC-004)
# Rules: specs/003-standardize-commits/contracts/safety-rules.md
# Requires commit-staging.sh (STAGED_PATHS/STAGED_STATUS) and secret-patterns.sh.

# Paths the contributor explicitly allowed (set from --allow-sensitive)
ALLOW_SENSITIVE_PATHS=()

# Findings, parallel arrays populated by run_safety_checks
SAFETY_KIND=()
SAFETY_PATH=()
SAFETY_RULE=()
SAFETY_OVERRIDABLE=()
SAFETY_ALLOWED=()

is_path_allowed() {
    local p="$1" a
    for a in "${ALLOW_SENSITIVE_PATHS[@]+"${ALLOW_SENSITIVE_PATHS[@]}"}"; do
        [ "$a" = "$p" ] && return 0
    done
    return 1
}

# Success if the path conventionally holds secrets
is_sensitive_path() {
    local base="${1##*/}"
    case "$base" in
        *.example|*.sample|*.template|*.pub) return 1 ;;
    esac
    case "$base" in
        .env|.env.*|*.pem|*.key|*.p12|id_rsa*|*.tfstate|*.tfstate.*|*.tfvars|credentials) return 0 ;;
    esac
    return 1
}

_add_finding() { # kind path rule overridable
    local allowed=false
    if [ "$1" = "sensitive-path" ] && is_path_allowed "$2"; then allowed=true; fi
    SAFETY_KIND+=("$1")
    SAFETY_PATH+=("$2")
    SAFETY_RULE+=("$3")
    SAFETY_OVERRIDABLE+=("$4")
    SAFETY_ALLOWED+=("$allowed")
}

find_sensitive_paths() {
    local i path
    for i in "${!STAGED_PATHS[@]}"; do
        path="${STAGED_PATHS[$i]}"
        [ "${STAGED_STATUS[$i]}" = "D" ] && continue   # removing a sensitive file is safe
        if is_sensitive_path "$path"; then
            _add_finding sensitive-path "$path" "sensitive-path" true
        fi
    done
}

# Scan only the added lines of the staged diff. Reports path and rule name, never the matched text.
find_secret_patterns() {
    local i path added rule name flag pat
    for i in "${!STAGED_PATHS[@]}"; do
        path="${STAGED_PATHS[$i]}"
        [ "${STAGED_STATUS[$i]}" = "D" ] && continue
        added=$(git diff --cached -U0 --no-color -- "$path" | grep -E '^\+' | grep -vE '^\+\+\+' || true)
        [ -z "$added" ] && continue
        for rule in "${SECRET_RULES_BASE[@]}" "${SECRET_RULES_EXTENDED[@]}"; do
            name="${rule%%|*}"
            flag="${rule#*|}"; flag="${flag%%|*}"
            pat="${rule#*|*|}"
            if [ "$flag" = "i" ]; then
                printf '%s\n' "$added" | grep -Eiq -e "$pat" && _add_finding secret-pattern "$path" "$name" false
            else
                printf '%s\n' "$added" | grep -Eq -e "$pat" && _add_finding secret-pattern "$path" "$name" false
            fi
        done
    done
    return 0
}

# Run both checks. Returns 0 when nothing blocks, 1 when at least one finding is not allowed.
run_safety_checks() {
    SAFETY_KIND=(); SAFETY_PATH=(); SAFETY_RULE=(); SAFETY_OVERRIDABLE=(); SAFETY_ALLOWED=()
    find_sensitive_paths
    find_secret_patterns
    local i
    for i in "${!SAFETY_KIND[@]}"; do
        [ "${SAFETY_ALLOWED[$i]}" = "false" ] && return 1
    done
    return 0
}

# Print the findings as text (stderr). Never prints matched content.
print_safety_findings() {
    local i note
    for i in "${!SAFETY_KIND[@]}"; do
        if [ "${SAFETY_ALLOWED[$i]}" = "true" ]; then note="allowed by --allow-sensitive"
        elif [ "${SAFETY_OVERRIDABLE[$i]}" = "true" ]; then note="override with --allow-sensitive ${SAFETY_PATH[$i]}"
        else note="credential content cannot be overridden: unstage the file and rotate the secret"; fi
        say "  - ${SAFETY_KIND[$i]}: ${SAFETY_PATH[$i]} (${SAFETY_RULE[$i]}) - ${note}"
    done
}

# JSON array of findings
safety_findings_json() {
    local out="[" i
    for i in "${!SAFETY_KIND[@]}"; do
        [ "$i" -gt 0 ] && out+=","
        out+="{\"kind\":$(json_str "${SAFETY_KIND[$i]}"),\"path\":$(json_str "${SAFETY_PATH[$i]}"),\"rule\":$(json_str "${SAFETY_RULE[$i]}"),\"overridable\":$(json_bool "${SAFETY_OVERRIDABLE[$i]}"),\"allowed\":$(json_bool "${SAFETY_ALLOWED[$i]}")}"
    done
    printf '%s]' "$out"
}
