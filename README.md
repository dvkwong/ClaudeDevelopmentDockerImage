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
| [ttyd](https://tsl0922.github.io/ttyd/) | Web-based terminal for browser console access |

## Running on Unraid

The easiest way to run the container on Unraid is with the included `docker-compose.yml`.

### 1 — Copy `docker-compose.yml` to your Unraid server

Place it anywhere accessible, e.g. `/mnt/user/appdata/claude-dev/docker-compose.yml`.

### 2 — (Optional) Configure your instance

Create a `.env` file next to `docker-compose.yml`:

```env
# Name this instance (defaults to "claude-dev").
# Use a unique name for each instance when running multiple side-by-side.
INSTANCE_NAME=claude-dev

# Discord bot token for the Claude Discord plugin (leave blank if unused).
DISCORD_BOT_TOKEN=your-token-here

# Web console port (defaults to 7681). Use different ports for multiple instances.
TTYD_PORT=7681
```

The `INSTANCE_NAME` variable controls the container name and the host volume
paths under `/mnt/user/appdata/`. Each unique name gets its own workspace and
config directories, so you can run several instances at the same time without
conflicts.

### 3 — Start the container

```bash
docker compose pull   # fetch the latest image from ghcr.io
docker compose up -d  # start in the background
```

### 4 — Open the web console

The container starts a **web-based terminal** automatically on port **7681**.  
Open your browser and navigate to:

```
http://<your-unraid-ip>:7681
```

You will get a full interactive bash shell right in your browser — no SSH or `docker exec` required.

> **Security note:** The web console has no authentication by default and is intended for use on a trusted local network. **Do not expose port 7681 to the internet.** If you need authentication, add credentials via a `TTYD_CREDENTIAL` environment variable and update the entrypoint's ttyd flags (e.g. `ttyd --credential user:password`).

> **Tip:** On Unraid, click the container's icon → **WebUI** to jump straight to the console (you may need to set the WebUI URL to `http://[IP]:[PORT:7681]` in the template).

### 5 — (Alternative) Open a shell via `docker exec`

```bash
docker exec -it claude-dev bash        # default instance
docker exec -it my-project bash        # custom-named instance
```

### Viewing logs

Container logs now show startup information and tool versions.  
View them from the Unraid Docker tab (**Logs** icon) or from the command line:

```bash
docker logs claude-dev          # default instance
docker logs -f claude-dev       # follow / stream logs
```

### Running multiple instances

To run more than one instance, create a separate directory (or `.env` file) for
each instance with a unique `INSTANCE_NAME`:

```bash
# Instance 1 (default name)
INSTANCE_NAME=claude-dev docker compose up -d

# Instance 2 (use a different web console port to avoid conflicts)
INSTANCE_NAME=claude-project-b TTYD_PORT=7682 docker compose up -d
```

Each instance will have isolated workspace and config volumes under
`/mnt/user/appdata/<INSTANCE_NAME>/` and its own web console port.

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
