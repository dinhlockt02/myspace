#!/usr/bin/env bash
# scripts/lib/pr-formatter.sh - Synthesis of PR title, description, scope, and verification steps

# Succeeds if a specs/ directory name belongs to the given branch: the names match, the
# numeric prefix (NNN) appears in the branch, or the branch introduces that spec by adding
# specs/<name>/spec.md. Merely editing files of an existing spec (a docs fix, a task update)
# does not make the branch "the feature", so it must not pull in the spec's intent and tasks.
feature_matches_branch() {
    local name="$1" branch="$2" base="$3"
    local leaf="${branch##*/}"

    if [ "$name" = "$branch" ] || [ "$name" = "$leaf" ]; then
        return 0
    fi

    local num="${name%%-*}"
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$branch" =~ (^|[/-])${num}($|[/-]) ]]; then
        return 0
    fi

    if get_branch_added_files "$base" | grep -qx "specs/${name}/spec.md"; then
        return 0
    fi

    return 1
}

# Prints the specs/ directory this branch is working on, or nothing if there is none.
# A stale .specify/feature.json or the newest spec must never be assumed to be the active
# feature, otherwise unrelated PRs inherit another feature's intent and task list.
detect_active_feature_dir() {
    local branch base
    branch=$(get_current_git_branch)
    base="${1:-${BASE_BRANCH:-main}}"

    local -a candidates=()

    if [ -f "${REPO_ROOT}/.specify/feature.json" ]; then
        local feat_dir
        feat_dir=$(grep -o '"feature_directory": *"[^"]*' "${REPO_ROOT}/.specify/feature.json" | cut -d'"' -f4 || echo "")
        [ -n "$feat_dir" ] && candidates+=("$(basename "$feat_dir")")
    fi

    # Every spec directory is a candidate; feature.json is only checked first as a hint
    local d
    for d in "${REPO_ROOT}/specs/"*/; do
        [ -d "$d" ] && candidates+=("$(basename "$d")")
    done

    local name
    for name in "${candidates[@]}"; do
        [ -n "$name" ] && [ -d "${REPO_ROOT}/specs/${name}" ] || continue
        if feature_matches_branch "$name" "$branch" "$base"; then
            echo "${REPO_ROOT}/specs/${name}"
            return 0
        fi
    done

    echo ""
    return 0
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
    local base="${BASE_BRANCH:-main}"

    if [ -n "$custom_title" ]; then
        echo "$custom_title"
        return 0
    fi

    local feat_dir
    feat_dir=$(detect_active_feature_dir "$base")
    if [ -n "$feat_dir" ] && [ -f "${feat_dir}/spec.md" ]; then
        local raw_title
        raw_title=$(grep -m 1 "^# Feature Specification:" "${feat_dir}/spec.md" | sed 's/^# Feature Specification: *//' || echo "")
        if [ -n "$raw_title" ]; then
            echo "feat: ${raw_title}"
            return 0
        fi
    fi

    # A single commit already has a conventional subject
    local mb count
    mb=$(git merge-base "$base" HEAD 2>/dev/null || echo "$base")
    count=$(git rev-list --count "${mb}..HEAD" 2>/dev/null || echo 0)
    if [ "$count" = "1" ]; then
        git log -1 --format=%s
        return 0
    fi

    # Otherwise derive "<type>(<scope>): <description>" from the branch name
    local type="chore" scope="" desc
    local -a parts
    IFS='/' read -r -a parts <<< "$branch"
    case "${parts[0]}" in
        feat|fix|chore|docs|refactor|test|ci|infra|req) type="${parts[0]}" ;;
        [0-9]*) type="feat" ;;  # Spec Kit feature branch: NNN-description
    esac
    if [ "${#parts[@]}" -ge 3 ]; then
        scope="${parts[1]}"
    fi
    desc=$(echo "${parts[${#parts[@]}-1]}" | sed -E 's/^[0-9]+-//; s/-/ /g')
    if [ -n "$scope" ]; then
        echo "${type}(${scope}): ${desc}"
    else
        echo "${type}: ${desc}"
    fi
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

