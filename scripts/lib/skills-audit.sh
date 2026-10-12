#!/usr/bin/env bash
# scripts/lib/skills-audit.sh - Verification of repository AI skills and governance rules

audit_all_ai_skills() {
    local is_json="${1:-false}"
    local skills_dir="${REPO_ROOT}/.agents/skills"
    local total_skills=0
    local passed_skills=0
    local failed_skills=0

    # List of required Spec-Kit skills in complete SDLC suite
    local expected_skills=(
        "speckit-specify"
        "speckit-clarify"
        "speckit-plan"
        "speckit-tasks"
        "speckit-implement"
        "speckit-converge"
        "speckit-analyze"
        "speckit-checklist"
        "speckit-taskstoissues"
        "speckit-constitution"
    )

    SKILLS_AUDIT_RECORDS=()

    if ! $is_json; then
        printf "${COLOR_BOLD}AI Skills & Governance Health Audit:${COLOR_RESET}\n"
    fi

    for skill in "${expected_skills[@]}"; do
        total_skills=$((total_skills + 1))
        local s_path=".agents/skills/${skill}"
        local full_path="${skills_dir}/${skill}"
        local s_manifest=false
        local s_instruct=false
        local s_status="missing"
        local s_err=""

        if [ -d "$full_path" ]; then
            if [ -f "${full_path}/SKILL.md" ]; then
                s_instruct=true
                if grep -q "^name:" "${full_path}/SKILL.md" && grep -q "^---" "${full_path}/SKILL.md"; then
                    s_manifest=true
                    s_status="operational"
                    passed_skills=$((passed_skills + 1))
                else
                    s_status="degraded"
                    s_err="SKILL.md missing valid YAML frontmatter"
                    failed_skills=$((failed_skills + 1))
                fi
            else
                s_status="degraded"
                s_err="Missing SKILL.md file"
                failed_skills=$((failed_skills + 1))
            fi
        else
            s_status="missing"
            s_err="Skill directory not found"
            failed_skills=$((failed_skills + 1))
        fi

        if ! $is_json; then
            local badge
            if [ "$s_status" = "operational" ]; then
                badge="${COLOR_GREEN}READY${COLOR_RESET}"
            elif [ "$s_status" = "degraded" ]; then
                badge="${COLOR_YELLOW}DEGRADED${COLOR_RESET}"
            else
                badge="${COLOR_RED}MISSING${COLOR_RESET}"
            fi
            printf "  • %-26s [%s]\n" "$skill" "$badge"
        fi

        # Store record JSON snippet
        local rec
        rec="{\"skill_name\":\"${skill}\",\"skill_path\":\"${s_path}\",\"manifest_valid\":${s_manifest},\"status\":\"${s_status}\",\"error_message\":\"${s_err}\"}"
        SKILLS_AUDIT_RECORDS+=("$rec")
    done

    # Governance rules check
    local agents_md_ok=false
    local constitution_ok=false

    if [ -f "${REPO_ROOT}/AGENTS.md" ]; then
        agents_md_ok=true
    fi
    if [ -f "${REPO_ROOT}/.specify/memory/constitution.md" ]; then
        constitution_ok=true
    fi

    if ! $is_json; then
        printf "\n${COLOR_BOLD}Governance Constraints & Rules:${COLOR_RESET}\n"
        printf "  • AGENTS.md:                [%s]\n" "$( $agents_md_ok && printf "${COLOR_GREEN}PASS${COLOR_RESET}" || printf "${COLOR_RED}FAIL${COLOR_RESET}" )"
        printf "  • constitution.md:          [%s]\n" "$( $constitution_ok && printf "${COLOR_GREEN}PASS${COLOR_RESET}" || printf "${COLOR_RED}FAIL${COLOR_RESET}" )"
        printf "\n"
    fi

    if [ "$failed_skills" -eq 0 ] && $agents_md_ok && $constitution_ok; then
        if ! $is_json; then log_success "Complete AI-native SDLC suite ($passed_skills/$total_skills skills) is verified and operational."; fi
        return 0
    else
        if ! $is_json; then log_error "AI skills audit encountered issues ($failed_skills failed skills)."; fi
        return 1
    fi
}

get_skills_json() {
    local list=""
    for r in "${SKILLS_AUDIT_RECORDS[@]}"; do
        [ -n "$list" ] && list="$list, "
        list="$list$r"
    done
    printf "[ %s ]\n" "$list"
}
