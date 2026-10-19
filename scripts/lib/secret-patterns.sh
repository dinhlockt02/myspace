#!/usr/bin/env bash
# scripts/lib/secret-patterns.sh - Credential patterns shared by pr-gates.sh and commit-safety.sh
# Full list and rationale: specs/003-standardize-commits/contracts/safety-rules.md

# Base rules: "name|case-insensitive(i or empty)|ERE". These are the patterns pr-gates.sh has always used.
SECRET_RULES_BASE=(
    'aws-secret-access-key|i|aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{30,}'
    'github-token-ghp|i|ghp_[a-zA-Z0-9]{36}'
    'private-key-block|i|BEGIN[[:space:]]+(RSA|EC|OPENSSH|DSA)[[:space:]]+PRIVATE[[:space:]]+KEY'
)

# Extended rules: high-confidence token formats only (generic "password=" matching is out of scope)
SECRET_RULES_EXTENDED=(
    'aws-access-key-id||AKIA[0-9A-Z]{16}'
    'google-oauth-client-secret||GOCSPX-[A-Za-z0-9_-]{20,}'
    'slack-token||xox[baprs]-[A-Za-z0-9-]{10,}'
    'github-token||gh[opusr]_[A-Za-z0-9]{36}'
    'github-fine-grained-pat||github_pat_[A-Za-z0-9_]{22,}'
    'pgp-private-key||BEGIN[ ]PGP[ ]PRIVATE[ ]KEY[ ]BLOCK'
)

_join_rule_patterns() {
    local out="" rule pat
    for rule in "$@"; do
        pat="${rule#*|*|}"
        out="${out:+${out}|}${pat}"
    done
    printf '%s' "$out"
}

# Combined regexes (grep -E). SECRET_PATTERN is exactly the original pr-gates.sh regex.
SECRET_PATTERN="($(_join_rule_patterns "${SECRET_RULES_BASE[@]}"))"
SECRET_PATTERN_EXTENDED="($(_join_rule_patterns "${SECRET_RULES_BASE[@]}" "${SECRET_RULES_EXTENDED[@]}"))"
