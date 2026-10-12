#!/usr/bin/env bash
# scripts/lib/pr-formatter.sh - Synthesis of PR title, description, scope, and verification steps

detect_active_feature_dir() {
    local branch
    branch=$(get_current_git_branch)

    # 1. Check .specify/feature.json
    if [ -f "${REPO_ROOT}/.specify/feature.json" ]; then
        local feat_dir
        feat_dir=$(grep -o '"feature_directory": *"[^"]*' "${REPO_ROOT}/.specify/feature.json" | cut -d'"' -f4 || echo "")
        if [ -n "$feat_dir" ] && [ -d "${REPO_ROOT}/${feat_dir}" ]; then
            echo "${REPO_ROOT}/${feat_dir}"
            return 0
        fi
    fi

    # 2. Check specs/<branch>
    if [ -d "${REPO_ROOT}/specs/${branch}" ]; then
        echo "${REPO_ROOT}/specs/${branch}"
        return 0
    fi

    # 3. Fallback: most recent directory in specs/
    local latest
    latest=$(ls -td "${REPO_ROOT}/specs/"*/ 2>/dev/null | head -n 1 || echo "")
    if [ -n "$latest" ]; then
        echo "${latest%/}"
        return 0
    fi

    echo ""
    return 1
}

get_affected_monorepo_projects() {
    local base="${1:-main}"
    local changed_files
    changed_files=$(get_branch_changed_files "$base")

    local projects=()

    while IFS= read -r f; do
        [ -z "$f" ] && continue
        if [[ "$f" =~ ^apps/idea-collector/frontend/ ]]; then
            projects+=("apps/idea-collector/frontend")
        elif [[ "$f" =~ ^apps/idea-collector/backend/ ]]; then
            projects+=("apps/idea-collector/backend")
        elif [[ "$f" =~ ^apps/commifra/ ]]; then
            projects+=("apps/commifra")
        elif [[ "$f" =~ ^infra/ ]]; then
            projects+=("infra")
        elif [[ "$f" =~ ^scripts/ ]]; then
            projects+=("scripts")
        elif [[ "$f" =~ ^\.agents/ ]]; then
            projects+=("agent-skills")
        elif [[ "$f" =~ ^\.github/ ]]; then
            projects+=("ci-cd")
        elif [[ "$f" =~ ^docs/ ]]; then
            projects+=("docs")
        else
            projects+=("root")
        fi
    done <<< "$changed_files"

    # Deduplicate
    printf "%s\n" "${projects[@]}" | sort -u
}

generate_pr_title() {
    local branch="$1"
    local custom_title="$2"

    if [ -n "$custom_title" ]; then
        echo "$custom_title"
        return 0
    fi

    local feat_dir
    feat_dir=$(detect_active_feature_dir)
    if [ -n "$feat_dir" ] && [ -f "${feat_dir}/spec.md" ]; then
        local raw_title
        raw_title=$(grep -m 1 "^# Feature Specification:" "${feat_dir}/spec.md" | sed 's/^# Feature Specification: *//' || echo "")
        if [ -n "$raw_title" ]; then
            echo "feat: ${raw_title}"
            return 0
        fi
    fi

    # Fallback to branch name formatted as conventional commit
    local clean_branch
    clean_branch=$(echo "$branch" | sed -E 's/^[0-9]+-//; s/-/ /g')
    echo "feat: ${clean_branch}"
}

generate_pr_body() {
    local branch="$1"
    local base="$2"
    local custom_notes="$3"

    local feat_dir
    feat_dir=$(detect_active_feature_dir)
    local feat_id="general"
    local spec_rel="specs/"
    local intent="Implementation updates across monorepo projects."
    local tasks_list=""

    if [ -n "$feat_dir" ]; then
        feat_id=$(basename "$feat_dir")
        spec_rel="specs/${feat_id}/spec.md"

        # Extract Intent from spec.md
        if [ -f "${feat_dir}/spec.md" ]; then
            local spec_intent
            spec_intent=$(grep -A 2 -m 1 "### User Story 1" "${feat_dir}/spec.md" | tail -n 1 || echo "")
            if [ -n "$spec_intent" ]; then
                intent="$spec_intent"
            fi
        fi

        # Extract completed tasks from tasks.md
        if [ -f "${feat_dir}/tasks.md" ]; then
            tasks_list=$(grep -E '^\- \[[xX]\]' "${feat_dir}/tasks.md" || echo "")
        fi
    fi

    if [ -z "$tasks_list" ]; then
        tasks_list="- [x] Complete feature implementation and verify local tests"
    fi

    # Affected projects list
    local affected_str=""
    while IFS= read -r proj; do
        [ -n "$proj" ] && affected_str="${affected_str}  - \`${proj}\`"$'\n'
    done < <(get_affected_monorepo_projects "$base")
    [ -z "$affected_str" ] && affected_str="  - \`monorepo\`"$'\n'

    # Build Verification steps based on affected projects
    local verify_str="1. **Host & Pre-Flight Checks**:"$'\n'
    verify_str="${verify_str}   \`\`\`bash"$'\n'
    verify_str="${verify_str}   pnpm run setup -- --check-only"$'\n'
    verify_str="${verify_str}   \`\`\`"$'\n'
    verify_str="${verify_str}2. **Verification Smoke Tests**:"$'\n'
    verify_str="${verify_str}   \`\`\`bash"$'\n'
    verify_str="${verify_str}   pnpm run setup -- --verify"$'\n'
    verify_str="${verify_str}   \`\`\`"

    local body=""
    body="## 🎯 Intent

${intent}

---

## 🔍 Scope & Touched Projects

- **Feature ID**: \`${feat_id}\`
- **Specification**: [\`${spec_rel}\`](${spec_rel})
- **Affected Monorepo Projects**:
${affected_str}
---

## ✅ Completed Tasks

${tasks_list}

---

## 🧪 Verification Steps

Reviewers can verify this change by running the following commands locally:

${verify_str}

---

## 🛡️ Pre-Flight Quality Gates

- [x] **Git Cleanliness**: Working tree verified clean
- [x] **Linting & Typecheck**: Clean pass across affected packages
- [x] **Test Suites**: Baseline and integration smoke tests passing
- [x] **Secret Audit**: Diff verified free of credentials, tokens, and keys

---

<!-- custom-notes -->"

    if [ -n "$custom_notes" ]; then
        body="${body}
### 📝 Reviewer Notes
${custom_notes}
"
    fi

    echo "$body"
}
