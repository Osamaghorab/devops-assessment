# Notifications API

A Node.js + Express + PostgreSQL API prepared for containerized development, testing, and publishing using Docker, Docker Compose, GitHub Actions, and an operations script.  
Application source code is located in `src/`.

## Overview

This project demonstrates how to build, run, test, and publish a containerized API using modern DevOps practices.  
It includes multi‑stage Docker builds, health‑based orchestration, CI image scanning, smoke testing, and automated publishing to GHCR.

## Quick Start

Requires Docker with Compose v2.  
`.env` is optional because Compose provides local defaults.

```bash
docker compose up -d --build
curl http://localhost:8080/health
curl http://localhost:8080/users
./scripts/ops.sh smoke
```

Using Make:

```makefile
make up
make smoke
make down
```

To override database credentials:

```bash
cp .env.example .env
```

The example credentials are for local development only.

## Architecture

| Path | Purpose |
|------|---------|
| Dockerfile | Multi‑stage build, production dependencies, non‑root runtime |
| docker-compose.yml | API + PostgreSQL services, healthchecks, network, persistent volume |
| .github/workflows/ci.yml | Build, scan, run, smoke‑test, and publish pipeline |
| scripts/ops.sh | Operational commands (`up`, `down`, `status`, `logs`, `smoke`) |
| Makefile | Shortcuts for local operations and optional linting |

### Dockerfile

- Installs production dependencies using `npm ci --omit=dev`.
- Copies only required runtime files.
- Runs the API as the unprivileged `node` user.
- Includes a healthcheck calling `/health`.

### Compose

- Starts PostgreSQL first and waits for its healthcheck.
- Starts the API only after the database is healthy.
- Exposes the API on port `8080`.
- Stores database data in the `pgdata` volume.
- PostgreSQL is not exposed on any host port.

## Security and Workflow Practices

- Non‑root container runtime.
- Minimal runtime footprint using production‑only dependencies.
- CI vulnerability scanning using Trivy, failing on fixable HIGH or CRITICAL findings.
- Third-party GitHub Actions are pinned to full commit SHAs to avoid relying on movable version tags.
- CI scans and runs the same built image (`notifications-api:ci`).
- Least‑privilege GitHub Actions permissions (`contents: read` by default).
- GHCR publishing uses GitHub’s built‑in `GITHUB_TOKEN`.
- Publishing occurs only after build, scan, and smoke tests succeed.
- CI prints logs on failure and always removes the Compose stack and test database volume.
- `.env` is ignored by Git and excluded from the Docker build context.
- Database is reachable only inside the Compose network.
- Health‑based startup and verification in both Compose and CI.

## CI/CD Flow

The GitHub Actions workflow runs on pull requests and pushes to `main`.

1. Build the API image and tag it `notifications-api:ci`.
2. Scan the image with Trivy.
3. Start the Compose stack using the scanned image.
4. Wait for healthchecks.
5. Run smoke tests using `scripts/ops.sh smoke`.
6. Print logs on failure; always remove the stack and test database volume.

On pushes to `main`, a publish job runs only after verification succeeds.  
It publishes the image to GHCR with `latest` and full commit SHA tags.

## Operational Commands

The `ops.sh` script uses strict Bash safety (`set -euo pipefail`) and exits non‑zero on failures.

| Command | Action |
|---------|--------|
| make up | Build and start the stack |
| make down | Stop the stack but keep database data |
| make status | Show service health |
| make logs | Follow API logs |
| make smoke | Run API smoke tests |
| make clean | Remove the stack and database volume |
| make lint | Run optional `hadolint` and `shellcheck` |

Smoke tests include `/health` and a create/read round‑trip for users and notifications.
