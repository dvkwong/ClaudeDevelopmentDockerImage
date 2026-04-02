# Development image based on the Microsoft .NET 8.0 SDK (LTS)
FROM mcr.microsoft.com/dotnet/sdk:8.0

# ── System packages ──────────────────────────────────────────────────────────
# Install curl, gnupg and git (git is typically pre-installed but listed
# explicitly for clarity).  The lists are removed afterwards to keep the
# layer slim.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        git \
        ca-certificates \
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

# ── Bun runtime ───────────────────────────────────────────────────────────────
# Bun is required by the Claude Discord plugin's MCP server.
ENV BUN_INSTALL="/usr/local/bun"
ENV PATH="${BUN_INSTALL}/bin:${PATH}"
RUN curl -fsSL https://bun.sh/install | bash

# ── Claude CLI ───────────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Claude Discord plugin ─────────────────────────────────────────────────────
# Clone the official plugin repository and install its dependencies so the
# plugin is ready to use.  Users still need to supply their Discord bot token
# at runtime (see README for instructions).
RUN git clone --depth 1 https://github.com/anthropics/claude-plugins-official.git \
        /opt/claude-plugins-official \
    && cd /opt/claude-plugins-official/external_plugins/discord \
    && bun install

# ── Workspace ────────────────────────────────────────────────────────────────
WORKDIR /workspace

CMD ["/bin/bash"]
