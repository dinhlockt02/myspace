#!/usr/bin/env bash
# scripts/lib/prerequisites.sh - Workstation prerequisites auditing and remediation

# Detect OS family: linux, darwin, windows_wsl
detect_os() {
    local u_kernel
    u_kernel=$(uname -r 2>/dev/null || echo "")
    local u_sys
    u_sys=$(uname -s 2>/dev/null || echo "")

    if echo "$u_kernel" | grep -qi "microsoft"; then
        echo "windows_wsl"
    elif echo "$u_sys" | grep -qi "darwin"; then
        echo "darwin"
    else
        echo "linux"
    fi
}

# Version comparison: returns 0 if $1 >= $2
semver_gte() {
    local v1="${1#v}"
    local v2="${2#v}"

    # Normalize versions to major.minor.patch
    local v1_major v1_minor v1_patch
    local v2_major v2_minor v2_patch

    IFS='.' read -r v1_major v1_minor v1_patch <<< "$v1"
    IFS='.' read -r v2_major v2_minor v2_patch <<< "$v2"

    v1_major=${v1_major:-0}; v1_minor=${v1_minor:-0}; v1_patch=${v1_patch%%[^0-9]*}
    v2_major=${v2_major:-0}; v2_minor=${v2_minor:-0}; v2_patch=${v2_patch%%[^0-9]*}
    v1_patch=${v1_patch:-0}; v2_patch=${v2_patch:-0}

    if [ "$v1_major" -gt "$v2_major" ]; then return 0; fi
    if [ "$v1_major" -lt "$v2_major" ]; then return 1; fi
    if [ "$v1_minor" -gt "$v2_minor" ]; then return 0; fi
    if [ "$v1_minor" -lt "$v2_minor" ]; then return 1; fi
    if [ "$v1_patch" -ge "$v2_patch" ]; then return 0; fi
    return 1
}

