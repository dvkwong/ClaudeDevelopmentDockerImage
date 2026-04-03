#!/bin/bash
set -euo pipefail

COMPOSE_FILE="docker-compose.local.yml"
CONTAINER_NAME="${LOCAL_CONTAINER_NAME:-claude-dev-local}"
PUID="${PUID:-$(id -u)}"
PGID="${PGID:-$(id -g)}"

export LOCAL_CONTAINER_NAME="$CONTAINER_NAME"
export PUID
export PGID

ensure_dirs() {
    mkdir -p .docker-test/workspace .docker-test/home .docker-test/root
}

compose() {
    docker compose -f "$COMPOSE_FILE" "$@"
}

usage() {
    cat <<'EOF'
Usage: ./local-dev.sh [command]

Commands:
  build       Build the local image
  up          Build and start the local container
  logs        Follow container logs
  shell       Open a shell as the mapped non-root user
  root-shell  Open a root shell
  recreate    Rebuild and recreate the container
  down        Stop and remove the local container
  clean       Remove the local container and local test data
  config      Render the local compose config
EOF
}

case "${1:-up}" in
    build)
        ensure_dirs
        compose build
        ;;
    up)
        ensure_dirs
        compose up -d --build
        ;;
    logs)
        compose logs -f
        ;;
    shell)
        docker exec -it --user "${PUID}:${PGID}" -e HOME=/home/devuser -w /workspace "$CONTAINER_NAME" bash
        ;;
    root-shell)
        docker exec -it -w /workspace "$CONTAINER_NAME" bash
        ;;
    recreate)
        ensure_dirs
        compose down
        compose up -d --build
        ;;
    down)
        compose down
        ;;
    clean)
        compose down --remove-orphans
        rm -rf .docker-test
        ;;
    config)
        ensure_dirs
        compose config
        ;;
    *)
        usage
        exit 1
        ;;
esac