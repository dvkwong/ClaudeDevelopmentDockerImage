# Development image — .NET SDK (latest) via Microsoft devcontainers base
FROM mcr.microsoft.com/devcontainers/dotnet:latest

# All installation steps run as root
USER root

# ── Runtime dependencies ─────────────────────────────────────────────────────
# gosu is needed by the entrypoint to drop privileges to PUID:PGID (Unraid).
RUN apt-get update && apt-get install -y --no-install-recommends \
        gosu \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# ── GitHub CLI (gh) ──────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
        https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ── Claude CLI ────────────────────────────────────────────────────────────────
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && install -m 755 "$(readlink -f /root/.local/bin/claude)" /usr/local/bin/claude-real \
    && rm -rf /root/.cache/claude /root/.claude /root/.local/bin /root/.local/share/claude /root/.local/state/claude
COPY claude-wrapper.sh /usr/local/bin/claude
RUN chmod +x /usr/local/bin/claude

# ── Bun runtime ──────────────────────────────────────────────────────────────
ENV BUN_INSTALL="/usr/local/bun"
RUN curl -fsSL https://bun.sh/install | bash

# ── Entrypoint (PUID / PGID support for Unraid) ──────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── Workspace ────────────────────────────────────────────────────────────────
ENV PATH="${BUN_INSTALL}/bin:${PATH}:/home/devuser/.local/bin:/root/.local/bin"
RUN mkdir -p /workspace /home/devuser
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
