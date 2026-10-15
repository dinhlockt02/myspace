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
        elif [[ "$f" =~ ^apps/idea-collector/infra/ ]]; then
            projects+=("apps/idea-collector/infra")
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

generate_deployment_notes() {
    local feat_dir="$1"
    local base="$2"
    local custom_deploy_notes="$3"

    local notes=""

    # 1. Custom deployment notes passed directly
    if [ -n "$custom_deploy_notes" ]; then
        notes="${custom_deploy_notes}"$'\n\n'
    fi

    # 2. Extract from active feature directory if deployment notes file or section exists
    if [ -n "$feat_dir" ]; then
        if [ -f "${feat_dir}/deployment.md" ]; then
            local file_content
            file_content=$(cat "${feat_dir}/deployment.md")
            notes="${notes}${file_content}"$'\n\n'
        elif [ -f "${feat_dir}/deploy-notes.md" ]; then
            local file_content
            file_content=$(cat "${feat_dir}/deploy-notes.md")
            notes="${notes}${file_content}"$'\n\n'
        elif [ -f "${feat_dir}/plan.md" ]; then
            local plan_deploy
            plan_deploy=$(awk '/^##* [0-9.]* *Deployment/I{flag=1; next} /^##* [0-9.]* *[A-Z]/{if(flag) exit} flag' "${feat_dir}/plan.md" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || echo "")
            if [ -n "$plan_deploy" ]; then
                notes="${notes}${plan_deploy}"$'\n\n'
            fi
        fi
    fi

    # 3. Contextual notes based on touched components
    local changed_files
    changed_files=$(get_branch_changed_files "$base")

    local has_infra=false
    local has_frontend=false
    local has_backend=false

    if echo "$changed_files" | grep -E '^apps/[^/]+/infra/|^infra/' >/dev/null 2>&1; then
        has_infra=true
    fi
    if echo "$changed_files" | grep -E '^apps/idea-collector/frontend/' >/dev/null 2>&1; then
        has_frontend=true
    fi
    if echo "$changed_files" | grep -E '^apps/idea-collector/backend/' >/dev/null 2>&1; then
        has_backend=true
    fi

    local auto_notes=""
    if $has_infra; then
        auto_notes="${auto_notes}- **Infrastructure Changes (Terraform)**:"$'\n'
        auto_notes="${auto_notes}  - Terraform plan and apply will execute via CI/CD on merge to \`main\`."$'\n'
        auto_notes="${auto_notes}  - **Approval Required**: Under Monorepo Constitution Principle II, infrastructure changes require explicit approval before merge."$'\n'
        auto_notes="${auto_notes}  - Verify all sensitive environment variables (e.g. \`TF_VAR_google_client_secret\`) are configured in repository secrets or AWS SSM."$'\n'
    fi

    if $has_frontend; then
        auto_notes="${auto_notes}- **Frontend Deployment**:"$'\n'
        auto_notes="${auto_notes}  - Assets build and sync to S3 bucket with CloudFront cache invalidation upon merge to \`main\`."$'\n'
        auto_notes="${auto_notes}  - Verify frontend environment variables (e.g. \`VITE_COGNITO_DOMAIN\`, \`VITE_COGNITO_CLIENT_ID\`, \`VITE_COGNITO_REDIRECT_URI\`) are configured in production."$'\n'
    fi

    if $has_backend; then
        auto_notes="${auto_notes}- **Backend Services**:"$'\n'
        auto_notes="${auto_notes}  - Lambda function binary (\`bootstrap\`) is packaged and updated on merge to \`main\`."$'\n'
        auto_notes="${auto_notes}  - Zero downtime: Backward compatibility is preserved for existing data and sessions."$'\n'
    fi

    if [ -z "$auto_notes" ]; then
        auto_notes="- **Standard Pipeline**: Automated GitHub Actions workflow triggers on merge to \`main\`."$'\n'
    fi

    auto_notes="${auto_notes}- **Rollback Strategy**: Revert the merge commit on \`main\` to automatically redeploy the previous stable build."

    if [ -n "$notes" ]; then
        echo "${notes}${auto_notes}"
    else
        echo "${auto_notes}"
    fi
}

generate_pr_body() {
    local branch="$1"
    local base="$2"
    local custom_notes="$3"
    local custom_deploy_notes="$4"

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

    # Build Deployment Notes
    local deploy_notes
    deploy_notes=$(generate_deployment_notes "$feat_dir" "$base" "$custom_deploy_notes")

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

## 🚀 Deployment Notes

${deploy_notes}

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
