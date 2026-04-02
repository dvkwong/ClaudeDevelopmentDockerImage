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

if [ -n "${GH_TOKEN}" ]; then
    log "  GH_TOKEN: (set)"
else
    log "  GH_TOKEN: (not set — gh CLI and git will use unauthenticated access)"
fi

if [ -n "${ANTHROPIC_API_KEY}" ]; then
    log "  ANTHROPIC_API_KEY: (set)"
else
    log "  ANTHROPIC_API_KEY: (not set — claude CLI will not work without it)"
fi

# ── User mapping ─────────────────────────────────────────────────────────────
if [ "${PUID}" != "0" ] || [ "${PGID}" != "0" ]; then
    log "Remapping container user to UID=${PUID} GID=${PGID}"

    # Create/update the group — handle the case where the desired GID is
    # already taken by another group (e.g. GID 100 = "users" on many distros).
    if getent group devuser > /dev/null 2>&1; then
        CURRENT_GID=$(getent group devuser | cut -d: -f3)
        if [ "${CURRENT_GID}" != "${PGID}" ]; then
            if getent group "${PGID}" > /dev/null 2>&1; then
                EXISTING_GROUP=$(getent group "${PGID}" | cut -d: -f1)
                log "GID ${PGID} already belongs to group '${EXISTING_GROUP}' — reusing it"
            else
                groupmod -g "${PGID}" devuser
            fi
        fi
    else
        if getent group "${PGID}" > /dev/null 2>&1; then
            EXISTING_GROUP=$(getent group "${PGID}" | cut -d: -f1)
            log "GID ${PGID} already belongs to group '${EXISTING_GROUP}' — reusing it"
        else
            groupadd -g "${PGID}" devuser
        fi
    fi

    # Create/update the user — handle the case where the desired UID is
    # already taken by another user.
    if getent passwd devuser > /dev/null 2>&1; then
        # devuser exists — check for UID collision before modifying
        CURRENT_UID=$(id -u devuser)
        if [ "${CURRENT_UID}" != "${PUID}" ]; then
            BLOCKING_USER=$(getent passwd "${PUID}" 2>/dev/null | cut -d: -f1)
            if [ -n "${BLOCKING_USER}" ]; then
                log "UID ${PUID} already belongs to user '${BLOCKING_USER}' — reassigning it"
                usermod -u "$(shuf -i 60000-60999 -n 1)" "${BLOCKING_USER}"
            fi
        fi
        usermod -u "${PUID}" -g "${PGID}" devuser
    else
        if getent passwd "${PUID}" > /dev/null 2>&1; then
            EXISTING_USER=$(getent passwd "${PUID}" | cut -d: -f1)
            log "UID ${PUID} already belongs to user '${EXISTING_USER}' — updating its GID"
            usermod -g "${PGID}" "${EXISTING_USER}"
        else
            useradd -u "${PUID}" -g "${PGID}" -m -s /bin/bash devuser
        fi
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
# Restart ttyd if it exits unexpectedly so the healthcheck stays valid.
while true; do
    wait "${TTYD_PID}" 2>/dev/null || true
    log "Web console process exited — restarting in 3 seconds …"
    sleep 3
    if [ -n "${RUN_USER}" ]; then
        ttyd --port "${TTYD_PORT}" --writable gosu "${RUN_USER}" /bin/bash &
    else
        ttyd --port "${TTYD_PORT}" --writable /bin/bash &
    fi
    TTYD_PID=$!
    log "Web console restarted (PID ${TTYD_PID})"
done
