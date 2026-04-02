# Development image — .NET SDK (latest) via Microsoft devcontainers base
FROM mcr.microsoft.com/devcontainers/dotnet:latest

# All installation steps run as root
USER root

# ── Extra system packages ─────────────────────────────────────────────────────
# curl, git and ca-certificates are already present in the devcontainers base.
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

# ── ttyd — web-based terminal ─────────────────────────────────────────────────
# Provides a browser-accessible console so Unraid users can reach the shell
# without relying solely on `docker exec`.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ttyd \
    && rm -rf /var/lib/apt/lists/*

# ── Bun runtime ───────────────────────────────────────────────────────────────
# Bun is required by the Claude Discord plugin's MCP server.
ENV BUN_INSTALL="/usr/local/bun"
ENV PATH="${BUN_INSTALL}/bin:${PATH}"
RUN curl -fsSL https://bun.sh/install | bash

# ── Claude CLI + Vite + React tooling ────────────────────────────────────────
RUN npm install -g \
        @anthropic-ai/claude-code \
        vite \
        create-vite \
        typescript

# ── Claude Discord plugin ─────────────────────────────────────────────────────
# Clone the official plugin repository and install its dependencies so the
# plugin is ready to use.  Users still need to supply their Discord bot token
# at runtime (see README for instructions).
RUN git clone --depth 1 https://github.com/anthropics/claude-plugins-official.git \
        /opt/claude-plugins-official \
    && cd /opt/claude-plugins-official/external_plugins/discord \
    && bun install

# ── Entrypoint (PUID / PGID support for Unraid) ──────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── Workspace ────────────────────────────────────────────────────────────────
RUN mkdir -p /workspace
WORKDIR /workspace

# ttyd default port
EXPOSE 7681

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
