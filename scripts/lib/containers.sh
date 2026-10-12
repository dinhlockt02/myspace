#!/usr/bin/env bash
# scripts/lib/containers.sh - Docker Compose lifecycle and health checking for dev onboarding

check_docker_daemon() {
    if ! command -v docker >/dev/null 2>&1; then
        return 1
    fi
    docker info >/dev/null 2>&1
}

start_containers() {
    log_info "Starting local backing services via Docker Compose..."
    if ! check_docker_daemon; then
        log_error "Docker daemon is not running or accessible. Please start Docker Engine or Desktop."
        return 1
    fi

    (cd "$REPO_ROOT" && docker compose up -d) || {
        log_error "Failed to start Docker Compose services."
        return 1
    }
}

wait_for_containers_healthy() {
    log_info "Waiting for containerized services to become healthy..."
    local timeout=30
    local elapsed=0

    while [ "$elapsed" -lt "$timeout" ]; do
        # Check if port 8000 responds (DynamoDB Local returns 400 with missing auth header)
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ 2>/dev/null || echo "000")
        if [ "$code" = "400" ] || [ "$code" = "200" ]; then
            log_success "DynamoDB Local is up and accepting connections at http://localhost:8000"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    log_warn "Timeout waiting for DynamoDB Local health probe on port 8000."
    return 1
}

stop_containers() {
    log_info "Stopping local backing services..."
    if check_docker_daemon; then
        (cd "$REPO_ROOT" && docker compose down)
    fi
}

get_containers_status_json() {
    local status="stopped"
    local health="none"
    local cid=""

    if check_docker_daemon; then
        cid=$(docker compose ps -q dynamodb-local 2>/dev/null || echo "")
        if [ -n "$cid" ]; then
            status="running"
            local code
            code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/ 2>/dev/null || echo "000")
            if [ "$code" = "400" ] || [ "$code" = "200" ]; then
                health="healthy"
            else
                health="unhealthy"
            fi
        else
            status="stopped"
        fi
    else
        status="missing"
    fi

    cat << EOF
[
  {
    "service_name": "dynamodb-local",
    "container_id": "${cid:-null}",
    "status": "${status}",
    "health_status": "${health}",
    "endpoint_url": "http://localhost:8000"
  }
]
EOF
}