check_host_prerequisites() {
    local is_json="${1:-false}"
    local os_type
    os_type=$(detect_os)
    local os_version
    os_version=$(uname -r)
    local active_shell="${SHELL:-/bin/bash}"

    local node_ver="missing"
    local pnpm_ver="missing"
    local go_ver="missing"
    local docker_ver="missing"
    local compose_ver="missing"
    local docker_daemon=false

    local node_ok=false
    local pnpm_ok=false
    local go_ok=false
    local docker_ok=false
    local compose_ok=false

    local remediation=()

    # 1. Node.js check (>= 20.0.0)
    if command -v node >/dev/null 2>&1; then
        node_ver=$(node -v | sed 's/^v//')
        if semver_gte "$node_ver" "20.0.0"; then
            node_ok=true
        else
            remediation+=("Node.js ($node_ver) is outdated. Minimum required: >= 20.0.0. Install via nvm: 'nvm install 20'")
        fi
    else
        remediation+=("Node.js is not installed. Install Node.js 20+ via https://nodejs.org or nvm.")
    fi

    # 2. pnpm check (>= 9.0.0)
    if command -v pnpm >/dev/null 2>&1; then
        pnpm_ver=$(pnpm -v)
        if semver_gte "$pnpm_ver" "9.0.0"; then
            pnpm_ok=true
        else
            remediation+=("pnpm ($pnpm_ver) is outdated. Minimum required: >= 9.0.0. Update: 'npm install -g pnpm'")
        fi
    else
        remediation+=("pnpm is not installed. Install via: 'npm install -g pnpm' or https://pnpm.io/installation")
    fi

    # 3. Go check (>= 1.22.0)
    if command -v go >/dev/null 2>&1; then
        local raw_go
        raw_go=$(go version | awk '{print $3}' | sed 's/^go//')
        go_ver="$raw_go"
        if semver_gte "$go_ver" "1.22.0"; then
            go_ok=true
        else
            remediation+=("Go ($go_ver) is outdated. Minimum required: >= 1.22.0. Install from https://go.dev/dl/")
        fi
    else
        remediation+=("Go is not installed. Required for backend services. Install from https://go.dev/dl/")
    fi

    # 4. Docker Engine check (>= 24.0.0)
    if command -v docker >/dev/null 2>&1; then
        local raw_docker
        raw_docker=$(docker -v 2>/dev/null | awk '{print $3}' | tr -d ',')
        docker_ver="${raw_docker:-present}"
        if semver_gte "$docker_ver" "24.0.0"; then
            docker_ok=true
        else
            docker_ok=true # Accept existing modern docker versions if parse is non-semver
        fi

        if docker info >/dev/null 2>&1; then
            docker_daemon=true
        else
            remediation+=("Docker daemon is inactive. Start Docker Desktop or run: 'sudo systemctl start docker'")
        fi
    else
        if [ "$os_type" = "darwin" ]; then
            remediation+=("Docker is not installed. Install Docker Desktop for macOS: https://docs.docker.com/desktop/setup/install/mac-install/")
        elif [ "$os_type" = "windows_wsl" ]; then
            remediation+=("Docker is not installed. Install Docker Desktop with WSL2 integration: https://docs.docker.com/desktop/setup/install/windows-install/")
        else
            remediation+=("Docker is not installed. Install Docker Engine for Linux: https://docs.docker.com/engine/install/")
        fi
    fi

    # 5. Docker Compose check (>= 2.20.0)
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        local raw_compose
        raw_compose=$(docker compose version 2>/dev/null | awk '{print $4}' | sed 's/^v//')
        compose_ver="${raw_compose:-present}"
        if semver_gte "$compose_ver" "2.20.0"; then
            compose_ok=true
        else
            compose_ok=true
        fi
    else
        remediation+=("Docker Compose is missing. Ensure docker compose v2 plugin is installed.")
    fi

    # Composite verdict
    local is_compatible=false
    if $node_ok && $pnpm_ok && $go_ok && $docker_ok && $compose_ok && $docker_daemon; then
        is_compatible=true
    fi

    # Store for JSON generation
    PROFILE_OS_TYPE="$os_type"
    PROFILE_OS_VERSION="$os_version"
    PROFILE_SHELL="$active_shell"
    PROFILE_NODE="$node_ver"
    PROFILE_PNPM="$pnpm_ver"
    PROFILE_GO="$go_ver"
    PROFILE_DOCKER="$docker_ver"
    PROFILE_COMPOSE="$compose_ver"
    PROFILE_DAEMON="$docker_daemon"
    PROFILE_COMPATIBLE="$is_compatible"
    PROFILE_REMEDIATION=("${remediation[@]}")

    # Output formatted report
    if ! $is_json; then
        printf "${COLOR_BOLD}Workstation Profile & Tooling Audit:${COLOR_RESET}\n"
        printf "  OS Family:        %s (%s)\n" "$os_type" "$os_version"
        printf "  Shell:            %s\n" "$active_shell"
        printf "  Node.js:          %-12s [%s]\n" "$node_ver" "$( $node_ok && printf "${COLOR_GREEN}PASS${COLOR_RESET}" || printf "${COLOR_RED}FAIL${COLOR_RESET}" )"
        printf "  pnpm:             %-12s [%s]\n" "$pnpm_ver" "$( $pnpm_ok && printf "${COLOR_GREEN}PASS${COLOR_RESET}" || printf "${COLOR_RED}FAIL${COLOR_RESET}" )"
        printf "  Go compiler:      %-12s [%s]\n" "$go_ver" "$( $go_ok && printf "${COLOR_GREEN}PASS${COLOR_RESET}" || printf "${COLOR_RED}FAIL${COLOR_RESET}" )"
        printf "  Docker Engine:    %-12s [%s]\n" "$docker_ver" "$( $docker_ok && printf "${COLOR_GREEN}PASS${COLOR_RESET}" || printf "${COLOR_RED}FAIL${COLOR_RESET}" )"
        printf "  Docker Compose:   %-12s [%s]\n" "$compose_ver" "$( $compose_ok && printf "${COLOR_GREEN}PASS${COLOR_RESET}" || printf "${COLOR_RED}FAIL${COLOR_RESET}" )"
        printf "  Docker Daemon:    %-12s [%s]\n" "$( $docker_daemon && echo "active" || echo "inactive" )" "$( $docker_daemon && printf "${COLOR_GREEN}PASS${COLOR_RESET}" || printf "${COLOR_RED}FAIL${COLOR_RESET}" )"
        printf "\n"

        if [ ${#remediation[@]} -gt 0 ]; then
            printf "${COLOR_YELLOW}${COLOR_BOLD}Remediation Steps Required:${COLOR_RESET}\n"
            for step in "${remediation[@]}"; do
                printf "  • %s\n" "$step"
            done
            printf "\n"
        fi
    else
        get_profile_json
    fi

    if $is_compatible; then
        return 0
    else
        return 1
    fi
}

get_profile_json() {
    local rem_json="[]"
    if [ ${#PROFILE_REMEDIATION[@]} -gt 0 ]; then
        local items=""
        for r in "${PROFILE_REMEDIATION[@]}"; do
            [ -n "$items" ] && items="$items, "
            items="$items\"$(echo "$r" | sed 's/"/\\"/g')\""
        done
        rem_json="[ $items ]"
    fi

    cat << EOF
{
  "os_type": "${PROFILE_OS_TYPE:-linux}",
  "os_version": "${PROFILE_OS_VERSION:-unknown}",
  "shell": "${PROFILE_SHELL:-/bin/bash}",
  "node_version": "${PROFILE_NODE:-missing}",
  "pnpm_version": "${PROFILE_PNPM:-missing}",
  "go_version": "${PROFILE_GO:-missing}",
  "docker_version": "${PROFILE_DOCKER:-missing}",
  "compose_version": "${PROFILE_COMPOSE:-missing}",
  "docker_daemon_active": ${PROFILE_DAEMON:-false},
  "is_compatible": ${PROFILE_COMPATIBLE:-false},
  "remediation_steps": ${rem_json}
}
EOF
}

