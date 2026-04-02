#!/bin/bash
set -e

# ── PUID / PGID support ───────────────────────────────────────────────────────
# Unraid (and many other hosts) pass PUID / PGID environment variables so that
# files written inside the container are owned by the host user rather than root.
#
# Defaults: run as root (0:0) when neither variable is set.
PUID=${PUID:-0}
PGID=${PGID:-0}

if [ "${PUID}" != "0" ] || [ "${PGID}" != "0" ]; then
    echo "[entrypoint] Remapping container user to UID=${PUID} GID=${PGID}"

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

    # Re-execute the requested command as the mapped user
    exec gosu "${PUID}:${PGID}" "$@"
fi

# Running as root — execute directly
exec "$@"
