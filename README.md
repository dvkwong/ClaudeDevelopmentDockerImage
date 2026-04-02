# ClaudeDevelopmentDockerImage

A Docker image containing .NET / web-development tools and the Claude CLI (with Discord plugin) for isolating development environments.  
The image is built automatically on every push to `main` and published to the GitHub Container Registry.

## What's inside

| Tool | Purpose |
|------|---------|
| [.NET SDK](https://dot.net) (latest) | .NET runtime + SDK (base image) |
| [Node.js 20 LTS](https://nodejs.org) + npm | JavaScript / web development |
| [Vite](https://vitejs.dev) + [create-vite](https://vitejs.dev/guide/#scaffolding-your-first-vite-project) | Fast frontend build tool & project scaffolding |
| [TypeScript](https://www.typescriptlang.org) | Typed JavaScript (React / Vite projects) |
| [git](https://git-scm.com) | Version control |
| [GitHub CLI (`gh`)](https://cli.github.com) | GitHub operations from the terminal |
| [Claude CLI](https://docs.anthropic.com/claude-code) | AI-powered coding assistant |
| [Bun](https://bun.sh) | Runtime required by the Claude Discord plugin |
| [Claude Discord plugin](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/discord) | Control Claude from Discord |

## Running on Unraid

The easiest way to run the container on Unraid is with the included `docker-compose.yml`.

### 1 — Copy `docker-compose.yml` to your Unraid server

Place it anywhere accessible, e.g. `/mnt/user/appdata/claude-dev/docker-compose.yml`.

### 2 — (Optional) Set your Discord bot token

Create a `.env` file next to `docker-compose.yml`:

```env
DISCORD_BOT_TOKEN=your-token-here
```

### 3 — Start the container

```bash
docker compose pull   # fetch the latest image from ghcr.io
docker compose up -d  # start in the background
```

### 4 — Open an interactive shell

```bash
docker exec -it claude-dev bash
```

### PUID / PGID

The container respects the standard Unraid `PUID` / `PGID` environment variables so that files written inside the container are owned by the correct host user. The defaults in `docker-compose.yml` are:

| Variable | Default | Meaning |
|----------|---------|---------|
| `PUID` | `99` | Unraid *nobody* user |
| `PGID` | `100` | Unraid *users* group |

Set both to `0` to run as root.

## Building locally

```bash
docker build -t claude-dev .
```

## Using the Claude Discord plugin

The Discord plugin is pre-installed at `/opt/claude-plugins-official/external_plugins/discord`.

1. Create a Discord bot in the [Discord Developer Portal](https://discord.com/developers/applications) and copy its token.
2. Pass the token via the `DISCORD_BOT_TOKEN` environment variable (see above).
3. Start the plugin's MCP server inside the container:
   ```bash
   cd /opt/claude-plugins-official/external_plugins/discord
   bun server.ts
   ```
4. Follow the on-screen pairing instructions to connect it to your Claude CLI session.

> **Note:** Never commit your Discord bot token to source control.

## CI/CD

Every push to `main` triggers the [Build and Publish](.github/workflows/docker-publish.yml) workflow, which:

1. Builds the image and pushes it to `ghcr.io/dvkwong/claudedevelopmentdockerimage:latest`
2. Automatically sets the package visibility to **public** so no authentication is needed when pulling from Unraid

### Do I need to log in on Unraid to pull the image?

**No** — the workflow makes the package public automatically after each build, so you can pull the image on Unraid without any credentials:

```bash
docker pull ghcr.io/dvkwong/claudedevelopmentdockerimage:latest
```

#### If the image is still showing as private

The first-time API call may fail if the package does not exist yet (it is created on the first push). After the first successful build, either:

- Re-run the workflow once from the **Actions** tab, **or**
- Manually set the visibility: **GitHub → Packages → claudedevelopmentdockerimage → Package settings → Change visibility → Public**

#### Keeping the image private (optional)

If you prefer to keep the image private, remove the *Make package public* step from the workflow and authenticate on Unraid with a GitHub Personal Access Token:

```bash
# On your Unraid server (via terminal or User Scripts plugin)
docker login ghcr.io -u YOUR_GITHUB_USERNAME -p YOUR_PAT
```

The PAT only needs the `read:packages` scope. Once logged in, `docker compose pull` will work as normal.