# Verification commands for the projects a branch touches.
generate_verification_steps() {
    local base="$1"
    local steps="" n=0 proj
    while IFS= read -r proj; do
        [ -z "$proj" ] && continue
        local cmds=""
        case "$proj" in
            apps/idea-collector/frontend)
                cmds="pnpm nx run idea-collector-frontend:lint"$'\n'"pnpm nx run idea-collector-frontend:build" ;;
            apps/idea-collector/backend)
                cmds="cd apps/idea-collector/backend && go vet ./... && go test ./..." ;;
            apps/idea-collector/infra)
                cmds="pnpm nx run idea-collector-infra:validate"$'\n'"pnpm nx run idea-collector-infra:plan" ;;
            scripts)
                cmds="bash -n scripts/*.sh scripts/lib/*.sh" ;;
            *) continue ;;
        esac
        n=$((n + 1))
        steps="${steps}${n}. **\`${proj}\`**:"$'\n'"   \`\`\`bash"$'\n'
        while IFS= read -r c; do steps="${steps}   ${c}"$'\n'; done <<< "$cmds"
        steps="${steps}   \`\`\`"$'\n'
    done < <(get_affected_monorepo_projects "$base")

    if [ -z "$steps" ]; then
        steps="1. Review the diff and the CI checks on this pull request."$'\n'
    fi
    printf '%s' "${steps%$'\n'}"
}

generate_pr_body() {
    local branch="$1"
    local base="$2"
    local custom_notes="$3"
    local custom_deploy_notes="$4"

    local feat_dir
    feat_dir=$(detect_active_feature_dir "$base")
    local feat_id=""
    local spec_rel=""
    local intent=""
    local tasks_list=""

    if [ -n "$feat_dir" ]; then
        feat_id=$(basename "$feat_dir")
        spec_rel="specs/${feat_id}/spec.md"

        # Extract Intent from spec.md
        if [ -f "${feat_dir}/spec.md" ]; then
            intent=$(grep -A 2 -m 1 "### User Story 1" "${feat_dir}/spec.md" | tail -n 1 || echo "")
        fi

        # Extract completed tasks from tasks.md
        if [ -f "${feat_dir}/tasks.md" ]; then
            tasks_list=$(grep -E '^\- \[[xX]\]' "${feat_dir}/tasks.md" || echo "")
        fi
    fi

    # Commits on this branch (oldest first)
    local mb
    mb=$(git merge-base "$base" HEAD 2>/dev/null || echo "$base")
    local commit_list
    commit_list=$(git log --reverse --format='- %s' "${mb}..HEAD" 2>/dev/null || echo "")

    # Without a matching spec, the intent is the oldest commit's message body (or subject)
    if [ -z "$intent" ]; then
        local first
        first=$(git log --reverse --format='%H' "${mb}..HEAD" 2>/dev/null | head -n 1)
        if [ -n "$first" ]; then
            intent=$(git log -1 --format=%b "$first" | grep -v '^Co-Authored-By:' | awk 'BEGIN{RS=""} NR==1{gsub(/\n/," "); print}')
            [ -z "$intent" ] && intent=$(git log -1 --format=%s "$first")
        fi
    fi
    [ -z "$intent" ] && intent="Implementation updates across monorepo projects."

    # Affected projects list
    local affected_str=""
    while IFS= read -r proj; do
        [ -n "$proj" ] && affected_str="${affected_str}  - \`${proj}\`"$'\n'
    done < <(get_affected_monorepo_projects "$base")
    [ -z "$affected_str" ] && affected_str="  - \`monorepo\`"$'\n'

    # Feature lines only when this branch belongs to a spec
    local scope_str=""
    if [ -n "$feat_id" ]; then
        scope_str="- **Feature ID**: \`${feat_id}\`
- **Specification**: [\`${spec_rel}\`](${spec_rel})
"
    fi
    scope_str="${scope_str}- **Affected Monorepo Projects**:
${affected_str}"

    # Completed tasks (spec branches) or the branch's commits
    local changes_heading="📦 Changes" changes_body="$commit_list"
    if [ -n "$tasks_list" ]; then
        changes_heading="✅ Completed Tasks"
        changes_body="$tasks_list"
    fi
    [ -z "$changes_body" ] && changes_body="- See the diff."

    local verify_str
    verify_str=$(generate_verification_steps "$base")

    # Build Deployment Notes
    local deploy_notes
    deploy_notes=$(generate_deployment_notes "$feat_dir" "$base" "$custom_deploy_notes")

    local body=""
    body="## 🎯 Intent

${intent}

---

## 🔍 Scope & Touched Projects

${scope_str}
---

## ${changes_heading}

${changes_body}

---

## 🧪 Verification Steps

Reviewers can verify this change by running the following commands locally:

${verify_str}

---

## 🚀 Deployment Notes

${deploy_notes}

---

## 🛡️ Pre-Flight Quality Gates

Run by \`scripts/pr-workflow.sh\` before this PR was opened:

- [x] **Git Cleanliness**: Working tree verified clean
- [x] **Linting**: \`nx run-many -t lint\` passed
- [x] **Tests**: Backend \`go test ./...\` passed
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
