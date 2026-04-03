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

# ── Node.js 20 LTS + npm ─────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
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
RUN npm install -g @anthropic-ai/claude-code

# ── Entrypoint (PUID / PGID support for Unraid) ──────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── Workspace ────────────────────────────────────────────────────────────────
ENV PATH="/home/devuser/.local/bin:/root/.local/bin:${PATH}"
RUN mkdir -p /workspace /home/devuser
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
