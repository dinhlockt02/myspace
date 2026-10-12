#!/usr/bin/env bash
# scripts/lib/templates.sh - Safe .env.example instantiation logic

instantiate_all_templates() {
    log_info "Instantiating environment configuration files from templates..."
    local count=0

    # Find all .env.example files across repository
    while IFS= read -r example_file; do
        if [ -f "$example_file" ]; then
            local target_dir
            target_dir="$(dirname "$example_file")"
            local target_env="${target_dir}/.env"

            if [ ! -f "$target_env" ]; then
                cp "$example_file" "$target_env"
                log_success "Created $(realpath --relative-to="$REPO_ROOT" "$target_env") from template."
                count=$((count + 1))
            else
                log_info "Preserved existing $(realpath --relative-to="$REPO_ROOT" "$target_env") (already configured)."
            fi
        fi
    done < <(find "$REPO_ROOT" -name ".env.example" -not -path "*/node_modules/*")

    log_success "Environment templates verified ($count new file(s) instantiated)."
    return 0
}
