#!/bin/bash
set -e

# ── Logging helpers ───────────────────────────────────────────────────────────
log()  { echo "[entrypoint] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# ── PUID / PGID support ───────────────────────────────────────────────────────
# Unraid (and many other hosts) pass PUID / PGID environment variables so that
# files written inside the container are owned by the host user rather than root.
#
# Defaults: run as root (0:0) when neither variable is set.
PUID=${PUID:-0}
PGID=${PGID:-0}

log "Starting Claude Development Environment"
log "========================================"

# ── Print tool versions ──────────────────────────────────────────────────────
log "Tool versions:"
log "  Node.js : $(node --version 2>/dev/null || echo 'not found')"
log "  npm     : $(npm --version 2>/dev/null || echo 'not found')"
log "  dotnet  : $(dotnet --version 2>/dev/null || echo 'not found')"
log "  git     : $(git --version 2>/dev/null || echo 'not found')"
log "  gh      : $(gh --version 2>/dev/null | head -1 || echo 'not found')"
log "  bun     : $(bun --version 2>/dev/null || echo 'not found')"
log "  claude  : $(claude --version 2>/dev/null || echo 'not found')"
log "  ttyd    : $(ttyd --version 2>/dev/null | head -1 || echo 'not found')"

log "Configuration:"
log "  PUID=${PUID}  PGID=${PGID}"
log "  Workspace: /workspace"

if [ -n "${DISCORD_BOT_TOKEN}" ]; then
    log "  Discord bot token: (set)"
else
    log "  Discord bot token: (not set)"
fi

# ── User mapping ─────────────────────────────────────────────────────────────
if [ "${PUID}" != "0" ] || [ "${PGID}" != "0" ]; then
    log "Remapping container user to UID=${PUID} GID=${PGID}"

    # Create/update the group
    if ! getent group devuser > /dev/null 2>&1; then
        groupadd -g "${PGID}" devuser
    else
        groupmod -g "${PGID}" devuser
    fi

    # Create/update the user
    if ! getent passwd devuser > /dev/null 2>&1; then
        useradd -u "${PUID}" -g "${PGID}" -m -s /bin/bash devuser
    else
        usermod -u "${PUID}" -g "${PGID}" devuser
    fi

    # Give the mapped user ownership of the workspace only when needed,
    # to avoid a slow recursive chown on large bind-mounted directories.
    if [ "$(stat -c '%u:%g' /workspace)" != "${PUID}:${PGID}" ]; then
        chown "${PUID}:${PGID}" /workspace
    fi

    RUN_USER="${PUID}:${PGID}"
else
    RUN_USER=""
fi

# ── Start ttyd (web-based terminal) ──────────────────────────────────────────
# ttyd provides a browser-accessible console on port 7681 so Unraid users can
# open the container shell from the Docker tab or navigate directly to the port.
TTYD_PORT=${TTYD_PORT:-7681}
log "Starting web console (ttyd) on port ${TTYD_PORT} …"

if [ -n "${RUN_USER}" ]; then
    # Run ttyd as root but have it spawn shells as the mapped user
    ttyd --port "${TTYD_PORT}" --writable gosu "${RUN_USER}" /bin/bash &
else
    ttyd --port "${TTYD_PORT}" --writable /bin/bash &
fi
TTYD_PID=$!
log "Web console started (PID ${TTYD_PID})"
log "  → Open http://<your-server-ip>:${TTYD_PORT} in a browser"
log "========================================"
log "Container is ready."

# ── Keep the container running ───────────────────────────────────────────────
# Wait on ttyd so the container stays alive and logs remain visible.
# If ttyd exits unexpectedly, fall back to an infinite sleep so the container
# does not stop.
wait "${TTYD_PID}" 2>/dev/null || true
log "Web console process ended — keeping container alive"
exec tail -f /dev/null
