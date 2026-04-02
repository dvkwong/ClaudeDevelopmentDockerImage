# ClaudeDevelopmentDockerImage

A Docker image containing .NET / web-development tools and the Claude CLI (with Discord plugin) for isolating development environments.

## What's inside

| Tool | Purpose |
|------|---------|
| [.NET 8 SDK](https://dot.net) | .NET LTS runtime + SDK (base image) |
| [Node.js 20 LTS](https://nodejs.org) + npm | JavaScript / web development |
| [git](https://git-scm.com) | Version control |
| [GitHub CLI (`gh`)](https://cli.github.com) | GitHub operations from the terminal |
| [Claude CLI](https://docs.anthropic.com/claude-code) | AI-powered coding assistant |
| [Bun](https://bun.sh) | Runtime required by the Claude Discord plugin |
| [Claude Discord plugin](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/discord) | Control Claude from Discord |

## Build

```bash
docker build -t claude-dev .
```

## Run

```bash
# Interactive shell with your project mounted at /workspace
docker run -it --rm \
  -v "$(pwd):/workspace" \
  claude-dev
```

## Using the Claude Discord plugin

The Discord plugin is pre-installed at `/opt/claude-plugins-official/external_plugins/discord`.

1. Create a Discord bot in the [Discord Developer Portal](https://discord.com/developers/applications) and copy its token.
2. Start the plugin's MCP server inside the container:
   ```bash
   cd /opt/claude-plugins-official/external_plugins/discord
   bun server.ts
   ```
3. Follow the on-screen pairing instructions to connect it to your Claude CLI session.

> **Note:** You will need to supply your Discord bot token at runtime. Never commit it to source control.
