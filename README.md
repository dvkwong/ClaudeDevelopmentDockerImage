# ClaudeDevelopmentDockerImage

A Docker image based on the Microsoft .NET devcontainer image with the GitHub CLI and Claude CLI added for isolated development environments.
The image is built automatically on every push to `main` and published to the GitHub Container Registry.

## What's inside

| Tool | Purpose |
|------|---------|
| [.NET SDK](https://dot.net) (latest) | .NET runtime + SDK (base image) |
| [git](https://git-scm.com) | Version control |
| [GitHub CLI (`gh`)](https://cli.github.com) | GitHub operations from the terminal |
| [Bun](https://bun.sh) | Runtime required by the Claude Discord plugin |
| [Claude CLI](https://docs.anthropic.com/claude-code) | AI-powered coding assistant |

## Running on Unraid

The easiest way to run the container on Unraid is with the included `docker-compose.yml`.

### 1 — Copy `docker-compose.yml` to your Unraid server

Place it anywhere accessible, e.g. `/mnt/user/appdata/claude-dev/docker-compose.yml`.

### 2 — Configure your instance

Create a `.env` file next to `docker-compose.yml`:

```env
# Name this instance (defaults to "claude-dev").
# Use a unique name for each instance when running multiple side-by-side.
INSTANCE_NAME=claude-dev

# Optional: map file ownership to your Unraid user.
PUID=99
PGID=100
```

Auth is no longer passed through environment variables. Instead, sign in once
inside the container and let the mounted home directories persist the CLI state
across image updates.

The `INSTANCE_NAME` variable controls the container name and the host volume
paths under `/mnt/user/appdata/`. Each unique name gets its own workspace and
home directories, so you can run several instances at the same time without
conflicts.

The compose file mounts these persistent paths:

| Host path | Container path | Purpose |
|-----------|----------------|---------|
| `/mnt/user/appdata/<INSTANCE_NAME>/workspace` | `/workspace` | Git repos, project files, local scripts |
| `/mnt/user/appdata/<INSTANCE_NAME>/home` | `/home/devuser` | Non-root auth, dotfiles, user-space tooling |
| `/mnt/user/appdata/<INSTANCE_NAME>/root` | `/root` | Root auth and config when using root shells |

### 3 — Start the container

```bash
docker compose pull   # fetch the latest image from ghcr.io
docker compose up -d  # start in the background
```

### 4 — Open a shell

```bash
docker exec -it --user 99:100 -e HOME=/home/devuser -w /workspace claude-dev bash
docker exec -it --user 99:100 -e HOME=/home/devuser -w /workspace my-project bash
```

Replace `99:100` with your configured `PUID:PGID`. If you need a root shell,
drop the `--user` flag.

When opening a root shell from the Unraid console, `claude` will automatically
drop to the mapped `PUID:PGID` user so it can run without hitting Claude's
root/sudo safety restriction.

### 5 — Authenticate once

Run these commands inside the container shell:

```bash
claude auth
gh auth login
```

Those credentials are stored in the mounted home directories, so they survive
container recreation and image updates.

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

# Instance 2
INSTANCE_NAME=claude-project-b docker compose up -d
```

Each instance will have isolated workspace and home volumes under
`/mnt/user/appdata/<INSTANCE_NAME>/`.

### PUID / PGID

The container respects the standard Unraid `PUID` / `PGID` environment variables so that files written inside the container are owned by the correct host user. The defaults in `docker-compose.yml` are:

| Variable | Default | Meaning |
|----------|---------|---------|
| `PUID` | `99` | Unraid *nobody* user |
| `PGID` | `100` | Unraid *users* group |

Set both to `0` to run as root.

## Building locally

For local testing before pushing to GitHub, use the local-only compose file and
helper script in this repo.

### Local test files

- `docker-compose.local.yml` builds from the current checkout instead of pulling from GHCR.
- `local-dev.sh` wraps the common local test commands.
- `.docker-test/` stores the local workspace and persisted home directories.

### Local test workflow

```bash
./local-dev.sh up
./local-dev.sh logs
./local-dev.sh shell
```

That flow will:

- build the image from the current `Dockerfile`
- start a local container named `claude-dev-local`
- persist test data in `.docker-test/workspace`, `.docker-test/home`, and `.docker-test/root`

Useful local commands:

```bash
./local-dev.sh build
./local-dev.sh recreate
./local-dev.sh root-shell
./local-dev.sh down
./local-dev.sh clean
```

If you want to run the compose commands directly instead of using the script:

```bash
mkdir -p .docker-test/workspace .docker-test/home .docker-test/root
docker compose -f docker-compose.local.yml up -d --build
docker exec -it --user "$(id -u):$(id -g)" -e HOME=/home/devuser -w /workspace claude-dev-local bash
```

## Persistence notes

Anything stored in `/workspace`, `/home/devuser`, or `/root` survives image
updates because those paths are bind-mounted from the host.

This covers:

- cloned repositories and project files
- Claude CLI auth, settings, and local state
- GitHub CLI auth and config
- dotfiles and user-space tooling installed under the mounted home directory

What does not persist automatically is software installed into the container's
system image at runtime, such as `apt install` inside a running container. If
you want extra tools to survive recreation, install them into the mounted home
directory or keep them in `/workspace`.

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
