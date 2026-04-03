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
mkdir -p /workspace /home/devuser /root

# ── Print tool versions ──────────────────────────────────────────────────────
log "Tool versions:"
log "  Node.js : $(node --version 2>/dev/null || echo 'not found')"
log "  npm     : $(npm --version 2>/dev/null || echo 'not found')"
log "  dotnet  : $(dotnet --version 2>/dev/null || echo 'not found')"
log "  git     : $(git --version 2>/dev/null || echo 'not found')"
log "  gh      : $(gh --version 2>/dev/null | head -1 || echo 'not found')"
log "  bun     : $(bun --version 2>/dev/null || echo 'not found')"
log "  claude  : $(claude --version 2>/dev/null || echo 'not found')"

log "Configuration:"
log "  PUID=${PUID}  PGID=${PGID}"
log "  Workspace: /workspace"
log "  Persistent non-root home: /home/devuser"
log "  Persistent root home: /root"

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

    if [ "$(stat -c '%u:%g' /home/devuser)" != "${PUID}:${PGID}" ]; then
        chown "${PUID}:${PGID}" /home/devuser
    fi

    # Give the mapped user ownership of the workspace only when needed,
    # to avoid a slow recursive chown on large bind-mounted directories.
    if [ "$(stat -c '%u:%g' /workspace)" != "${PUID}:${PGID}" ]; then
        chown "${PUID}:${PGID}" /workspace
    fi

    export HOME=/home/devuser
    log "Running command as ${PUID}:${PGID} with HOME=${HOME}"
    exec gosu "${PUID}:${PGID}" "$@"
fi

export HOME=/root
log "========================================"
log "Running command as root with HOME=${HOME}"
exec "$@"
