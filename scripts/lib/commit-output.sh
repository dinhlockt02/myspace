#!/usr/bin/env bash
# scripts/lib/commit-output.sh - Exit codes, JSON helpers and text output for commit-workflow.sh

# Exit codes (see specs/003-standardize-commits/contracts/cli-schema.yml)
EX_OK=0
EX_INVALID=1
EX_EMPTY=2
EX_BLOCKED=3
EX_PROTECTED=4
EX_NOCONFIRM=5
EX_BREAKING=6
EX_GITFAIL=7
EX_USAGE=64

# Human-readable output always goes to stderr so stdout stays clean for --json
say() { printf '%s\n' "$*" >&2; }
say_err() { printf 'error: %s\n' "$*" >&2; }

# Escape a string for use inside a JSON string literal
json_escape() {
    local s="$1"
    s=$(printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037')
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

json_str() { printf '"%s"' "$(json_escape "$1")"; }

# "value" or null when empty
json_str_or_null() {
    if [ -z "${1:-}" ]; then printf 'null'; else json_str "$1"; fi
}

json_bool() { if [ "${1:-}" = "true" ]; then printf 'true'; else printf 'false'; fi; }

# JSON array of strings from the arguments
json_str_array() {
    local out="[" first=true item
    for item in "$@"; do
        $first || out+=","
        out+=$(json_str "$item")
        first=false
    done
    printf '%s]' "$out"
}
