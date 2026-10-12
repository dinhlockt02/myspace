#!/usr/bin/env bash
# scripts/setup-dev.sh - Core developer onboarding and environment bootstrap CLI
set -eo pipefail

SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(CDPATH="" cd "${SCRIPT_DIR}/.." && pwd)"

# Auto-discover standard toolchains if not present in current shell PATH
if ! command -v node >/dev/null 2>&1 && [ -s "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1090
    source "$NVM_DIR/nvm.sh"
fi
if ! command -v go >/dev/null 2>&1 && [ -d "/usr/local/go/bin" ]; then
    export PATH="$PATH:/usr/local/go/bin"
fi
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Source helper modules
source "${SCRIPT_DIR}/lib/reporter.sh"
[ -f "${SCRIPT_DIR}/lib/prerequisites.sh" ] && source "${SCRIPT_DIR}/lib/prerequisites.sh"
[ -f "${SCRIPT_DIR}/lib/containers.sh" ] && source "${SCRIPT_DIR}/lib/containers.sh"
[ -f "${SCRIPT_DIR}/lib/templates.sh" ] && source "${SCRIPT_DIR}/lib/templates.sh"
[ -f "${SCRIPT_DIR}/lib/skills-audit.sh" ] && source "${SCRIPT_DIR}/lib/skills-audit.sh"

# Default flag states
FLAG_CHECK_ONLY=false
FLAG_BOOTSTRAP=false
FLAG_CONTAINERS=false
FLAG_VERIFY_SKILLS=false
FLAG_VERIFY=false
FLAG_CLEAN=false
FLAG_JSON=false

show_help() {
    cat << 'EOF'
Usage: ./scripts/setup-dev.sh [OPTIONS]
       pnpm run setup [-- OPTIONS]

Myspace Monorepo Developer Onboarding and Environment Setup CLI.

OPTIONS:
  --check-only       Run prerequisite and host diagnostics only (non-destructive)
  --bootstrap        Install monorepo dependencies and instantiate .env templates
  --containers       Start and verify local containerized backing services (DynamoDB Local)
  --verify-skills    Audit repository AI skills, rules, and governance tools
  --verify           Execute verification smoke tests across all workspace projects
  --clean            Purge node_modules, build artifacts, and container volumes before setup
  --json             Output machine-readable JSON diagnostic payload
  --help, -h         Show this help message

EXIT CODES:
  0  SUCCESS
  1  PREREQUISITE_ERROR (missing or incompatible host tool)
  2  BOOTSTRAP_ERROR (dependency installation or template error)
  3  CONTAINER_ERROR (Docker daemon or container startup failure)
  4  SKILL_ERROR (AI skill or constitutional governance issue)
  5  VERIFY_ERROR (smoke test failure)

EOF
    exit 0
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check-only)
            FLAG_CHECK_ONLY=true
            ;;
        --bootstrap)
            FLAG_BOOTSTRAP=true
            ;;
        --containers)
            FLAG_CONTAINERS=true
            ;;
        --verify-skills)
            FLAG_VERIFY_SKILLS=true
            ;;
        --verify)
            FLAG_VERIFY=true
            ;;
        --clean)
            FLAG_CLEAN=true
            ;;
        --json)
            FLAG_JSON=true
            ;;
        --)
            # Ignore bare argument separator passed by pnpm / npm
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run with --help for usage information." >&2
            exit 1
            ;;
    esac
    shift
done

# If no specific action flags provided, run full standard onboarding
if ! $FLAG_CHECK_ONLY && ! $FLAG_BOOTSTRAP && ! $FLAG_CONTAINERS && ! $FLAG_VERIFY_SKILLS && ! $FLAG_VERIFY && ! $FLAG_CLEAN; then
    RUN_FULL=true
else
    RUN_FULL=false
fi

# Clean state if requested
if $FLAG_CLEAN; then
    if ! $FLAG_JSON; then log_info "Cleaning workspace artifacts and stopping containers..."; fi
    type stop_containers >/dev/null 2>&1 && stop_containers || true
    rm -rf "${REPO_ROOT}/node_modules" "${REPO_ROOT}/.nx/cache" "${REPO_ROOT}/dist"
    if ! $FLAG_JSON; then log_success "Workspace cleaned successfully."; fi
    if ! $RUN_FULL && ! $FLAG_CHECK_ONLY && ! $FLAG_BOOTSTRAP && ! $FLAG_CONTAINERS && ! $FLAG_VERIFY; then
        exit 0
    fi
