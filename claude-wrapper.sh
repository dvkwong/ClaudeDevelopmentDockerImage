#!/bin/bash
set -e

CLAUDE_BIN="/usr/local/bin/claude-real"

if [ ! -x "${CLAUDE_BIN}" ]; then
    echo "claude binary not found at ${CLAUDE_BIN}" >&2
    exit 1
fi

if [ "$(id -u)" = "0" ] && { [ "${PUID:-0}" != "0" ] || [ "${PGID:-0}" != "0" ]; }; then
    export HOME=/home/devuser
    exec gosu "${PUID:-0}:${PGID:-0}" "${CLAUDE_BIN}" "$@"
fi

exec "${CLAUDE_BIN}" "$@"