fi

# Phase 1 / US1: Prerequisites Check
if $RUN_FULL || $FLAG_CHECK_ONLY; then
    RUN_MODE="check-only"
    if ! $FLAG_JSON; then print_banner; fi
    if type check_host_prerequisites >/dev/null 2>&1; then
        if ! check_host_prerequisites "$FLAG_JSON"; then
            if ! $FLAG_JSON; then
                log_error "Prerequisite check failed. Please resolve the issues above."
            fi
            exit 1
        fi
    fi
    if $FLAG_CHECK_ONLY; then
        exit 0
    fi
fi

# Phase 2 / US2: Bootstrap (Dependencies + Templates)
if $RUN_FULL || $FLAG_BOOTSTRAP; then
    RUN_MODE="bootstrap"
    if ! $FLAG_JSON; then log_info "Bootstrapping workspace dependencies and configurations..."; fi
    
    # Instantiate .env templates
    if type instantiate_all_templates >/dev/null 2>&1; then
        instantiate_all_templates || {
            log_error "Failed to instantiate environment templates."
            exit 2
        }
    fi

    # Install pnpm workspace dependencies
    if ! $FLAG_JSON; then log_info "Installing pnpm dependencies..."; fi
    (cd "$REPO_ROOT" && pnpm install --frozen-lockfile=false) || {
        log_error "Failed to install pnpm dependencies."
        exit 2
    }

    # Download Go backend dependencies if present
    if [ -f "$REPO_ROOT/apps/idea-collector/backend/go.mod" ]; then
        if ! $FLAG_JSON; then log_info "Verifying Go backend dependencies..."; fi
        (cd "$REPO_ROOT/apps/idea-collector/backend" && go mod download) || {
            log_warn "Go module download warning (proceeding)."
        }
    fi
    if ! $FLAG_JSON; then log_success "Workspace dependencies bootstrapped successfully."; fi
fi

# Phase 2 / US2: Containers Provisioning
if $RUN_FULL || $FLAG_CONTAINERS; then
    RUN_MODE="containers"
    if type start_containers >/dev/null 2>&1; then
        start_containers || exit 3
        wait_for_containers_healthy || exit 3
    fi
fi

# Phase 3 / US3: Skills Verification
if $RUN_FULL || $FLAG_VERIFY_SKILLS; then
    RUN_MODE="verify-skills"
    if type audit_all_ai_skills >/dev/null 2>&1; then
        if ! audit_all_ai_skills "$FLAG_JSON"; then
            exit 4
        fi
    fi
fi

# Phase 4 / US4: Smoke Test & Reporting
if $RUN_FULL || $FLAG_VERIFY; then
    RUN_MODE="verify"
    if ! $FLAG_JSON; then log_info "Running workspace verification smoke test..."; fi
    
    # Run lint and tests across monorepo projects
    (cd "$REPO_ROOT" && NX_DAEMON=false pnpm nx run-many -t lint,test,build --parallel=2) || {
        log_error "Workspace smoke tests failed."
        exit 5
    }

    if [ -f "$REPO_ROOT/apps/idea-collector/backend/main.go" ]; then
        (cd "$REPO_ROOT/apps/idea-collector/backend" && go build -o /dev/null main.go) || {
            log_error "Go backend compilation failed."
            exit 5
        }
    fi

    if ! $FLAG_JSON; then
        log_success "All workspace smoke tests passed!"
    fi
fi

# Complete / Persist Diagnostic Report
OVERALL_STATUS="passed"
if type generate_full_report_json >/dev/null 2>&1; then
    REPORT_JSON=$(generate_full_report_json)
    if [ -n "$REPORT_JSON" ]; then
        save_diagnostic_report "$REPORT_JSON"
        if $FLAG_JSON; then
            printf "%s\n" "$REPORT_JSON"
        fi
    fi
fi

if ! $FLAG_JSON; then
    printf "\n"
    log_success "Developer environment onboarding completed successfully!"
    log_info "You are ready to develop and contribute across the Myspace monorepo."
    printf "\n"
fi

exit 0
